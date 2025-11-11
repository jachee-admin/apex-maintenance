param(
  [string]$SqlPlus = "sqlplus",
  [string]$DateTag = (Get-Date -Format yyyyMMdd_HHmmss)
)
echo foo
exit
# Determine repo paths
$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$diag   = Join-Path $here "..\sql\diagnostics\run_all_diagnostics.sql"
$diagDir= Split-Path -Parent $diag

# Also set SQLPATH so @child.sql works if you run them manually
$env:SQLPATH = $diagDir

# Call the driver, passing the diagnostics directory explicitly
# Use forward slashes so SQL*Plus is happy on Windows.
$diagDirPosix = $diagDir -replace '\\','/'
echo $diagDirPosix
#& $SqlPlus "/ as sysdba" "@$diag" "_date=$DateTag" "BASEDIR=$diagDirPosix"

#Write-Host "Diagnostics complete. See diag_report_$DateTag.log in the current directory."
