<#
.SYNOPSIS
  Safe wrapper to run Oracle OPatch datapatch -verbose across a CDB and all open PDBs.

.DESCRIPTION
  - Opens all PDBs READ WRITE (if possible).
  - Shows unresolved PDB plug-in violations (and aborts unless -Force is set).
  - Runs datapatch -verbose from $OracleHome\OPatch.
  - Validates results via CDB_REGISTRY_SQLPATCH.
  - Saves full logs to -LogDir.

.PARAMETER OracleHome
  ORACLE_HOME path (e.g. C:\oracle\product\23.4.0\dbhome_1)

.PARAMETER OracleSid
  CDB instance name (e.g. FREECDB1)

.PARAMETER SqlPlus
  Path to sqlplus.exe (defaults to auto-resolve in PATH)

.PARAMETER LogDir
  Directory for logs (defaults to ./logs)

.PARAMETER Force
  Proceed even if plug-in violations are detected.

.EXAMPLE
  .\fix_run_datapatch.ps1 -OracleHome "C:\oracle\dbhome_1" -OracleSid FREECDB1

.EXAMPLE
  .\fix_run_datapatch.ps1 -OracleHome "C:\oracle\dbhome_1" -OracleSid FREECDB1 -Force
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$OracleHome,
  [Parameter(Mandatory=$true)][string]$OracleSid,
  [string]$SqlPlus = "sqlplus",
  [string]$LogDir = ".\logs",
  [switch]$Force
)

$ErrorActionPreference = "Stop"

# Prep
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$Log = Join-Path $LogDir "datapatch_${OracleSid}_$ts.log"
$SqlLog = Join-Path $LogDir "precheck_${OracleSid}_$ts.log"
$PostLog = Join-Path $LogDir "postcheck_${OracleSid}_$ts.log"

Write-Host "=== fix_run_datapatch.ps1 @ $ts ==="
Write-Host "ORACLE_HOME: $OracleHome"
Write-Host "ORACLE_SID : $OracleSid"
Write-Host "SqlPlus    : $SqlPlus"
Write-Host "Logs       : $Log"

# Validate paths
$DataPatch = Join-Path $OracleHome "OPatch\datapatch.bat"
if (-not (Test-Path $DataPatch)) {
  throw "datapatch not found at $DataPatch"
}

# Set env for child processes
$env:ORACLE_HOME = $OracleHome
$env:ORACLE_SID  = $OracleSid
$env:PATH        = "$OracleHome\bin;$env:PATH"

# Pre-checks: open PDBs, show violations
$preSql = @"
set pages 200 lines 200
column name format a20
prompt === Instance / PDB states BEFORE datapatch ===
select logins from v`$instance;
select con_id, name, open_mode, restricted from v`$pdbs order by con_id;

prompt === Attempt to open all PDBs READ WRITE (ignore errors) ===
alter session set container = CDB`$ROOT;
begin
  for r in (select name from v`$pdbs where name not in ('PDB$SEED')) loop
    begin
      execute immediate 'alter pluggable database '||r.name||' open read write';
    exception when others then null;
    end;
  end loop;
end;
/

prompt === Unresolved plug-in violations (should be empty) ===
column cause format a40
column status format a10
column message format a120
select name, cause, type, status, message
from   pdb_plug_in_violations
where  status <> 'RESOLVED'
order  by time;
"@

$preSql | Out-File -FilePath $SqlLog -Encoding ascii
& $SqlPlus "/ as sysdba" "@$SqlLog" | Tee-Object -FilePath $SqlLog

# If violations exist and not forcing, abort
$violations = (& $SqlPlus -s "/ as sysdba" "set pages 0 feed off; select count(*) from pdb_plug_in_violations where status <> 'RESOLVED';")
if (($violations.Trim() -as [int]) -gt 0 -and -not $Force) {
  Write-Warning "Unresolved plug-in violations detected ($violations). Fix them or run with -Force."
  Write-Host "See $SqlLog"
  exit 2
}

# Run datapatch -verbose
Write-Host "=== Running datapatch -verbose ==="
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $DataPatch
$psi.Arguments = "-verbose"
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.UseShellExecute = $false
$proc = [System.Diagnostics.Process]::Start($psi)
$stdOut = $proc.StandardOutput.ReadToEnd()
$stdErr = $proc.StandardError.ReadToEnd()
$proc.WaitForExit()

$stdOut | Out-File -FilePath $Log -Encoding ascii
if ($stdErr) { "`n=== STDERR ===`n$stdErr" | Out-File -Append -FilePath $Log }

if ($proc.ExitCode -ne 0) {
  Write-Warning "datapatch exited with code $($proc.ExitCode). Review $Log"
  exit $proc.ExitCode
}

Write-Host "datapatch completed. Log: $Log"

# Post-checks
$postSql = @"
set pages 200 lines 200
prompt === PDB states AFTER datapatch ===
select con_id, name, open_mode, restricted from v`$pdbs order by con_id;

prompt === SQL patches applied (last 20) ===
column name format a20
select p.name, sp.status, to_char(sp.action_time,'YYYY-MM-DD HH24:MI') action_time, sp.description
from   cdb_registry_sqlpatch sp
join   v`$pdbs p on p.con_id = sp.con_id
order  by sp.action_time desc fetch first 20 rows only;
"@

$postSql | Out-File -FilePath $PostLog -Encoding ascii
& $SqlPlus "/ as sysdba" "@$PostLog" | Tee-Object -FilePath $PostLog

Write-Host "=== Done. See logs: $SqlLog, $Log, $PostLog ==="
