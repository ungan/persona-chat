Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:StateDir = Join-Path $ProjectRoot '.run'

function Read-ChatEnv {
    param([string]$Path = (Join-Path $ProjectRoot '.env'))
    if (-not (Test-Path -LiteralPath $Path)) { throw 'Create .env from .env.example and set LLM_API_KEY and LLM_MODEL.' }
    $allowed = @('LLM_API_KEY','LLM_MODEL','CHAT_PORT','LLM_MAX_COMPLETION_TOKENS','CHAT_CONTEXT_CHAR_LIMIT','LLM_TEMPERATURE','LLM_REASONING_EFFORT','LLM_INSTRUCTION_ROLE')
    $values = @{CHAT_PORT='18081'; LLM_MODEL='gpt-4.1-mini'; LLM_MAX_COMPLETION_TOKENS='1024'; CHAT_CONTEXT_CHAR_LIMIT='20000'; LLM_TEMPERATURE=''; LLM_REASONING_EFFORT=''; LLM_INSTRUCTION_ROLE='system'}
    foreach ($line in [IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8)) {
        $entry = $line.Trim().TrimStart([char]0xFEFF)
        if (-not $entry -or $entry.StartsWith('#')) { continue }
        if ($entry -notmatch '^([A-Z_]+)\s*=(.*)$') { throw 'Invalid .env line. Use NAME=value; do not put comments after values.' }
        $key = $Matches[1]; $value = $Matches[2].Trim()
        if ($allowed -notcontains $key) { throw "Unsupported .env setting: $key" }
        if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        $values[$key] = $value
    }
    if (-not $values.ContainsKey('LLM_API_KEY') -or [string]::IsNullOrWhiteSpace($values.LLM_API_KEY) -or $values.LLM_API_KEY -eq 'your-api-key-here') { throw 'Set your own LLM_API_KEY in .env. Never paste the key into chat or GitHub.' }
    if ([string]::IsNullOrWhiteSpace($values.LLM_MODEL)) { throw 'Set LLM_MODEL in .env.' }
    $port = 0
    if (-not [int]::TryParse($values.CHAT_PORT, [ref]$port) -or $port -lt 1024 -or $port -gt 65535) { throw 'CHAT_PORT must be 1024..65535.' }
    return $values
}

function Get-ChatJava {
    param([switch]$RequireJdk)
    # Prefer a bundled runtime, then JAVA_HOME/PATH. Download a private JDK only if needed.
    $candidates = @()
    $runtime = Join-Path $ProjectRoot 'runtime'
    if (Test-Path -LiteralPath $runtime) { $candidates += @(Get-ChildItem -LiteralPath $runtime -Directory | ForEach-Object { Join-Path $_.FullName 'bin\java.exe' }) }
    if ($env:JAVA_HOME) { $candidates += Join-Path $env:JAVA_HOME 'bin\java.exe' }
    $command = Get-Command java.exe -ErrorAction SilentlyContinue
    if ($command) { $candidates += $command.Source }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            $info = New-Object Diagnostics.ProcessStartInfo
            $info.FileName = $candidate; $info.Arguments = '-version'; $info.UseShellExecute = $false
            $info.CreateNoWindow = $true; $info.RedirectStandardError = $true
            $proc = [Diagnostics.Process]::Start($info); $version = $proc.StandardError.ReadToEnd(); $proc.WaitForExit()
            $hasCompiler = Test-Path -LiteralPath (Join-Path (Split-Path $candidate) 'javac.exe')
            if ($version -match 'version "(\d+)' -and [int]$Matches[1] -eq 17 -and (-not $RequireJdk -or $hasCompiler)) { return $candidate }
        }
    }
    Write-Host 'Downloading a private Java 17 JDK (first run only)...'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $assets = Invoke-RestMethod -Uri 'https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse'
    $package = $assets[0].binary.package
    New-Item -ItemType Directory -Force -Path $runtime | Out-Null
    $archive = Join-Path $runtime 'jdk17.zip'
    Invoke-WebRequest -Uri $package.link -OutFile $archive -UseBasicParsing
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $package.checksum.ToLowerInvariant()) { throw 'Java archive checksum mismatch.' }
    Expand-Archive -LiteralPath $archive -DestinationPath $runtime -Force
    $java = @(Get-ChildItem -LiteralPath $runtime -Directory | ForEach-Object { Join-Path $_.FullName 'bin\java.exe' } | Where-Object {
        (Test-Path -LiteralPath $_) -and (-not $RequireJdk -or (Test-Path -LiteralPath (Join-Path (Split-Path $_) 'javac.exe')))
    })
    if ($java.Count -eq 0) { throw 'Java extraction failed.' }
    return $java[0]
}

function Get-ChatProcess {
    $stateFile = Join-Path $StateDir 'server.json'
    if (-not (Test-Path -LiteralPath $stateFile)) { return $null }
    $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
    $proc = Get-Process -Id $state.pid -ErrorAction SilentlyContinue
    if ($proc -and $proc.Path -eq $state.path -and [string]$proc.StartTime.ToUniversalTime().Ticks -eq [string]$state.ticks) { return $proc }
    return $null
}

function Save-ChatProcess($Process) {
    @{pid=$Process.Id; path=$Process.Path; ticks=[string]$Process.StartTime.ToUniversalTime().Ticks} | ConvertTo-Json |
        Set-Content -LiteralPath (Join-Path $StateDir 'server.json') -Encoding UTF8
}

function Build-ChatServer([string]$Java) {
    $savedJavaHome = $env:JAVA_HOME
    try {
        $env:JAVA_HOME = Split-Path (Split-Path $Java)
        Push-Location (Join-Path $ProjectRoot 'server')
        try {
            & .\gradlew.bat ("-Dorg.gradle.java.home=" + $env:JAVA_HOME) --no-daemon test bootJar
            if ($LASTEXITCODE -ne 0) { throw 'Java server build/tests failed.' }
        } finally { Pop-Location }
    } finally { $env:JAVA_HOME = $savedJavaHome }
}
