-- Run with: sqlplus "/ as sysdba" @run_all_diagnostics.sql _date=YYYYMMDD_HH24MISS BASEDIR=/full/path/to/scripts/sql/diagnostics
set define on verify off serveroutput on feedback on lines 200 pages 200 trimspool on

-- sanity: BASEDIR must be provided
column _bd new_value _BASEDIR
select '&&BASEDIR' "_BD" from dual;

spool diag_report_&&_date..log

prompt === Using BASEDIR: &&_BASEDIR ===

prompt === RUN: diag_pdb_status ===
@"&&_BASEDIR/diag_pdb_status.sql"

prompt === RUN: diag_pdb_violations ===
@"&&_BASEDIR/diag_pdb_violations.sql"

prompt === RUN: diag_apex_versions ===
@"&&_BASEDIR/diag_apex_versions.sql"

prompt === RUN: diag_sqlpatch_status ===
@"&&_BASEDIR/diag_sqlpatch_status.sql"

prompt === RUN: diag_common_local_conflicts ===
@"&&_BASEDIR/diag_common_local_conflicts.sql"

prompt === RUN: diag_invalid_objects ===
@"&&_BASEDIR/diag_invalid_objects.sql"

spool off
prompt Report written to diag_report_&&_date..log
