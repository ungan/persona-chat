. (Join-Path $PSScriptRoot 'Common.ps1')
if (Get-ChatProcess) { throw 'Stop this project server before running the smoke test.' }
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
$socket = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
$socket.Start(); $testPort = $socket.LocalEndpoint.Port; $socket.Stop()
$testEnv = Join-Path $StateDir 'smoke-test.env'
@('LLM_API_KEY=mock-key-never-sent-to-openai','LLM_MODEL=smoke-test-model',('CHAT_PORT='+$testPort)) | Set-Content -LiteralPath $testEnv -Encoding UTF8
try {
    & (Join-Path $PSScriptRoot 'Start.ps1') -ServerOnly -EnvFile $testEnv
    $config = Get-Content -LiteralPath (Join-Path $StateDir 'client.json') -Raw | ConvertFrom-Json
    if ((Get-Content -LiteralPath (Join-Path $StateDir 'client.json') -Raw).Contains('mock-key')) { throw 'API key leaked into client config.' }
    $health = Invoke-RestMethod -Uri ($config.url+'/health') -Headers @{'X-Chat-Token'=$config.token}
    if ($health.model -ne 'smoke-test-model') { throw '.env model was not used.' }
    try { Invoke-RestMethod -Uri ($config.url+'/health') | Out-Null; throw 'Missing token was accepted.' }
    catch { if (-not $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 403) { throw } }
    try {
        Invoke-RestMethod -Method Post -Uri ($config.url+'/chat') -Headers @{'X-Chat-Token'=$config.token} -ContentType 'application/json' -Body '{"stage":3,"messages":[]}' | Out-Null
        throw 'Invalid chat payload was accepted.'
    } catch { if (-not $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 400) { throw } }
    $blocked = $false
    try { & (Join-Path $PSScriptRoot 'Start.ps1') -ServerOnly -EnvFile $testEnv } catch { $blocked = $true }
    if (-not $blocked) { throw 'Duplicate launch was accepted.' }
    if (-not (Get-ChatProcess)) { throw 'Duplicate launch accidentally stopped the existing server.' }
    Write-Host 'PASS: portable Java, launcher, model config, health, token rejection, invalid request, duplicate launch. No real API call.'
} finally {
    & (Join-Path $PSScriptRoot 'Stop.ps1')
    Remove-Item -LiteralPath $testEnv -ErrorAction SilentlyContinue
}
