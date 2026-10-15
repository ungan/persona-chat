param([Parameter(Mandatory=$true)][string]$ReleaseZip)
. (Join-Path $PSScriptRoot 'Common.ps1')
if (-not (Test-Path -LiteralPath $ReleaseZip -PathType Leaf)) { throw 'Build the public Windows release ZIP with Package.ps1 first.' }
if ([IO.Path]::GetFileName($ReleaseZip) -notlike 'PersonaChat-Public-Windows-*.zip') { throw 'Only a public Windows package may be bundled.' }
$source = & (Join-Path $PSScriptRoot 'Prepare-GitHub.ps1')
$id = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,6)
$share = Join-Path $ProjectRoot ('dist\PersonaChat-Public-Share-'+$id)
New-Item -ItemType Directory -Path $share | Out-Null
Copy-Item -LiteralPath (Join-Path $ProjectRoot '00_처음_사용하기.txt') -Destination (Join-Path $share '00_먼저읽기.txt')
Copy-Item -LiteralPath $ReleaseZip -Destination (Join-Path $share '01_PersonaChat_실행용.zip')
Copy-Item -LiteralPath $source.Zip -Destination (Join-Path $share '02_PersonaChat_소스.zip')
Compress-Archive -LiteralPath $share -DestinationPath ($share+'.zip')
Write-Host ('Public share ZIP: '+$share+'.zip')
