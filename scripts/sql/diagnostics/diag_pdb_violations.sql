set pages 200 lines 200 trimspool on
col name format a20
col cause format a40
col type format a10
col status format a10
col message format a120
col action format a120

prompt === Unresolved plug-in violations (all PDBs) ===
select name, cause, type, status, message, action, time
from   pdb_plug_in_violations
where  status <> 'RESOLVED'
order  by time;

