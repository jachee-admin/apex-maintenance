   set pages 300 lines 200 trimspool on
col name          format a24
col pdb_name      format a24
col network_name  format a40
col con_id        format 999
col pdb           format a16
col failover      format a10
col preferred     format a10
col aq_ha_notifications format a3

prompt === Listener target (DB-side) ===
show parameter local_listener
show parameter remote_listener

prompt === Database services and their owning PDBs ===
-- v$services shows runtime services; cdb_services shows CDB/PDB mappings (23c/19c)
WITH svc AS (
    SELECT s.name,
           s.network_name,
           s.con_id,
           s.failover_method,
           s.failover_type,
           s.failover_retries,
           s.failover_delay,
           s.goal,
           s.drp_method
      FROM v$services s
),p AS (
    SELECT con_id,
           name pdb_name
      FROM v$pdbs
)
SELECT s.name,
       nvl(
           p.pdb_name,
           CASE
               WHEN s.con_id = 1 THEN
                       'CDB$ROOT'
           END
       ) AS pdb_name,
       s.network_name,
       s.con_id
  FROM svc s
  LEFT JOIN p
ON p.con_id = s.con_id
 ORDER BY s.con_id,
          s.name;

prompt === cdb_services (if populated) ===
SELECT name,
       pdb,
       network_name,
       aq_ha_notifications
  FROM cdb_services
 ORDER BY pdb,
          name;

prompt === Active services by instance (GV$SERVICES) ===
col inst_id format 999
SELECT inst_id,
       name,
       network_name,
       con_id
  FROM gv$services
 ORDER BY inst_id,
          con_id,
          name;

prompt === Service => PDB readiness checklist ===
-- 1) Service name you configure in ORDS must belong to the TARGET PDB, not CDB$ROOT
-- 2) Service must be ONLINE and resolving via your listener (check OS: lsnrctl status)
-- 3) TNS alias should map to this service; verify with: sqlplus user@tns_alias
-- 4) ORDS pool must be configured with db.connectionType=service and db.serviceName=<PDB service>

prompt === Quick TNS sanity (optional): show your current DB name and service ===
SELECT name
  FROM v$database;
SELECT sys_context(
    'USERENV',
    'SERVICE_NAME'
) AS current_service
  FROM dual;

prompt === Tip (outside SQL): ===
prompt lsnrctl status
prompt   -> confirm the service for your PDB appears under Services Summary
prompt tnsping <your_tns_alias>
prompt   -> confirm resolution to the correct host/port/service