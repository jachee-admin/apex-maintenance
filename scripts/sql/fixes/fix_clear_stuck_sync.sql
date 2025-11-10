-- Clears stuck PDB sync rows that reference ORDS/APEX user DDL.
-- Run in ROOT *and* then in the affected PDB.
-- Usage:
--   sqlplus / as sysdba @fix_clear_stuck_sync.sql USERNAME=ORDS_PUBLIC_USER
--
define USERNAME="ORDS_PUBLIC_USER"

set serveroutput on verify off feed on pages 200 lines 200
col sqlstmt format a120

prompt === BACKUP then DELETE from pdb_sync$ in ROOT where SQL includes &USERNAME ===
create table pdb_sync_backup_root as
select * from pdb_sync$ where upper(sqlstmt) like upper('%&USERNAME%');

delete from pdb_sync$ where upper(sqlstmt) like upper('%&USERNAME%');
commit;

prompt === Switch to affected PDB BEFORE running this block again ===
prompt In PDB session, we will:
prompt   create table pdb_sync_backup_pdb as select * from sys.pdb_sync$ ...
prompt   delete from sys.pdb_sync$ where upper(sqlstmt) like upper('%&USERNAME%');
prompt   commit;

