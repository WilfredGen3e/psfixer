function Restore-PSFixerSnapshot {
    <#
    .SYNOPSIS
        Reinstalls module versions that a Reset-PSFixerEnvironment run removed,
        using its pre-reset inventory snapshot.
    .DESCRIPTION
        Compares a snapshot JSON file (written automatically by Reset-PSFixerEnvironment
        before it removes anything) against the modules currently installed, and
        reinstalls any module+version pair from the snapshot that is missing now.
        Requires PSGallery connectivity for the versions to still be available there.
    .PARAMETER SnapshotPath
        Path to a specific snapshot JSON file. If omitted, the most recent snapshot
        under $env:TEMP\PSFixer is used.
    .EXAMPLE
        Restore-PSFixerSnapshot -WhatIf
    .EXAMPLE
        Restore-PSFixerSnapshot -SnapshotPath "$env:TEMP\PSFixer\inventory-20260710-113622.json"
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [string]$SnapshotPath
    )

    if (-not $SnapshotPath) {
        $snapshotDir = Join-Path -Path $env:TEMP -ChildPath 'PSFixer'
        $latest = Get-PSFixerLatestSnapshot -SnapshotPath $snapshotDir
        if (-not $latest) {
            throw (Get-PSFixerString -Key 'Snapshot.NotFound' -FormatArgs @($snapshotDir))
        }
        $SnapshotPath = $latest.FullName
    }

    if (-not (Test-Path -Path $SnapshotPath)) {
        throw (Get-PSFixerString -Key 'Snapshot.PathNotFound' -FormatArgs @($SnapshotPath))
    }

    function ConvertTo-PSFixerVersionObject {
        # ConvertFrom-Json turns [version] into a plain PSCustomObject with
        # Major/Minor/Build/Revision fields, not a real [version] - rebuild it
        # so version comparisons against Get-Module output work correctly.
        param($DeserializedVersion)

        if ($DeserializedVersion.Revision -ge 0) {
            [version]::new($DeserializedVersion.Major, $DeserializedVersion.Minor, $DeserializedVersion.Build, $DeserializedVersion.Revision)
        }
        else {
            [version]::new($DeserializedVersion.Major, $DeserializedVersion.Minor, $DeserializedVersion.Build)
        }
    }

    $snapshot = Get-Content -Path $SnapshotPath -Raw | ConvertFrom-Json
    $currentModules = @(Get-PSFixerModule)

    $toRestore = foreach ($entry in $snapshot.Modules) {
        $entryVersion = ConvertTo-PSFixerVersionObject -DeserializedVersion $entry.Version
        $stillPresent = $currentModules | Where-Object { $_.Name -eq $entry.Name -and $_.Version -eq $entryVersion }
        if (-not $stillPresent) {
            [pscustomobject]@{
                Name    = $entry.Name
                Version = $entryVersion
                Scope   = $entry.Scope
            }
        }
    }

    if (-not $toRestore) {
        Write-Host (Get-PSFixerString -Key 'Snapshot.NothingToRestore') -ForegroundColor Green
        return
    }

    foreach ($entry in $toRestore) {
        $scope = if ($entry.Scope -like 'AllUsers*') { 'AllUsers' } else { 'CurrentUser' }
        $target = "$($entry.Name) $($entry.Version) (Scope=$scope)"
        if ($PSCmdlet.ShouldProcess($target, (Get-PSFixerString -Key 'Snapshot.ShouldProcessAction'))) {
            try {
                Install-Module -Name $entry.Name -RequiredVersion $entry.Version -Scope $scope -Force -ErrorAction Stop
                Write-Host (Get-PSFixerString -Key 'Snapshot.Restored' -FormatArgs @($target)) -ForegroundColor Green
            }
            catch {
                Write-Warning (Get-PSFixerString -Key 'Snapshot.RestoreFailed' -FormatArgs @($target, $_))
            }
        }
    }
}
