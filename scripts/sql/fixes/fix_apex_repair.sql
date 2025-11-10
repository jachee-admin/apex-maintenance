-- fix_apex_repair.sql
-- Usage:
--    Quick repair (current PDB)
--      sqlplus / as sysdba @scripts/sql/fixes/fix_apex_repair.sql
--
--    Explicit repair with tag in spool file
--      sqlplus / as sysdba @scripts/sql/fixes/fix_apex_repair.sql MODE=REPAIR TAG=post_patch
--
--    Full reinstall (current PDB) — DANGEROUS, drops APEX in this PDB
--      sqlplus / as sysdba @scripts/sql/fixes/fix_apex_repair.sql MODE=REINSTALL CONFIRM=YES IMGPREFIX=/i/ TS_SYS_AUX=SYSAUX TS_TEMP=TEMP TAG=reinstall_242
--
-- Purpose:
--   - MODE=REPAIR (default): Recompile and validate APEX in the *current PDB*.
--   - MODE=REINSTALL: Remove and reinstall APEX in the *current PDB* using apxremov.sql/apexins.sql.
--
-- IMPORTANT:
--   * Run this INSIDE the target PDB (NOT from CDB$ROOT).
--   * For MODE=REINSTALL, this will DROP APEX from the PDB (applications included) and reinstall it.
--     You MUST pass CONFIRM=YES to proceed.
--
-- Parameters (all optional unless MODE=REINSTALL):
--   MODE         : REPAIR | REINSTALL     (default REPAIR)
--   CONFIRM      : YES to allow REINSTALL (default NO)
--   IMGPREFIX    : APEX images prefix for apexins.sql (default /i/)
--   TS_SYS_AUX   : Tablespace for SYSAUX argument to apexins.sql (default SYSAUX)
--   TS_TEMP      : TEMP tablespace name (default TEMP)
--   TAG          : Optional label to suffix spool/report files
--
-- Examples:
--   sqlplus / as sysdba @fix_apex_repair.sql
--   sqlplus / as sysdba @fix_apex_repair.sql MODE=REPAIR TAG=post_patch
--   sqlplus / as sysdba @fix_apex_repair.sql MODE=REINSTALL CONFIRM=YES IMGPREFIX=/i/ TS_SYS_AUX=SYSAUX TS_TEMP=TEMP TAG=reinstall_242
--
-- Post-steps after reinstall (manual, outside this script):
--   - Ensure /i/ (images) served by ORDS matches the installed APEX version.
--   - Optionally run @apex_rest_config.sql to provision REST users (will prompt for passwords).
--   - Restart ORDS and verify pool is VALID.

define MODE        = "REPAIR"
define CONFIRM     = "NO"
define IMGPREFIX   = "/i/"
define TS_SYS_AUX  = "SYSAUX"
define TS_TEMP     = "TEMP"
define TAG         = ""

set define on verify off serveroutput on feedback on lines 200 pages 200 trimspool on

column _ts suffix new_value _TAG
select case when '&&TAG' is null then '' else '_'||'&&TAG' end "_TS" from dual;

spool fix_apex_repair&&_TAG..log

prompt === Context check ===
column con_name new_value _CON
select sys_context('USERENV','CON_NAME') con_name from dual;
prompt CON_NAME = &&_CON

-- Abort if running in root
whenever sqlerror continue
declare
  v_con varchar2(128) := sys_context('USERENV','CON_NAME');
begin
  if v_con = 'CDB$ROOT' then
    raise_application_error(-20000, 'Run fix_apex_repair.sql inside the target PDB, not CDB$ROOT');
  end if;
end;
/
whenever sqlerror exit

prompt === Current APEX component status (before) ===
col comp_id format a8
col version format a20
col status  format a12
select comp_id, version, status from dba_registry where comp_id='APEX';

prompt === Invalid objects (top 20) before ===
col owner format a20
col object_name format a30
select * from (
  select owner, object_type, object_name, status
  from   dba_objects
  where  status <> 'VALID'
  order  by owner, object_type, object_name
) where rownum <= 20;

prompt === Mode selection ===
prompt MODE=&&MODE, CONFIRM=&&CONFIRM, IMGPREFIX=&&IMGPREFIX, TS_SYS_AUX=&&TS_SYS_AUX, TS_TEMP=&&TS_TEMP

declare
  v_mode    varchar2(30) := upper('&&MODE');
  v_confirm varchar2(10) := upper('&&CONFIRM');
begin
  if v_mode not in ('REPAIR','REINSTALL') then
    raise_application_error(-20001, 'Invalid MODE. Use MODE=REPAIR or MODE=REINSTALL');
  end if;

  if v_mode = 'REINSTALL' and v_confirm <> 'YES' then
    raise_application_error(-20002, 'REINSTALL requested but CONFIRM<>YES. Aborting for safety.');
  end if;
end;
/

-- =========================
-- MODE: REPAIR
-- =========================
begin
  if upper('&&MODE') = 'REPAIR' then
    dbms_output.put_line('>>> REPAIR mode: recompiling invalids (UTLRP), then re-checking APEX status...');
  end if;
end;
/
-- Recompile invalids (safe, idempotent)
@?/rdbms/admin/utlrp.sql

prompt === APEX status after REPAIR (no reinstall) ===
select comp_id, version, status from dba_registry where comp_id='APEX';

prompt === Remaining invalid objects (top 20) ===
select * from (
  select owner, object_type, object_name, status
  from   dba_objects
  where  status <> 'VALID'
  order  by owner, object_type, object_name
) where rownum <= 20;

-- Short-circuit if we were only doing REPAIR
begin
  if upper('&&MODE') = 'REPAIR' then
    raise_application_error(-20999, 'REPAIR complete (this is a controlled exit to skip REINSTALL branch).');
  end if;
end;
/
-- Ignore the controlled exit for flow control
whenever sqlerror continue

-- =========================
-- MODE: REINSTALL
-- =========================
prompt
prompt === REINSTALL mode: Removing and reinstalling APEX in this PDB ===
prompt This will DROP APEX schemas and applications in &&_CON. Proceeding (CONFIRM=YES supplied).
prompt

-- Backup quick facts before removal
prompt === Snapshot of APEX component BEFORE removal ===
select comp_id, version, status from dba_registry where comp_id='APEX';

-- Remove existing APEX from the PDB
prompt >>> Running @apxremov.sql (this can take several minutes) ...
@apxremov.sql

-- Reinstall APEX (same version as your media dir in SQLPATH / working dir)
prompt >>> Running @apexins.sql &&TS_SYS_AUX &&TS_SYS_AUX &&TS_TEMP &&IMGPREFIX (this may take a while) ...
@apexins.sql &&TS_SYS_AUX &&TS_SYS_AUX &&TS_TEMP &&IMGPREFIX

-- Recompile everything again after install
@?/rdbms/admin/utlrp.sql

prompt === APEX status after REINSTALL ===
select comp_id, version, status from dba_registry where comp_id='APEX';

prompt === Invalid objects (top 20) after REINSTALL ===
select * from (
  select owner, object_type, object_name, status
  from   dba_objects
  where  status <> 'VALID'
  order  by owner, object_type, object_name
) where rownum <= 20;

prompt
prompt >>> NOTE:
prompt - Ensure your ORDS static images (/i/) match the installed APEX version.
prompt - To (re)configure APEX REST users later, run @apex_rest_config.sql (will prompt for passwords).
prompt

spool off
prompt Log written to fix_apex_repair&&_TAG..log
