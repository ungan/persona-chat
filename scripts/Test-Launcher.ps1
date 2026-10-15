param([Parameter(Mandatory=$true)][string]$Package, [switch]$Offline)
. (Join-Path $PSScriptRoot 'Common.ps1')
$testRoot = Join-Path $StateDir ('launcher-check-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
Expand-Archive -LiteralPath $Package -DestinationPath $testRoot
$folder = (Get-ChildItem -LiteralPath $testRoot -Directory | Select-Object -First 1).FullName
$envPath = Join-Path $folder '.env'
$report = [Collections.Generic.List[string]]::new()
$launcher = $null
$player = $null
function Check([bool]$value,[string]$message) {
    if (-not $value) { throw $message }
    $report.Add('PASS '+$message)
}
function Invoke-LauncherCheck {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = 'powershell.exe'
    $info.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $folder 'scripts\Launch.ps1')+'"'
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [Text.Encoding]::UTF8
    $process = [Diagnostics.Process]::Start($info)
    $read = $process.StandardOutput.ReadToEndAsync()
    $errors = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(15000)) { $process.Kill(); throw 'Launcher rejection timed out.' }
    return @{code=$process.ExitCode; output=$read.Result}
}
try {
    Move-Item -LiteralPath $envPath -Destination (Join-Path $folder 'env-placeholder-backup.txt')
    $result = Invoke-LauncherCheck
    Check ($result.code -eq 2 -and $result.output.Contains('LLM_API_KEY') -and (Test-Path -LiteralPath $envPath)) 'missing .env creates template and shows setup instructions'
    [IO.File]::WriteAllText($envPath,"LLM_API_KEY=`nLLM_MODEL=gpt-4.1-mini`n",[Text.Encoding]::UTF8)
    $result = Invoke-LauncherCheck
    Check ($result.code -eq 2 -and $result.output.Contains('설정을 확인')) 'empty key refuses launch with Korean instructions'
    Copy-Item -LiteralPath (Join-Path $folder '.env.example') -Destination $envPath -Force
    $result = Invoke-LauncherCheck
    Check ($result.code -eq 2) 'placeholder key refuses launch'
    Check (-not (Test-Path -LiteralPath (Join-Path $folder '.run\server.json'))) 'missing-key checks start no server'
    $settings = if ($Offline) { "LLM_API_KEY=offline-launch-check-no-api-calls`nLLM_MODEL=gpt-4.1-mini`nCHAT_PORT=18084`n" } else { [IO.File]::ReadAllText((Join-Path $ProjectRoot '.env')) }
    if ($settings -match '(?m)^CHAT_PORT\s*=') { $settings = [regex]::Replace($settings,'(?m)^CHAT_PORT\s*=.*$','CHAT_PORT=18084') }
    else { $settings += "`nCHAT_PORT=18084`n" }
    [IO.File]::WriteAllText($envPath,$settings,[Text.Encoding]::UTF8)
    $settings = $null
    $launcher = Start-Process -FilePath $env:ComSpec -ArgumentList ('/d /c ""'+(Join-Path $folder '채팅 시작.cmd')+'""') -WorkingDirectory $folder -WindowStyle Hidden -PassThru
    $expires = (Get-Date).AddSeconds(60)
    $expectedExe = Join-Path $folder 'release\client\PersonaChat.exe'
    while ((Get-Date) -lt $expires) {
        $player = Get-Process PersonaChat -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $expectedExe } | Select-Object -First 1
        if ($player) { break }
        Start-Sleep -Milliseconds 250
    }
    Check ($null -ne $player) 'Korean named entry starts Windows app from extracted ZIP'
    $config = Get-Content -LiteralPath (Join-Path $folder '.run\client.json') -Raw | ConvertFrom-Json
    $state = Get-Content -LiteralPath (Join-Path $folder '.run\server.json') -Raw | ConvertFrom-Json
    $health = Invoke-RestMethod -Uri ($config.url+'/health') -Headers @{'X-Chat-Token'=$config.token} -TimeoutSec 10
    Check ($health.status -eq 'UP') 'bundled server starts with configured environment'
    $result = Invoke-LauncherCheck
    Check ($result.code -eq 1 -and $result.output.Contains('이미 실행')) 'second launch gives Korean duplicate notice'
    $players = @(Get-Process PersonaChat -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $expectedExe })
    $after = Get-Content -LiteralPath (Join-Path $folder '.run\server.json') -Raw | ConvertFrom-Json
    Check ($players.Count -eq 1 -and $after.pid -eq $state.pid -and $null -ne (Get-Process -Id $state.pid -ErrorAction SilentlyContinue)) 'duplicate launch preserves one app and original server'
    $playerLog = Join-Path $env:USERPROFILE 'AppData\LocalLow\PersonaChat\Persona Chat\Player.log'
    $expires = (Get-Date).AddSeconds(20)
    $connected = $false
    while ((Get-Date) -lt $expires) {
        if ((Test-Path -LiteralPath $playerLog) -and ((Get-Content -LiteralPath $playerLog -Raw) -match 'PersonaChat: connected to local server')) { $connected=$true; break }
        Start-Sleep -Milliseconds 250
    }
    Check $connected 'Windows app confirms connection to local server'
    Check ($player.CloseMainWindow()) 'normal window-close request accepted'
    Check ($player.WaitForExit(15000) -and $launcher.WaitForExit(15000)) 'app and launcher exit normally'
    Check ($null -eq (Get-Process -Id $state.pid -ErrorAction SilentlyContinue)) 'server stops after app closes'
} finally {
    if ($player -and -not $player.HasExited) { [void]$player.CloseMainWindow() }
    & (Join-Path $folder 'scripts\Stop.ps1')
    Copy-Item -LiteralPath (Join-Path $folder '.env.example') -Destination $envPath -Force
    New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot 'docs\previews') | Out-Null
    $report | Set-Content -LiteralPath (Join-Path $ProjectRoot 'docs\previews\launcher-verification.txt') -Encoding UTF8
    $report | Write-Output
}
