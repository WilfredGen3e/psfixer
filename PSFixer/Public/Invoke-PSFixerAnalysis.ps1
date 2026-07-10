function Invoke-PSFixerAnalysis {
    <#
    .SYNOPSIS
        Analyzes a PSFixer inventory and reports problems with severity and
        recommended actions (§5.2).
    .DESCRIPTION
        Detects duplicate modules (ANA-01), multiple/conflicting versions
        (ANA-02, ANA-04), legacy/unsupported modules (ANA-05), repository
        misconfiguration (ANA-06), and outdated package providers (ANA-07).
        Outdated-version checks against the gallery (ANA-03) only run with
        -Online, since analysis must work offline (NFR-05).
    .PARAMETER Inventory
        A PSFixer.Inventory object, e.g. from Get-PSFixerInventory. If omitted,
        a fresh inventory is collected.
    .PARAMETER Online
        Also check the gallery for newer versions of installed modules (ANA-03).
        Requires internet connectivity.
    .PARAMETER NoReport
        Skip writing the HTML report to ~\psfixerreports (INV-08). Findings are
        still returned to the pipeline as usual.
    .PARAMETER NoOpenReport
        Write the HTML report as usual but don't open it in the default browser.
        Has no effect when -NoReport is also specified.
    .PARAMETER IncludeUnmanaged
        Also flag duplicate-location/multiple-version findings (ANA-01, ANA-02)
        for modules that ship in-box with Windows and were never installed via
        the package manager (e.g. the Pester bundled with Windows PowerShell,
        or PackageManagement itself). These can't be removed by
        Reset-PSFixerEnvironment anyway, so they're excluded by default.
    .EXAMPLE
        Get-PSFixerInventory | Invoke-PSFixerAnalysis
    #>
    [CmdletBinding()]
    [OutputType('PSFixer.Finding')]
    param(
        [Parameter(ValueFromPipeline)]
        [pscustomobject]$Inventory,

        [switch]$Online,

        [switch]$NoReport,

        [switch]$NoOpenReport,

        [switch]$IncludeUnmanaged
    )

    process {
        if (-not $Inventory) {
            $Inventory = Get-PSFixerInventory
        }

        $findings = [System.Collections.Generic.List[pscustomobject]]::new()

        function New-Finding {
            param($Category, $Severity, $Message, $Recommendation, $Item)
            [pscustomobject]@{
                PSTypeName     = 'PSFixer.Finding'
                Category       = $Category
                Severity       = $Severity
                Message        = $Message
                Recommendation = $Recommendation
                Item           = $Item
            }
        }

        $moduleGroups = $Inventory.Modules | Group-Object -Property Name

        # Entries with no Managed property (e.g. a hand-built inventory) are treated as
        # manageable, so this only ever narrows results for real Get-PSFixerInventory input.
        function Get-PSFixerManageableEntries {
            param($Entries)
            if ($IncludeUnmanaged) { return $Entries }
            return @($Entries | Where-Object { $_.Managed -ne $false })
        }

        # ANA-01: duplicate modules (same module on multiple locations)
        foreach ($group in $moduleGroups) {
            $entries = Get-PSFixerManageableEntries -Entries $group.Group
            $distinctPaths = $entries | Select-Object -ExpandProperty Path -Unique
            if ($distinctPaths.Count -gt 1) {
                $findings.Add((New-Finding -Category 'DuplicateModule' -Severity 'Warning' `
                    -Message "Module '$($group.Name)' is installed in $($distinctPaths.Count) locations." `
                    -Recommendation "Run Reset-PSFixerEnvironment -Scope Modules to consolidate '$($group.Name)' to a single location." `
                    -Item $group.Name))
            }
        }

        # ANA-02: multiple versions of the same module, mark the one that loads
        foreach ($group in $moduleGroups) {
            $entries = Get-PSFixerManageableEntries -Entries $group.Group
            $versions = $entries | Select-Object -ExpandProperty Version -Unique
            if ($versions.Count -gt 1) {
                $loaded = Get-Module -Name $group.Name -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty Version -First 1
                $highest = $versions | Sort-Object -Descending | Select-Object -First 1
                $loadedText = if ($loaded) { $loaded.ToString() } else { 'not currently imported' }
                $findings.Add((New-Finding -Category 'MultipleVersions' -Severity 'Warning' `
                    -Message "Module '$($group.Name)' has $($versions.Count) versions installed ($($versions -join ', ')). Loaded: $loadedText. Newest installed: $highest." `
                    -Recommendation "Run Reset-PSFixerEnvironment -Scope Modules to remove old versions of '$($group.Name)', keeping $highest." `
                    -Item $group.Name))
            }
        }

        # ANA-05: legacy/unsupported modules
        $legacyMap = Get-PSFixerLegacyModuleMap
        foreach ($group in $moduleGroups) {
            if ($legacyMap.ContainsKey($group.Name)) {
                $info = $legacyMap[$group.Name]
                $findings.Add((New-Finding -Category 'LegacyModule' -Severity $info.Severity `
                    -Message "Module '$($group.Name)' is legacy/unsupported. $($info.Reason)" `
                    -Recommendation "Migrate to '$($info.Replacement)' and remove '$($group.Name)' via Reset-PSFixerEnvironment." `
                    -Item $group.Name))
            }
        }

        # ANA-04: command conflicts between simultaneously-loadable legacy/modern modules
        $legacyPresent = $moduleGroups.Name | Where-Object { $_ -and $legacyMap.ContainsKey($_) }
        if ($legacyPresent -and ($moduleGroups.Name -contains 'Microsoft.Graph')) {
            $findings.Add((New-Finding -Category 'CommandConflict' -Severity 'Critical' `
                -Message "Legacy module(s) $($legacyPresent -join ', ') are installed alongside Microsoft.Graph, which can cause command name conflicts and inconsistent authentication behavior." `
                -Recommendation 'Remove the legacy module(s) and standardize on Microsoft.Graph.' `
                -Item ($legacyPresent -join ',')))
        }

        # ANA-06: repository problems
        $psGallery = $Inventory.Repositories | Where-Object { $_.Name -eq 'PSGallery' }
        if (-not $psGallery) {
            $findings.Add((New-Finding -Category 'Repository' -Severity 'Critical' `
                -Message 'PSGallery is not registered.' `
                -Recommendation 'Run Set-PSFixerBaseline or Reset-PSFixerEnvironment -Scope Repositories to register PSGallery as Trusted.' `
                -Item 'PSGallery'))
        }
        elseif (-not $psGallery.Trusted) {
            $findings.Add((New-Finding -Category 'Repository' -Severity 'Warning' `
                -Message 'PSGallery is registered but not Trusted, which will prompt on every install.' `
                -Recommendation 'Run Set-PSFixerBaseline or Reset-PSFixerEnvironment -Scope Repositories to mark PSGallery as Trusted.' `
                -Item 'PSGallery'))
        }

        # ANA-07: outdated/missing NuGet provider
        $nuget = $Inventory.PackageProviders | Where-Object { $_.Name -eq 'NuGet' }
        $minNuGet = [version]'2.8.5.201'
        if (-not $nuget) {
            $findings.Add((New-Finding -Category 'PackageProvider' -Severity 'Critical' `
                -Message 'NuGet package provider is not installed.' `
                -Recommendation "Run Reset-PSFixerEnvironment -Scope Providers to install NuGet $minNuGet or later." `
                -Item 'NuGet'))
        }
        elseif ([version]$nuget.Version -lt $minNuGet) {
            $findings.Add((New-Finding -Category 'PackageProvider' -Severity 'Warning' `
                -Message "NuGet package provider version $($nuget.Version) is older than the recommended minimum $minNuGet." `
                -Recommendation 'Run Reset-PSFixerEnvironment -Scope Providers to update NuGet.' `
                -Item 'NuGet'))
        }

        # ANA-03: outdated versions vs. gallery (requires connectivity)
        if ($Online) {
            foreach ($group in $moduleGroups) {
                try {
                    $latest = Find-Module -Name $group.Name -ErrorAction Stop | Select-Object -First 1
                    $highestInstalled = $group.Group | Select-Object -ExpandProperty Version -Unique | Sort-Object -Descending | Select-Object -First 1
                    if ($latest.Version -gt $highestInstalled) {
                        $findings.Add((New-Finding -Category 'OutdatedModule' -Severity 'Info' `
                            -Message "Module '$($group.Name)' $highestInstalled is outdated; $($latest.Version) is available." `
                            -Recommendation "Run Update-Module -Name '$($group.Name)' or Update-PSFixerProfile." `
                            -Item $group.Name))
                    }
                }
                catch {
                    Write-Verbose "Could not check gallery version for '$($group.Name)': $_"
                }
            }
        }

        if (-not $NoReport) {
            $reportDir = Join-Path -Path $HOME -ChildPath 'psfixerreports'
            if (-not (Test-Path -Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }

            $reportPath = Join-Path -Path $reportDir -ChildPath "psfixer-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
            New-PSFixerHtmlReport -Inventory $Inventory -Findings $findings | Set-Content -Path $reportPath -Encoding UTF8

            $reportUri = "file:///$($reportPath -replace '\\', '/')"
            Write-Host "PSFixer-rapport: $reportUri" -ForegroundColor Cyan

            if (-not $NoOpenReport) {
                try {
                    Start-Process -FilePath $reportPath -ErrorAction Stop
                }
                catch {
                    Write-Verbose "Kon het rapport niet automatisch openen: $_"
                }
            }
        }

        return $findings
    }
}
