# Builds the Microsoft Store package (.msix) from the game's Windows .exe.
# Runs on Windows with the Windows SDK (it uses makeappx.exe), for example on
# GitHub Actions:
#   pwsh store/make_msix.ps1 -Exe ZupermarketZimulator.exe -Version 0.9.3 -Out ZupermarketZimulator-store.msix
#
# The package's identity comes from store/identity.ini. The Store doesn't
# allow 0 as a package's first number, so game version X.Y.Z becomes package
# version (X+1).Y.Z.0 (0.9.3 -> 1.9.3.0); the game itself still says 0.9.3.
# Upload the .msix unsigned: the Store signs it.
param(
    [Parameter(Mandatory = $true)] [string] $Exe,
    [Parameter(Mandatory = $true)] [string] $Version,
    [Parameter(Mandatory = $true)] [string] $Out,
    [string] $IdentityFile = (Join-Path $PSScriptRoot "identity.ini")
)
$ErrorActionPreference = "Stop"

$id = @{}
foreach ($line in Get-Content $IdentityFile) {
    if ($line -match '^\s*([A-Za-z]+)\s*=\s*(.*?)\s*$') { $id[$Matches[1]] = $Matches[2] }
}
foreach ($key in "Name", "Publisher", "PublisherDisplayName") {
    if (-not $id[$key]) { throw "$IdentityFile has no $key yet (see Partner Center > Product identity)" }
}

$numbers = @($Version.Trim().TrimStart("v").Split(".") | ForEach-Object { [int]($_ -replace '[^0-9].*$', '') })
while ($numbers.Count -lt 3) { $numbers += 0 }
$packageVersion = "{0}.{1}.{2}.0" -f ($numbers[0] + 1), $numbers[1], $numbers[2]

$stage = Join-Path ([IO.Path]::GetTempPath()) ("zz_msix_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $stage | Out-Null
try {
    Copy-Item $Exe (Join-Path $stage "ZupermarketZimulator.exe")
    Copy-Item (Join-Path $PSScriptRoot "Assets") (Join-Path $stage "Assets") -Recurse
    $esc = { param($s) [Security.SecurityElement]::Escape($s) }
    $xml = Get-Content (Join-Path $PSScriptRoot "AppxManifest.xml.in") -Raw
    $xml = $xml.Replace("{NAME}", (& $esc $id.Name)).Replace("{PUBLISHER}", (& $esc $id.Publisher))
    $xml = $xml.Replace("{PUBLISHER_DISPLAY_NAME}", (& $esc $id.PublisherDisplayName)).Replace("{VERSION}", $packageVersion)
    [IO.File]::WriteAllText((Join-Path $stage "AppxManifest.xml"), $xml, (New-Object Text.UTF8Encoding $false))

    $makeappx = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.*\x64\makeappx.exe" |
        Sort-Object { [version]$_.Directory.Parent.Name } -Descending | Select-Object -First 1
    if (-not $makeappx) { throw "makeappx.exe wasn't found: install the Windows SDK" }
    & $makeappx.FullName pack /o /d $stage /p $Out
    if ($LASTEXITCODE -ne 0) { throw "makeappx couldn't build the package" }
    Write-Host "Made $Out (package version $packageVersion)"
}
finally {
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
}
