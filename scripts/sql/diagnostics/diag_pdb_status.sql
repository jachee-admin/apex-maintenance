set pages 200 lines 200 trimspool on
col name format a20
prompt === Instance login mode ===
select logins from v$instance;

prompt === PDB states ===
select con_id, name, open_mode, restricted from v$pdbs order by con_id;

prompt === instance restricted parameter ===
show parameter restricted

