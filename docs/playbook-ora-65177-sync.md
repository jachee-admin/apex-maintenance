### `docs/playbook-ora-65177-sync.md`

# Playbook: ORA-65177 — PDB Sync Failures on User DDL

**Symptom:**


PDB opens `READ WRITE` but remains `RESTRICTED=YES`.
`pdb_plug_in_violations` shows:
````

Sync PDB failed with ORA-65177 during 'ALTER USER ORDS_PUBLIC_USER IDENTIFIED BY ...'

````

---

## Root Cause

- `ORA-65177` = “conflicting local and common object.”
- A DDL executed in `CDB$ROOT` (such as unlocking or changing a common user) attempted to replay inside a PDB that already has a *local* user of the same name.
- The DDL fails, leaving the sync queue (`pdb_sync$`) dirty → PDB opens in restricted mode until resolved.

---

## Diagnosis

1. Check violations:
```sql
   select name, cause, type, status, message
   from   pdb_plug_in_violations
   where  status <> 'RESOLVED'
   order  by time;
```

2. Check user common/local status:

```sql
   select con_id, username, common, account_status
   from   cdb_users
   where  username='ORDS_PUBLIC_USER'
   order  by con_id;
```

---

## Fix Procedure

1. **Backup and delete the stuck sync rows.**

```sql
   -- in CDB$ROOT
   create table pdb_sync_backup_root as
     select * from pdb_sync$ where sqlstmt like '%ORDS_PUBLIC_USER%';
   delete from pdb_sync$ where sqlstmt like '%ORDS_PUBLIC_USER%';
   commit;

   -- in PDB
   alter session set container = <pdbname>;
   create table pdb_sync_backup_pdb as
     select * from sys.pdb_sync$ where sqlstmt like '%ORDS_PUBLIC_USER%';
   delete from sys.pdb_sync$ where sqlstmt like '%ORDS_PUBLIC_USER%';
   commit;
```

2. **Reopen the PDB cleanly**

```sql
   alter session set container = CDB$ROOT;
   alter pluggable database <pdbname> close immediate;
   alter pluggable database <pdbname> open read write;
   alter pluggable database <pdbname> save state;
```

3. **Validate user**

```sql
   alter session set container = <pdbname>;
   alter user ORDS_PUBLIC_USER identified by "<newpassword>" account unlock;
```

---

## Prevention

* Do not maintain ORDS/APEX users from root.
* Keep APEX and ORDS users **local-only**.
* After patching, run:

```sql
  select * from pdb_plug_in_violations where status <> 'RESOLVED';
```
* Remove any common `ORDS_PUBLIC_USER` if per-PDB model is desired.

---

**Reference:**

* ORA-65177: conflict between local and common metadata.
* Fixed by clearing failed DDL from sync queue.


