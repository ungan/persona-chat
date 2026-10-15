. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'PublicAssets.ps1')
$name = 'PersonaChat-Public-Source-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,6)
$out = Join-Path $ProjectRoot ('github-ready\'+$name)
New-Item -ItemType Directory -Force -Path $out | Out-Null
$roots = @('client\Assets','client\Packages','client\ProjectSettings','server\src','server\gradle','scripts','prompts')
foreach ($root in $roots) {
    Get-ChildItem -LiteralPath (Join-Path $ProjectRoot $root) -File -Recurse | ForEach-Object {
        $relative = $_.FullName.Substring($ProjectRoot.Length+1).Replace('\','/')
        if ($relative -match '(^|/)(_Recovery|Checks)(/|\.meta$)' -or
            $relative -match '\.(png|jpg|jpeg|gif|webp|psd|mp4|zip|log|bak|tmp)(\.meta)?$' -or
            $relative -match '/(ARTWORK|POSES)\.md(\.meta)?$') { return }
        $destination = Join-Path $out $relative
        New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $destination
    }
}
Copy-PublicCharacter $ProjectRoot $out
foreach ($file in @('server\build.gradle','server\settings.gradle','server\gradlew','server\gradlew.bat','00_처음_사용하기.txt','채팅 시작.cmd','Start.cmd','Start-Server.cmd','Stop.cmd','README.md','LICENSE','ASSETS.md','THIRD_PARTY.md','.env.example','.gitignore','.gitattributes')) {
    Copy-Item -LiteralPath (Join-Path $ProjectRoot $file) -Destination (Join-Path $out $file)
}
New-Item -ItemType Directory -Force -Path (Join-Path $out 'docs') | Out-Null
foreach ($file in @('MANUAL.md','DEMO.md','DOWNLOADS.md')) {
    Copy-Item -LiteralPath (Join-Path $ProjectRoot ('docs\'+$file)) -Destination (Join-Path $out 'docs')
}
New-Item -ItemType Directory -Force -Path (Join-Path $out 'docs\images') | Out-Null
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'docs\images\chat-preview.png') -Destination (Join-Path $out 'docs\images\chat-preview.png')
Compress-Archive -LiteralPath $out -DestinationPath ($out+'.zip')
Write-Host ('Public source ZIP: '+$out+'.zip')
[pscustomobject]@{Folder=$out; Zip=($out+'.zip')}
