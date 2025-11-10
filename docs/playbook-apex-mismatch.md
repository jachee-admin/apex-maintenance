### `docs/playbook-apex-mismatch.md`

# Playbook: APEX Version Mismatch (Root vs PDB)

**Symptom:**
PDB opens `READ WRITE RESTRICTED`.
`pdb_plug_in_violations` shows:

```
APEX component version mismatch between CDB and PDB
````

---

## Diagnosis

1. Compare versions:
```sql
   -- root
   select comp_id, version, status from cdb_registry where con_id = 1 and comp_id='APEX';
   -- pdb
   alter session set container = <pdbname>;
   select comp_id, version, status from dba_registry where comp_id='APEX';
```

2. If the versions differ → violation confirmed.


## Fix Option 1 — Match PDB to Root (most common)

```sql
-- In PDB
@apxremov.sql       -- removes old APEX
@apexins.sql SYSAUX SYSAUX TEMP /i/
@?/rdbms/admin/utlrp.sql
```

Then reopen and save state:

```sql
alter session set container = CDB$ROOT;
alter pluggable database <pdbname> close immediate;
alter pluggable database <pdbname> open read write;
alter pluggable database <pdbname> save state;
```

---

## Fix Option 2 — Remove APEX from Root, keep per-PDB

If you prefer isolated APEX installs:

```sql
-- In root
@apxremov.sql

-- In each PDB
@apexins.sql SYSAUX SYSAUX TEMP /i/
@?/rdbms/admin/utlrp.sql
```

---

## Verification

```sql
select name, open_mode, restricted from v$pdbs;
select comp_id, version, status from dba_registry where comp_id='APEX';
```

Expect `RESTRICTED=NO`, versions identical.

---

## Notes

* APEX in root replicates to new PDBs; many DBAs now prefer *per-PDB only*.
* Always re-run `datapatch -verbose` after patching or upgrading APEX.
* Keep `/i/` (images) directory synchronized with installed APEX version.

