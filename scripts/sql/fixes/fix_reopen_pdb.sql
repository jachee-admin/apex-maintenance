-- Reopen a PDB cleanly and save state
-- Usage: sqlplus / as sysdba @fix_reopen_pdb.sql PDB=FREEPDB1
define PDB="FREEPDB1"

set echo on
show con_name
alter session set container = CDB$ROOT;
alter pluggable database &PDB close immediate;
alter pluggable database &PDB open read write;

-- verify
select name, open_mode, restricted from v$pdbs where name='&PDB';

-- persist
alter pluggable database &PDB save state;

