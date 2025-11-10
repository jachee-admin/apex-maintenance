# apex_config_troubleshooting

Fast, repeatable troubleshooting for Oracle APEX/ORDS on multitenant DBs (CDB/PDB).

## What this repo does
- **Diagnostics:** PDB open state, restricted logins, plug-in violations, APEX version mismatches, missing datapatch, common vs local user conflicts (ORDS/APEX users).
- **Fixes:** Clear stuck PDB sync rows (e.g., ORA-65177 on `ALTER USER ORDS_PUBLIC_USER`), reopen PDB cleanly, optional restricted-session grants.
- **Wrappers:** PowerShell and bash runners that collect both DB and host/ORDS environment in one report.

> Principle: **Diagnose first**, then apply the smallest safe fix.

## Typical “HTTP 571 from ORDS” runbook
1. `scripts/ps/ords-env-check.ps1` or `scripts/bash/ords-env-check.sh`
2. `scripts/sql/diagnostics/run_all_diagnostics.sql` (via `scripts/ps/run-diagnostics.ps1` or `scripts/bash/run-diagnostics.sh`)
3. If `pdb_plug_in_violations` shows ORA-65177 on ORDS/APEX users:
   - `scripts/sql/fixes/fix_clear_stuck_sync.sql`
   - `scripts/sql/fixes/fix_reopen_pdb.sql`
4. Re-run diagnostics. Expect `RESTRICTED=NO`, ORDS pool VALID.

## Safety
- Fix scripts back up rows before deletes.
- No destructive user drops here; we only clear queued sync rows and reopen.
- Always review scripts before running in prod.

## Troubleshooting - Typical use
### Windows:

```powershell
cd apex_config_troubleshooting
.\scripts\ps\ords-env-check.ps1
.\scripts\ps\run-diagnostics.ps1
# If violations show ORDS_PUBLIC_USER stuck:
sqlplus / as sysdba @scripts\sql\fixes\fix_clear_stuck_sync.sql USERNAME=ORDS_PUBLIC_USER
sqlplus / as sysdba @scripts\sql\fixes\fix_reopen_pdb.sql PDB=FREEPDB1
```

### Linux:
```bash
cd apex_config_troubleshooting
./scripts/bash/ords-env-check.sh
./scripts/bash/run-diagnostics.sh
sqlplus / as sysdba @scripts/sql/fixes/fix_clear_stuck_sync.sql USERNAME=ORDS_PUBLIC_USER
sqlplus / as sysdba @scripts/sql/fixes/fix_reopen_pdb.sql PDB=FREEPDB1
```


