set pages 200 lines 200 trimspool on
prompt === Invalid objects in each PDB (top 50) ===
col owner format a20
col object_name format a30
select * from (
  select p.name, o.owner, o.object_type, o.object_name, o.status
  from   cdb_objects o
  join   v$pdbs p on p.con_id = o.con_id
  where  o.status <> 'VALID'
  order  by p.con_id, o.owner
) where rownum <= 50;

