#!/usr/bin/env bash
# Safe wrapper to run OPatch datapatch -verbose with pre/post checks.
# Usage:
#   ORACLE_HOME=/opt/oracle/product/23c/dbhome_1 ORACLE_SID=FREECDB1 ./fix_run_datapatch.sh
#   ./fix_run_datapatch.sh --oracle-home /opt/oracle/product/23c/dbhome_1 --oracle-sid FREECDB1 --force

set -euo pipefail

ORACLE_HOME="${ORACLE_HOME:-}"
ORACLE_SID="${ORACLE_SID:-}"
SQLPLUS="${SQLPLUS:-sqlplus}"
LOGDIR="${LOGDIR:-./logs}"
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --oracle-home) ORACLE_HOME="$2"; shift 2 ;;
    --oracle-sid)  ORACLE_SID="$2";  shift 2 ;;
    --sqlplus)     SQLPLUS="$2";     shift 2 ;;
    --logdir)      LOGDIR="$2";      shift 2 ;;
    --force)       FORCE=true;       shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

[[ -n "$ORACLE_HOME" && -n "$ORACLE_SID" ]] || { echo "Set ORACLE_HOME and ORACLE_SID (or pass --oracle-home/--oracle-sid)"; exit 1; }
mkdir -p "$LOGDIR"

export ORACLE_HOME ORACLE_SID PATH="$ORACLE_HOME/bin:$PATH"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="$LOGDIR/datapatch_${ORACLE_SID}_$TS.log"
PRE="$LOGDIR/precheck_${ORACLE_SID}_$TS.sql"
POST="$LOGDIR/postcheck_${ORACLE_SID}_$TS.sql"

DATAPATCH="$ORACLE_HOME/OPatch/datapatch"
[[ -x "$DATAPATCH" ]] || { echo "datapatch not found at $DATAPATCH"; exit 1; }

cat > "$PRE" <<'SQL'
set pages 200 lines 200
column name format a20
prompt === Instance / PDB states BEFORE datapatch ===
select logins from v$instance;
select con_id, name, open_mode, restricted from v$pdbs order by con_id;

prompt === Attempt to open all PDBs READ WRITE (ignore errors) ===
alter session set container = CDB$ROOT;
begin
  for r in (select name from v$pdbs where name not in ('PDB$SEED')) loop
    begin
      execute immediate 'alter pluggable database '||r.name||' open read write';
    exception when others then null;
    end;
  end loop;
end;
/

prompt === Unresolved plug-in violations (should be empty) ===
column cause format a40
column status format a10
column message format a120
select name, cause, type, status, message
from   pdb_plug_in_violations
where  status <> 'RESOLVED'
order  by time;
SQL

"$SQLPLUS" / as sysdba @"$PRE" | tee "${PRE%.sql}.log" >/dev/null

VIOLATIONS=$("$SQLPLUS" -s / as sysdba <<'SQL'
set pages 0 feed off
select count(*) from pdb_plug_in_violations where status <> 'RESOLVED';
SQL
)
VIOLATIONS="$(echo "$VIOLATIONS" | tr -d '[:space:]')"
if [[ "${VIOLATIONS:-0}" -gt 0 && "$FORCE" != true ]]; then
  echo "Unresolved plug-in violations: $VIOLATIONS. Fix first or rerun with --force"
  exit 2
fi

echo "=== Running datapatch -verbose ==="
set +e
"$DATAPATCH" -verbose >"$LOG" 2>&1
RC=$?
set -e
if [[ $RC -ne 0 ]]; then
  echo "datapatch exited with $RC. See $LOG"
  exit $RC
fi
echo "datapatch complete. Log: $LOG"

cat > "$POST" <<'SQL'
set pages 200 lines 200
column name format a20
prompt === PDB states AFTER datapatch ===
select con_id, name, open_mode, restricted from v$pdbs order by con_id;

prompt === SQL patches applied (last 20) ===
select p.name, sp.status, to_char(sp.action_time,'YYYY-MM-DD HH24:MI') action_time, sp.description
from   cdb_registry_sqlpatch sp
join   v$pdbs p on p.con_id = sp.con_id
order  by sp.action_time desc fetch first 20 rows only;
SQL

"$SQLPLUS" / as sysdba @"$POST" | tee "${POST%.sql}.log" >/dev/null

echo "Done. Logs: $LOG, ${PRE%.sql}.log, ${POST%.sql}.log"
