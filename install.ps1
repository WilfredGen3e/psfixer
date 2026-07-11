<#
.SYNOPSIS
    Bootstraps or updates PSFixer from GitHub without requiring PSGallery.
.DESCRIPTION
    Downloads the latest commit on the given branch as a zip, replaces any
    existing CurrentUser install, imports the module, and prints the list of
    available commands. Requires no admin rights and no PSGallery/PowerShellGet
    dependency, since a corrupted gallery config is one of the exact problems
    PSFixer is meant to diagnose.
.PARAMETER Repo
    GitHub "owner/name" of the PSFixer repository.
.PARAMETER Branch
    Branch to install from.
.EXAMPLE
    irm https://wilfredgen3e.github.io/psfixer/install.ps1 | iex
#>
[CmdletBinding()]
param(
    [string]$Repo = 'WilfredGen3e/psfixer',
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'

$moduleRoot = if ($PSVersionTable.PSEdition -eq 'Core') {
    Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules'
}
else {
    Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Modules'
}

if (-not (Test-Path -Path $moduleRoot)) {
    New-Item -Path $moduleRoot -ItemType Directory -Force | Out-Null
}

$destination = Join-Path $moduleRoot 'PSFixer'
$zipUrl = "https://github.com/$Repo/archive/refs/heads/$Branch.zip"
$tempDir = Join-Path $env:TEMP "psfixer-install-$(Get-Random)"
$zipPath = Join-Path $tempDir 'psfixer.zip'

New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

try {
    Write-Host "PSFixer downloaden vanaf $Repo ($Branch)..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing

    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
    $repoName = $Repo.Split('/')[-1]
    $extractedRoot = Get-ChildItem -Path $tempDir -Directory | Where-Object { $_.Name -like "$repoName-*" } | Select-Object -First 1
    if (-not $extractedRoot) {
        throw "Kan de uitgepakte repository-map niet vinden onder '$tempDir'."
    }

    $sourceModule = Join-Path $extractedRoot.FullName 'PSFixer'
    if (-not (Test-Path -Path $sourceModule)) {
        throw "Kan de PSFixer-modulemap niet vinden in de download van '$Repo'."
    }

    if (Get-Module -Name PSFixer) {
        Remove-Module -Name PSFixer -Force
    }

    if (Test-Path -Path $destination) {
        Remove-Item -Path $destination -Recurse -Force
    }

    Copy-Item -Path $sourceModule -Destination $destination -Recurse -Force
}
finally {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Import-Module -Name (Join-Path $destination 'PSFixer.psd1') -Force -Global

$manifest = Import-PowerShellDataFile -Path (Join-Path $destination 'PSFixer.psd1')

Write-Host ''
Write-Host "PSFixer $($manifest.ModuleVersion) geinstalleerd in: $destination" -ForegroundColor Green
Write-Host ''
Write-Host 'Beschikbare commando''s:' -ForegroundColor Cyan
Get-Command -Module PSFixer | Sort-Object Name | ForEach-Object {
    $synopsis = (Get-Help -Name $_.Name -ErrorAction SilentlyContinue).Synopsis
    '  {0,-28} {1}' -f $_.Name, $synopsis
}
Write-Host ''
Write-Host 'Begin met: Get-PSFixerInventory | Invoke-PSFixerAnalysis' -ForegroundColor Cyan
