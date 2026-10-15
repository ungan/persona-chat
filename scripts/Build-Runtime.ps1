. (Join-Path $PSScriptRoot 'Common.ps1')
$java = Get-ChatJava -RequireJdk
$jlink = Join-Path (Split-Path $java) 'jlink.exe'
$output = Join-Path $ProjectRoot 'runtime\java17'
if (Test-Path -LiteralPath $output) { throw 'runtime\java17 already exists. Use the existing runtime, or move it aside before rebuilding.' }
& $jlink --add-modules java.se,jdk.crypto.ec,jdk.unsupported,jdk.charsets --strip-debug --no-header-files --no-man-pages --output $output
if ($LASTEXITCODE -ne 0) { throw 'Java runtime build failed.' }
Write-Host 'Portable Java runtime created in runtime\java17.'
