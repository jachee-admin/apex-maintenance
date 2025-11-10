-- CALL WITH: sqlplus / as sysdba @run_all_diagnostics.sql _date="$(date +%Y%m%d_%H%M%S)"

spool diag_report_&&_date..log
prompt === RUN: diag_pdb_status ===
@diag_pdb_status.sql

prompt === RUN: diag_pdb_violations ===
@diag_pdb_violations.sql

prompt === RUN: diag_apex_versions ===
@diag_apex_versions.sql

prompt === RUN: diag_sqlpatch_status ===
@diag_sqlpatch_status.sql

prompt === RUN: diag_common_local_conflicts ===
@diag_common_local_conflicts.sql

prompt === RUN: diag_invalid_objects ===
@diag_invalid_objects.sql

spool off
prompt Report written to diag_report_&&_date..log

