param(
  [string]$SqlPlus="sqlplus",
  [string]$DateTag="$(Get-Date -Format yyyyMMdd_HHmmss)"
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$diag = Join-Path $here "..\sql\diagnostics\run_all_diagnostics.sql"
& $SqlPlus "/ as sysdba" "@$diag" "_date=$DateTag"
Write-Host "Diagnostics complete. See diag_report_$DateTag.log in current directory."

