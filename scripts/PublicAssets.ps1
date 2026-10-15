# Public packaging copies only reviewed example assets.
function Copy-PublicCharacter([string]$SourceRoot, [string]$DestinationRoot) {
    $configPath = Join-Path $SourceRoot 'character\character.json'
    $profile = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($emotion in @('neutral','happy','sad')) {
        $expected = 'portraits/example-'+$emotion+'.png'
        $spec = $profile.$emotion
        if ($spec.path -ne $expected -or $spec.columns -ne 1 -or $spec.index -ne 0) {
            throw 'Public packaging requires reviewed example portraits. Update the allowlist and ASSETS.md before distributing other artwork.'
        }
        if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot ('character\'+$expected)) -PathType Leaf)) { throw ('Missing public portrait: '+$expected) }
    }
    $target = Join-Path $DestinationRoot 'character'
    New-Item -ItemType Directory -Force -Path (Join-Path $target 'portraits') | Out-Null
    Copy-Item -LiteralPath $configPath -Destination $target
    foreach ($emotion in @('neutral','happy','sad')) {
        Copy-Item -LiteralPath (Join-Path $SourceRoot ('character\portraits\example-'+$emotion+'.png')) -Destination (Join-Path $target 'portraits')
    }
}
