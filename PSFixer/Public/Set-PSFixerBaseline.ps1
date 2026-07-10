function Set-PSFixerBaseline {
    <#
    .SYNOPSIS
        Applies the PSFixer baseline to the local environment (§5.4).
    .DESCRIPTION
        Registers/trusts PSGallery (BAS-02), ensures required package providers
        are present (BAS-03), and applies recommended settings such as TLS and
        PSResourceGet preference (BAS-04). Does not install PowerShell 7 itself
        in v1 — see open question in PRD §10; reports non-compliance instead.
        Idempotent (NFR-03): re-running has no effect once compliant.
    .PARAMETER Path
        Path to a custom baseline JSON file (BAS-06). Defaults to the built-in baseline.
    .EXAMPLE
        Set-PSFixerBaseline -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [string]$Path
    )

    $baseline = Get-PSFixerBaselineDefinition -Path $Path

    if ($PSVersionTable.PSVersion -lt [version]$baseline.MinimumPowerShellVersion) {
        Write-Warning "Running PowerShell $($PSVersionTable.PSVersion), baseline requires >= $($baseline.MinimumPowerShellVersion). Install/upgrade PowerShell 7 manually, then re-run Set-PSFixerBaseline (BAS-01)."
    }

    foreach ($repo in $baseline.Repositories) {
        if ($PSCmdlet.ShouldProcess($repo.Name, 'Register/trust repository')) {
            # PowerShellGet (Get-PSRepository) and PSResourceGet (Get-PSResourceRepository) keep
            # entirely separate trust settings for the same repository - trusting one does not
            # trust the other. Test-PSFixerBaseline/Get-PSFixerRepository prefer PSResourceGet
            # when it's present, so both must be fixed here or compliance never actually clears.
            $existing = Get-PSRepository -Name $repo.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                if ($repo.Name -eq 'PSGallery') {
                    Register-PSRepository -Default -ErrorAction Stop
                }
                else {
                    Write-Warning "Repository '$($repo.Name)' is not registered and is not PSGallery; register it manually or add it to your custom baseline with a Uri."
                    continue
                }
            }
            Set-PSRepository -Name $repo.Name -InstallationPolicy $repo.InstallationPolicy -ErrorAction Stop

            if ($repo.Name -eq 'PSGallery' -and (Get-Command -Name Get-PSResourceRepository -ErrorAction SilentlyContinue)) {
                if (-not (Get-PSResourceRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
                    Register-PSResourceRepository -PSGallery -ErrorAction Stop
                }
                Set-PSResourceRepository -Name PSGallery -Trusted:($repo.InstallationPolicy -eq 'Trusted') -ErrorAction Stop
            }
        }
    }

    foreach ($provider in $baseline.PackageProviders) {
        $minVersion = [version]$provider.MinimumVersion
        $current = Get-PackageProvider -Name $provider.Name -ErrorAction SilentlyContinue

        if ($current -and [version]$current.Version -ge $minVersion) {
            continue
        }

        if ($PSCmdlet.ShouldProcess($provider.Name, 'Install/update package provider')) {
            Install-PackageProvider -Name $provider.Name -MinimumVersion $minVersion -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
        }
    }

    if ($baseline.PreferPSResourceGet) {
        if ($PSCmdlet.ShouldProcess('Microsoft.PowerShell.PSResourceGet', 'Install module')) {
            if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.PSResourceGet -ErrorAction SilentlyContinue)) {
                Install-Module -Name Microsoft.PowerShell.PSResourceGet -Scope CurrentUser -Force -ErrorAction Stop
            }
        }
    }

    if ($baseline.SecurityProtocol) {
        if ($PSCmdlet.ShouldProcess('SecurityProtocol', 'Apply TLS settings for this session')) {
            $flags = $baseline.SecurityProtocol | ForEach-Object { [Net.SecurityProtocolType]$_ }
            $combined = $flags[0]
            foreach ($flag in $flags[1..($flags.Count - 1)]) { $combined = $combined -bor $flag }
            [Net.ServicePointManager]::SecurityProtocol = $combined
        }
    }

    Test-PSFixerBaseline -Path $Path
}
