-- Optional, temporary: allow specific users to connect during restricted mode
-- Usage: sqlplus / as sysdba @fix_optional_grant_restricted.sql PDB=FREEPDB1 USERNAME=ORDS_PUBLIC_USER
define PDB="FREEPDB1"
define USERNAME="ORDS_PUBLIC_USER"

alter session set container = &PDB;
grant restricted session to &USERNAME;
-- Revoke later:
-- revoke restricted session from &USERNAME;

