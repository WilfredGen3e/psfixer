function Reset-PSFixerEnvironment {
    <#
    .SYNOPSIS
        Cleans up the local PowerShell environment back to a healthy state (§5.3).
    .DESCRIPTION
        Removes duplicate/old module versions, reconfigures repositories, and
        updates package providers, depending on -Scope. Every destructive action
        goes through ShouldProcess (HER-05); a snapshot of the current inventory
        is written before any change is made (HER-06); actions are logged (HER-08).
    .PARAMETER Scope
        Which part(s) of the environment to reset. Defaults to All.
    .PARAMETER KeepVersion
        For modules with multiple installed versions, the version to keep.
        Defaults to the newest installed version per module.
    .PARAMETER SnapshotPath
        Directory to write the pre-reset inventory snapshot to (HER-06).
        Defaults to a timestamped file under $env:TEMP\PSFixer.
    .PARAMETER LogPath
        File to append action log entries to (HER-08).
    .EXAMPLE
        Reset-PSFixerEnvironment -Scope Modules -WhatIf
    .EXAMPLE
        Reset-PSFixerEnvironment -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [ValidateSet('All', 'Modules', 'Repositories', 'Providers')]
        [string[]]$Scope = 'All',

        [hashtable]$KeepVersion = @{},

        [string]$SnapshotPath = (Join-Path -Path $env:TEMP -ChildPath 'PSFixer'),

        [string]$LogPath
    )

    if ($Scope -contains 'All') {
        $Scope = @('Modules', 'Repositories', 'Providers')
    }

    if (-not $LogPath) {
        $LogPath = Join-Path -Path $SnapshotPath -ChildPath 'reset.log'
    }

    if (-not (Test-Path -Path $SnapshotPath)) {
        New-Item -Path $SnapshotPath -ItemType Directory -Force | Out-Null
    }

    # HER-06: snapshot current state before making any change
    $inventory = Get-PSFixerInventory
    $snapshotFile = Join-Path -Path $SnapshotPath -ChildPath "inventory-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $inventory | ConvertTo-Json -Depth 6 | Set-Content -Path $snapshotFile -Encoding UTF8
    Write-PSFixerLog -Path $LogPath -Message "Snapshot written to $snapshotFile" -Level Info

    if ('Modules' -in $Scope) {
        $moduleGroups = $inventory.Modules | Group-Object -Property Name
        foreach ($group in $moduleGroups) {
            $keep = $KeepVersion[$group.Name]
            if (-not $keep) {
                $keep = ($group.Group.Version | Sort-Object -Descending | Select-Object -First 1)
            }

            $toRemove = $group.Group | Where-Object { $_.Version -ne $keep }
            foreach ($entry in $toRemove) {
                $target = "$($entry.Name) $($entry.Version) [$($entry.Path)]"
                if ($PSCmdlet.ShouldProcess($target, 'Uninstall duplicate/old module version')) {
                    try {
                        if (Get-Command -Name Uninstall-PSResource -ErrorAction SilentlyContinue) {
                            Uninstall-PSResource -Name $entry.Name -Version $entry.Version -SkipDependencyCheck -ErrorAction Stop
                        }
                        else {
                            Uninstall-Module -Name $entry.Name -RequiredVersion $entry.Version -Force -ErrorAction Stop
                        }
                        Write-PSFixerLog -Path $LogPath -Message "Removed $target" -Level Info
                    }
                    catch {
                        Write-PSFixerLog -Path $LogPath -Message "Failed to remove $target : $_" -Level Critical
                        Write-Warning "Failed to remove $target : $_"
                    }
                }
            }
        }
    }

    if ('Repositories' -in $Scope) {
        if ($PSCmdlet.ShouldProcess('PSGallery', 'Register/trust repository')) {
            if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
                Register-PSRepository -Default -ErrorAction Stop
                Write-PSFixerLog -Path $LogPath -Message 'Registered PSGallery' -Level Info
            }
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
            Write-PSFixerLog -Path $LogPath -Message 'Set PSGallery to Trusted' -Level Info
        }
    }

    if ('Providers' -in $Scope) {
        if ($PSCmdlet.ShouldProcess('NuGet', 'Install/update package provider')) {
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
                Write-PSFixerLog -Path $LogPath -Message 'Installed/updated NuGet package provider' -Level Info
            }
            catch {
                Write-PSFixerLog -Path $LogPath -Message "Failed to update NuGet provider: $_" -Level Critical
                Write-Warning "Failed to update NuGet provider: $_"
            }
        }
    }

    Write-PSFixerLog -Path $LogPath -Message 'Reset-PSFixerEnvironment completed' -Level Info
}
