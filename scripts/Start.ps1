param([switch]$ServerOnly, [string]$EnvFile)
. (Join-Path $PSScriptRoot 'Common.ps1')
if (-not $EnvFile) { $EnvFile = Join-Path $ProjectRoot '.env' }
$values = Read-ChatEnv -Path $EnvFile
$clientExe = Join-Path $ProjectRoot 'release\client\PersonaChat.exe'
if (-not $ServerOnly -and -not (Test-Path -LiteralPath $clientExe)) {
    throw 'Unity client is not built yet. Read README section 2, then run scripts\Build.ps1 -UnityEditor <Unity.exe>. For Editor Play mode use Start-Server.cmd.'
}
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
try { $lock = [IO.File]::Open((Join-Path $StateDir 'launch.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
catch [IO.IOException] {
    if (($_.Exception.HResult -band 65535) -in @(32,33)) { throw 'CHAT_ALREADY_RUNNING' }
    throw
}
$server = $null
try {
    $existingApp = Get-Process PersonaChat -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $clientExe } | Select-Object -First 1
    if ($existingApp) { throw 'CHAT_ALREADY_RUNNING' }
    if (Get-ChatProcess) { throw 'This project server is already running. Use Stop.cmd before restarting/changing .env.' }
    $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, [int]$values.CHAT_PORT)
    try { $listener.Start() } catch { throw 'CHAT_PORT is already in use. Stop the previous server or change CHAT_PORT in .env.' }
    finally { $listener.Stop() }
    $java = Get-ChatJava
    $jar = Join-Path $ProjectRoot 'server\build\libs\persona-chat-server.jar'
    if (-not (Test-Path -LiteralPath $jar)) { $java = Get-ChatJava -RequireJdk; Build-ChatServer $java }
    $random = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($random) } finally { $rng.Dispose() }
    $token = [Convert]::ToBase64String($random)
    $configPath = Join-Path $StateDir 'client.json'
    @{url=('http://127.0.0.1:'+$values.CHAT_PORT+'/api'); token=$token; contentRoot=$ProjectRoot} | ConvertTo-Json |
        Set-Content -LiteralPath $configPath -Encoding UTF8
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $java; $info.Arguments = '-jar "'+$jar+'"'; $info.WorkingDirectory = $ProjectRoot
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    foreach ($name in $values.Keys) { $info.EnvironmentVariables[$name] = $values[$name] }
    $info.EnvironmentVariables['CHAT_CLIENT_TOKEN'] = $token
    $info.EnvironmentVariables['CHAT_PROMPT_DIR'] = Join-Path $ProjectRoot 'prompts'
    $info.EnvironmentVariables['CHAT_CHARACTER_FILE'] = Join-Path $ProjectRoot 'character\character.json'
    $info.EnvironmentVariables['LOGGING_FILE_NAME'] = Join-Path $StateDir 'server.log'
    # Do not inherit unrelated framework debug/config flags into the portable app.
    foreach ($name in @('JAVA_TOOL_OPTIONS','JDK_JAVA_OPTIONS','_JAVA_OPTIONS','SPRING_APPLICATION_JSON','SPRING_CONFIG_LOCATION','SPRING_CONFIG_ADDITIONAL_LOCATION','SPRING_PROFILES_ACTIVE')) {
        $info.EnvironmentVariables.Remove($name)
    }
    $server = [Diagnostics.Process]::Start($info)
    Save-ChatProcess $server
    $healthy = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        if ($server.HasExited) { throw 'Server exited during startup. Check .env and prompts. Run scripts\Diagnose.ps1 for details.' }
        try {
            $health = Invoke-RestMethod -Uri ('http://127.0.0.1:'+$values.CHAT_PORT+'/api/health') -Headers @{'X-Chat-Token'=$token} -TimeoutSec 2
            if ($health.service -eq 'persona-chat') { $healthy = $true; break }
        } catch { }
        Start-Sleep -Milliseconds 500
    }
    if (-not $healthy) { throw 'Server startup timed out.' }
    Write-Host ('Server ready: 127.0.0.1:'+$values.CHAT_PORT+' / model: '+$health.model)
    if ($ServerOnly) { Write-Host 'Open the Unity client project and press Play. Stop.cmd stops the server.' }
    else {
        $appInfo = New-Object Diagnostics.ProcessStartInfo
        $appInfo.FileName = $clientExe; $appInfo.Arguments = '--config "'+$configPath+'"'; $appInfo.UseShellExecute = $false
        $appInfo.WorkingDirectory = Split-Path $clientExe
        foreach ($name in @('LLM_API_KEY','OPENAI_API_KEY','CHAT_CLIENT_TOKEN')) { $appInfo.EnvironmentVariables.Remove($name) }
        $app = [Diagnostics.Process]::Start($appInfo)
        Write-Host 'Chat opened. Closing the chat window also stops this server.'
        $app.WaitForExit()
        $owned = Get-ChatProcess
        if ($owned -and $owned.Id -eq $server.Id) { Stop-Process -Id $owned.Id -Force }
    }
} catch {
    if ($server) {
        $owned = Get-ChatProcess
        if ($owned -and $owned.Id -eq $server.Id) { Stop-Process -Id $owned.Id -Force }
    }
    throw
} finally { $lock.Dispose() }
