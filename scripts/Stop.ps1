. (Join-Path $PSScriptRoot 'Common.ps1')
$proc = Get-ChatProcess
if ($proc) { Stop-Process -Id $proc.Id -Force; Write-Host 'Persona Chat server stopped.' }
else { Write-Host 'No owned Persona Chat server is running.' }
