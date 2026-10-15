. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'PublicAssets.ps1')
$exe = Join-Path $ProjectRoot 'release\client\PersonaChat.exe'
$jar = Join-Path $ProjectRoot 'server\build\libs\persona-chat-server.jar'
$runtime = Join-Path $ProjectRoot 'runtime\java17'
if (-not (Test-Path -LiteralPath $exe)) { throw 'Build the Unity Windows client first. A source-only folder is not a runnable release.' }
if (-not (Test-Path -LiteralPath $jar)) { throw 'Build the Java server first.' }
if (-not (Test-Path -LiteralPath $runtime)) { & (Join-Path $PSScriptRoot 'Build-Runtime.ps1') }
$dist = Join-Path $ProjectRoot 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$name = 'PersonaChat-Public-Windows-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,6)
$out = Join-Path $dist $name
New-Item -ItemType Directory -Path $out | Out-Null
foreach ($dir in @('scripts','release','runtime','server\build\libs')) { New-Item -ItemType Directory -Force -Path (Join-Path $out $dir) | Out-Null }
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'release\client') -Destination (Join-Path $out 'release') -Recurse
Copy-Item -LiteralPath $runtime -Destination (Join-Path $out 'runtime') -Recurse
Copy-Item -LiteralPath $jar -Destination (Join-Path $out 'server\build\libs')
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'prompts') -Destination $out -Recurse
Copy-PublicCharacter $ProjectRoot $out
foreach ($file in @('00_처음_사용하기.txt','채팅 시작.cmd','Start.cmd','Stop.cmd','README.md','LICENSE','ASSETS.md','THIRD_PARTY.md','.env.example')) {
    Copy-Item -LiteralPath (Join-Path $ProjectRoot $file) -Destination $out
}
foreach ($file in @('Common.ps1','Start.ps1','Launch.ps1','Stop.ps1','Diagnose.ps1','Get-DownloadStats.ps1')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $out 'scripts')
}
New-Item -ItemType Directory -Force -Path (Join-Path $out 'docs') | Out-Null
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'docs\DEMO.md') -Destination (Join-Path $out 'docs')
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'docs\MANUAL.md') -Destination (Join-Path $out 'docs')
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'docs\DOWNLOADS.md') -Destination (Join-Path $out 'docs')
New-Item -ItemType Directory -Force -Path (Join-Path $out 'docs\images') | Out-Null
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'docs\images\chat-preview.png') -Destination (Join-Path $out 'docs\images')
# Never copy the developer's .env, local client token, logs, or chat data.
Copy-Item -LiteralPath (Join-Path $ProjectRoot '.env.example') -Destination (Join-Path $out '.env')
Compress-Archive -LiteralPath $out -DestinationPath (Join-Path $dist ($name+'.zip'))
Write-Host ('Release ZIP: '+(Join-Path $dist ($name+'.zip')))
