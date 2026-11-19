$ErrorActionPreference = 'Stop'
$addonRoot = Split-Path $PSScriptRoot -Parent
$distRoot = Join-Path $addonRoot 'dist'
New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
$archivePath = Join-Path $distRoot 'GatherCompassForever-0.8.3.zip'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archiveStream = [System.IO.File]::Open($archivePath, [System.IO.FileMode]::Create)
$archive = [System.IO.Compression.ZipArchive]::new($archiveStream, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $runtimeFiles = Get-Content -LiteralPath (Join-Path $addonRoot 'GatherCompassForever.toc') | Where-Object { $_.Trim() -and -not $_.StartsWith('#') }
    $imageFiles = Get-ChildItem -LiteralPath (Join-Path $addonRoot 'docs/images') -Filter '*.png' -File | Sort-Object Name | ForEach-Object { 'docs/images/' + $_.Name }
    $packageFiles = @('GatherCompassForever.toc','README.md','NOTICE.md','LICENSE','CHANGELOG.md','CONTRIBUTING.md','Libs/LICENSE.txt','Libs/HereBeDragons-LICENSE.txt','Media/Icon.tga','Media/Header.tga','Media/LogoSheet.tga','Media/EmptyEmblem.tga','Media/README.txt','Media/NodeRing.tga','Media/NodeSquare.tga','Media/GuideArrow.tga') + @($runtimeFiles) + @($imageFiles)
    foreach ($relativeFile in $packageFiles) {
        $sourcePath = Join-Path $addonRoot $relativeFile.Trim()
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Missing package file: $relativeFile" }
        $entryName = 'GatherCompassForever/' + $relativeFile.Trim().Replace('\','/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $sourcePath, $entryName, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally { $archive.Dispose(); $archiveStream.Dispose() }
Write-Output "Packaged $archivePath"
