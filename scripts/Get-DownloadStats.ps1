param(
    [string]$Owner = 'ungan',
    [string]$Repository = 'persona-chat',
    [switch]$AsJson
)
$ErrorActionPreference = 'Stop'
if ($Owner -notmatch '^[A-Za-z0-9-]+$' -or $Repository -notmatch '^[A-Za-z0-9_.-]+$') { throw 'Invalid owner or repository name.' }
$headers = @{ Accept = 'application/vnd.github+json'; 'User-Agent' = 'PersonaChat-DownloadStats' }
$rows = [Collections.Generic.List[object]]::new()
$page = 1
$allAssetDownloads = 0L
while ($true) {
    $uri = 'https://api.github.com/repos/{0}/{1}/releases?per_page=100&page={2}' -f $Owner,$Repository,$page
    $releases = @(Invoke-RestMethod -Uri $uri -Headers $headers)
    foreach ($release in $releases) {
        if ($release.draft) { continue }
        foreach ($asset in $release.assets) {
            $allAssetDownloads += [long]$asset.download_count
            if ($asset.name -like '*Windows*.zip') {
                $rows.Add([pscustomobject]@{
                    Version = $release.tag_name
                    File = $asset.name
                    Downloads = [long]$asset.download_count
                    Published = $release.published_at
                })
            }
        }
    }
    if ($releases.Count -lt 100) { break }
    $page++
}
$total = 0L
foreach ($row in $rows) { $total += $row.Downloads }
$report = [pscustomobject]@{
    Repository = "$Owner/$Repository"
    CheckedAtUtc = [DateTime]::UtcNow.ToString('o')
    WindowsZipDownloads = $total
    AllReleaseAssetDownloads = $allAssetDownloads
    Assets = @($rows.ToArray())
}
if ($AsJson) { $report | ConvertTo-Json -Depth 5; return }
if ($rows.Count) { $rows | Format-Table Version,File,Downloads,Published -AutoSize }
else { Write-Output 'No published Windows ZIP assets yet.' }
Write-Output ('Windows ZIP downloads: ' + $total)
Write-Output ('All Release asset downloads: ' + $allAssetDownloads)
Write-Output 'Counts are download events, not unique users or installations. Git clone/source archives are not included.'
