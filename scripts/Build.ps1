param([string]$UnityEditor, [switch]$ServerOnly)
. (Join-Path $PSScriptRoot 'Common.ps1')
$java = Get-ChatJava -RequireJdk
Build-ChatServer $java
if ($ServerOnly) { exit 0 }
if (-not $UnityEditor) {
    $standard = 'C:\Program Files\Unity\Hub\Editor\6000.3.26f1\Editor\Unity.exe'
    if (Test-Path -LiteralPath $standard) { $UnityEditor = $standard }
}
if (-not $UnityEditor -or -not (Test-Path -LiteralPath $UnityEditor -PathType Leaf)) { throw 'Install Unity 6000.3.26f1 with Windows Build Support, then pass -UnityEditor <absolute Unity.exe path>.' }
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
$unityProject = Join-Path $ProjectRoot 'client'
$log = Join-Path $StateDir 'unity-build.log'
$argsText = '-batchmode -quit -projectPath "'+$unityProject+'" -executeMethod PersonaChat.Editor.ChatBuild.Windows -buildTarget Win64 -logFile "'+$log+'"'
$proc = Start-Process -FilePath $UnityEditor -ArgumentList $argsText -PassThru -WindowStyle Hidden
$proc.WaitForExit(); $proc.Refresh()
if ($proc.ExitCode -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $ProjectRoot 'release\client\PersonaChat.exe'))) { throw "Unity build failed. Read $log" }
Write-Host 'Build complete. Fill .env, then run Start.cmd.'
