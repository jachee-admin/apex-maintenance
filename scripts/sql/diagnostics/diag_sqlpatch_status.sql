set pages 200 lines 200 trimspool on
col username format a20
col account_status format a20
prompt === Common vs Local user check (ORDS/APEX) ===
select con_id, username, common, account_status
from   cdb_users
where  username in ('ORDS_PUBLIC_USER','APEX_PUBLIC_USER','APEX_230200','APEX_240200') -- add your schema names as needed
order  by username, con_id;

