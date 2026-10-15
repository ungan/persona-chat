. (Join-Path $PSScriptRoot 'Common.ps1')
$values = Read-ChatEnv
Write-Host ('Project: '+$ProjectRoot)
Write-Host ('API key: configured (value hidden); model: '+$values.LLM_MODEL)
Write-Host ('Unity build exists: '+(Test-Path -LiteralPath (Join-Path $ProjectRoot 'release\client\PersonaChat.exe')))
$proc = Get-ChatProcess
if ($proc) {
    $config = Get-Content -LiteralPath (Join-Path $StateDir 'client.json') -Raw | ConvertFrom-Json
    $health = Invoke-RestMethod -Uri ($config.url+'/health') -Headers @{'X-Chat-Token'=$config.token} -TimeoutSec 5
    Write-Host ('Server: '+$health.status+' / '+$health.model)
} else { Write-Host 'Server: stopped' }
