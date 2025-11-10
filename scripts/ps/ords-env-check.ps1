# Collects Windows env + ORDS config + sqlplus path for quick triage.
Write-Host "=== Host/Env ==="
[System.Environment]::OSVersion.VersionString
Write-Host "JAVA_HOME:" $env:JAVA_HOME
Write-Host "ORACLE_HOME:" $env:ORACLE_HOME
Write-Host "NLS_LANG:" $env:NLS_LANG
Write-Host "PATH (first 5):"
$env:Path.Split(';') | Select-Object -First 5 | ForEach-Object { " - $_" }

Write-Host "`n=== Which sqlplus ==="
$which = (Get-Command sqlplus.exe -ErrorAction SilentlyContinue)
$which | Format-List *

Write-Host "`n=== ORDS version/config ==="
ords --version
ords --config "C:\ords\config" config list

Write-Host "`nTip: ensure db.serviceName points to the PDB service, not CDB$ROOT."

