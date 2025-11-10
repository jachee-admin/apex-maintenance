

### `docs/playbook-datapatch.md`


# Playbook: Running `datapatch -verbose` Safely

**Purpose:**
`datapatch` applies SQL portion of Database RUs/RURs and component updates (APEX, JVM, etc.) across all containers.

---

## When to Run

- After applying any **RU/RUR patch** or **PSU** to Oracle Home.
- After upgrading or reinstalling APEX.
- After ORDS or database binaries are updated.

---

## Pre-check

1. Open all PDBs read/write:
```sql
   alter session set container = CDB$ROOT;
   alter pluggable database all open read write;
```

2. Check for unresolved plug-in violations:

```sql
   select name, cause, status
   from   pdb_plug_in_violations
   where  status <> 'RESOLVED';
```

3. Ensure there’s no restricted mode:

```sql
   select name, restricted from v$pdbs;
```

---

## Run `datapatch`

From OS shell as Oracle owner:

```bash
export ORACLE_HOME=/path/to/dbhome
export ORACLE_SID=<cdb_name>
$ORACLE_HOME/OPatch/datapatch -verbose
```

Watch for:

```
SQL Patching tool complete successfully
```

---

## Post-run Validation

```sql
select name, open_mode, restricted from v$pdbs;
select * from cdb_registry_sqlpatch order by action_time;
```

Expected:

* Each PDB listed as *APPLIED*.
* No new unresolved plug-in violations.

---

## Troubleshooting

* If a PDB shows “FAILED” status, open it manually and re-run datapatch for that PDB:

```bash
  sqlplus / as sysdba
  alter session set container=<pdbname>;
  @?/sqlpatch/sqlpatch.sql
```

* If a patch was applied while PDBs were closed, open them all and rerun `datapatch -verbose`.

---

## Best Practice

* Always take a backup before RU application.
* Run diagnostics (`run_all_diagnostics.sql`) after datapatch.
* Save a copy of `$ORACLE_HOME/sqlpatch/sqlpatch.log` and `/cfgtoollogs/sqlpatch/` in your repo for traceability.

