# Playbook: ORDS HTTP 571 / ORA-01035


**Symptom:**

- Browser shows `HTTP Status 571 – ORDS was unable to make a connection to the database.`
- ORDS logs show `ORA-01035: Login denied. Database is in RESTRICTED mode.`

---

## Quick Diagnosis

1. **Check PDB state**
```sql
   select name, open_mode, restricted from v$pdbs;
````

* `RESTRICTED = YES` → root cause confirmed.

2. **Check for unresolved plug-in violations**

   ```sql
   select name, cause, type, status, message, action
   from   pdb_plug_in_violations
   where  status <> 'RESOLVED'
   order  by time;
   ```

3. **Look for ORDS_PUBLIC_USER or APEX_PUBLIC_USER sync failures**

   * If message includes *ORA-65177 during 'ALTER USER ...'* the PDB sync is stuck.

---

## Resolution Steps

1. **Disable restricted mode (if possible)**

```sql
   alter session set container = CDB$ROOT;
   alter pluggable database <pdbname> close immediate;
   alter pluggable database <pdbname> open read write;
```

   Recheck:

```sql
   select name, open_mode, restricted from v$pdbs where name='<pdbname>';
```

2. **If still restricted:**
   Run `scripts/sql/diagnostics/diag_pdb_violations.sql`
   and `scripts/sql/fixes/fix_clear_stuck_sync.sql` to remove stuck sync entries.

3. **Once unrestricted, restart ORDS**

```powershell
   ords --config "C:\ords\config" serve --port 8181
```

   Watch for:

```
   /ords/ => VALID
```

---

## Prevention

* Keep `ORDS_PUBLIC_USER` **local to the PDB**.
* Avoid altering or unlocking ORDS users from `CDB$ROOT`.
* Always verify `pdb_plug_in_violations` after maintenance.
* Run `datapatch -verbose` after RUs or RURs.

---

**Reference:**
`ORA-01035` = Restricted logins only. ORDS cannot connect when the DB or PDB is in restricted mode.

