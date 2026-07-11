function Reset-PSFixerEnvironment {
    <#
    .SYNOPSIS
        Cleans up the local PowerShell environment back to a healthy state.
    .DESCRIPTION
        Removes duplicate/old module versions, reconfigures repositories, and
        updates package providers, depending on -Scope. Every destructive action
        goes through ShouldProcess; a snapshot of the current inventory
        is written before any change is made; actions are logged.
    .PARAMETER Scope
        Which part(s) of the environment to reset. Defaults to All.
    .PARAMETER KeepVersion
        For modules with multiple installed versions, the version to keep.
        Defaults to the newest installed version per module.
    .PARAMETER SnapshotPath
        Directory to write the pre-reset inventory snapshot to.
        Defaults to a timestamped file under $env:TEMP\PSFixer.
    .PARAMETER LogPath
        File to append action log entries to.
    .PARAMETER TargetEdition
        Which PowerShell edition(s) the Modules scope should clean up: 'PS7',
        'WindowsPowerShell', or 'Both'. If omitted, prompts interactively when
        possible; falls back to whichever edition is currently running for
        non-interactive/scripted use. Cleaning up the "other" edition runs
        Uninstall-Module/-PSResource in that edition's own host process (never
        edits $env:PSModulePath) and never requires admin rights for
        CurrentUser-scoped modules.
    .EXAMPLE
        Reset-PSFixerEnvironment -Scope Modules -WhatIf
    .EXAMPLE
        Reset-PSFixerEnvironment -Confirm:$false
    .EXAMPLE
        Reset-PSFixerEnvironment -Scope Modules -TargetEdition Both -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [ValidateSet('All', 'Modules', 'Repositories', 'Providers')]
        [string[]]$Scope = 'All',

        [hashtable]$KeepVersion = @{},

        [string]$SnapshotPath = (Join-Path -Path $env:TEMP -ChildPath 'PSFixer'),

        [string]$LogPath,

        [ValidateSet('PS7', 'WindowsPowerShell', 'Both')]
        [string]$TargetEdition
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
        $editions = Resolve-PSFixerTargetEdition -TargetEdition $TargetEdition
        $currentEdition = Get-PSFixerCurrentEdition

        foreach ($edition in $editions) {
            $modulesForEdition = if ($edition -eq $currentEdition) {
                $inventory.Modules
            }
            else {
                Get-PSFixerEditionModuleDump -Edition $edition
            }

            $moduleGroups = $modulesForEdition | Group-Object -Property Name
            foreach ($group in $moduleGroups) {
                # Skip entries the package manager doesn't track (in-box Windows modules like
                # the bundled Pester or PackageManagement) - removal is guaranteed to fail for
                # those, so don't attempt it and don't let one pick $keep.
                $manageable = @($group.Group | Where-Object { $_.Managed -ne $false })
                if ($manageable.Count -lt 2) {
                    continue
                }

                $keep = $KeepVersion[$group.Name]
                if (-not $keep) {
                    $keep = ($manageable.Version | Sort-Object -Descending | Select-Object -First 1)
                }

                $toRemove = $manageable | Where-Object { $_.Version -ne $keep }
                foreach ($entry in $toRemove) {
                    $target = "$($entry.Name) $($entry.Version) [$($entry.Path)] [$edition]"
                    if ($PSCmdlet.ShouldProcess($target, 'Uninstall duplicate/old module version')) {
                        try {
                            if ($edition -eq $currentEdition) {
                                if (Get-Command -Name Uninstall-PSResource -ErrorAction SilentlyContinue) {
                                    Uninstall-PSResource -Name $entry.Name -Version $entry.Version -SkipDependencyCheck -ErrorAction Stop -WarningAction Stop
                                }
                                else {
                                    Uninstall-Module -Name $entry.Name -RequiredVersion $entry.Version -Force -ErrorAction Stop -WarningAction Stop
                                }
                            }
                            else {
                                Uninstall-PSFixerModuleInEdition -Edition $edition -Name $entry.Name -Version $entry.Version
                            }

                            # Uninstall-Module/-PSResource can "succeed" (no exception) while writing a
                            # non-terminating warning instead - e.g. Windows in-box modules (like the
                            # bundled Pester 3.4.0) were never registered as an installed package, so
                            # there's nothing to uninstall from PowerShellGet's point of view even though
                            # the files are still on disk. Verify on disk before claiming success - this
                            # also works for the other-edition path, since a filesystem path doesn't
                            # care which PowerShell process checks it.
                            if (Test-Path -Path $entry.Path) {
                                throw "Bestand staat nog op '$($entry.Path)' na uninstall-poging (waarschijnlijk een ingebouwde Windows-module die niet via de package manager te verwijderen is)."
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
    }

    if ('Repositories' -in $Scope) {
        if ($PSCmdlet.ShouldProcess('PSGallery', 'Register/trust repository')) {
            # PowerShellGet (Get-PSRepository) and PSResourceGet (Get-PSResourceRepository) keep
            # entirely separate trust settings for PSGallery, even though they point at the same
            # URL - trusting one does not trust the other. Get-PSFixerRepository/ANA-06 prefer
            # PSResourceGet when it's present, so both must be fixed here or the finding never
            # actually clears.
            if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
                Register-PSRepository -Default -ErrorAction Stop
                Write-PSFixerLog -Path $LogPath -Message 'Registered PSGallery (PowerShellGet)' -Level Info
            }
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
            Write-PSFixerLog -Path $LogPath -Message 'Set PSGallery to Trusted (PowerShellGet)' -Level Info

            if (Get-Command -Name Get-PSResourceRepository -ErrorAction SilentlyContinue) {
                if (-not (Get-PSResourceRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
                    Register-PSResourceRepository -PSGallery -ErrorAction Stop
                    Write-PSFixerLog -Path $LogPath -Message 'Registered PSGallery (PSResourceGet)' -Level Info
                }
                Set-PSResourceRepository -Name PSGallery -Trusted -ErrorAction Stop
                Write-PSFixerLog -Path $LogPath -Message 'Set PSGallery to Trusted (PSResourceGet)' -Level Info
            }
        }
    }

    if ('Providers' -in $Scope) {
        $minNuGet = [version]'2.8.5.201'
        $currentNuGet = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue

        if ($currentNuGet -and [version]$currentNuGet.Version -ge $minNuGet) {
            Write-PSFixerLog -Path $LogPath -Message "NuGet provider $($currentNuGet.Version) already satisfies the minimum ($minNuGet); nothing to do" -Level Info
        }
        elseif ($PSCmdlet.ShouldProcess('NuGet', 'Install/update package provider')) {
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion $minNuGet -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
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
