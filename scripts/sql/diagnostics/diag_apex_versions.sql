set pages 200 lines 200 trimspool on
col version format a12
prompt === APEX in CDB root ===
select comp_id, version, status
from   cdb_registry
where  con_id = 1 and comp_id = 'APEX';

prompt === APEX per-PDB ===
select v.con_id, p.name, r.comp_id, r.version, r.status
from   cdb_registry r
join   v$pdbs p on p.con_id = r.con_id
where  r.comp_id = 'APEX'
order  by v.con_id;

