function Test-PSFixerBaseline {
    <#
    .SYNOPSIS
        Reports compliance against the PSFixer baseline without changing anything (BAS-05).
    .PARAMETER Path
        Path to a custom baseline JSON file (BAS-06). Defaults to the built-in baseline.
    .EXAMPLE
        Test-PSFixerBaseline
    #>
    [CmdletBinding()]
    [OutputType('PSFixer.BaselineCheck')]
    param(
        [string]$Path
    )

    $baseline = Get-PSFixerBaselineDefinition -Path $Path
    $results = [System.Collections.Generic.List[pscustomobject]]::new()

    function New-Check {
        param($Name, $Compliant, $Detail)
        [pscustomobject]@{
            PSTypeName = 'PSFixer.BaselineCheck'
            Check      = $Name
            Compliant  = $Compliant
            Detail     = $Detail
        }
    }

    # BAS-01: PowerShell version
    $minVersion = [version]$baseline.MinimumPowerShellVersion
    $currentVersion = $PSVersionTable.PSVersion
    $results.Add((New-Check -Name 'PowerShellVersion' `
        -Compliant ($currentVersion -ge $minVersion) `
        -Detail "Current: $currentVersion, required: >= $minVersion"))

    # BAS-02: repositories
    foreach ($repo in $baseline.Repositories) {
        $actual = Get-PSFixerRepository | Where-Object { $_.Name -eq $repo.Name }
        $compliant = $actual -and ($actual.Trusted -eq ($repo.InstallationPolicy -eq 'Trusted'))
        $results.Add((New-Check -Name "Repository:$($repo.Name)" `
            -Compliant $compliant `
            -Detail $(if ($actual) { "Trusted=$($actual.Trusted), required Trusted=$($repo.InstallationPolicy -eq 'Trusted')" } else { 'Not registered' })))
    }

    # BAS-03: package providers
    foreach ($provider in $baseline.PackageProviders) {
        $actual = Get-PackageProvider -Name $provider.Name -ErrorAction SilentlyContinue
        $minVer = [version]$provider.MinimumVersion
        $compliant = $actual -and ([version]$actual.Version -ge $minVer)
        $results.Add((New-Check -Name "PackageProvider:$($provider.Name)" `
            -Compliant $compliant `
            -Detail $(if ($actual) { "Version=$($actual.Version), required >= $minVer" } else { 'Not installed' })))
    }

    # BAS-04: PSResourceGet preference, TLS
    if ($baseline.PreferPSResourceGet) {
        $hasPSResourceGet = [bool](Get-Module -ListAvailable -Name Microsoft.PowerShell.PSResourceGet -ErrorAction SilentlyContinue)
        $results.Add((New-Check -Name 'PSResourceGet' -Compliant $hasPSResourceGet `
            -Detail $(if ($hasPSResourceGet) { 'Installed' } else { 'Not installed' })))
    }

    if ($baseline.SecurityProtocol) {
        $current = [Net.ServicePointManager]::SecurityProtocol.ToString()
        $required = $baseline.SecurityProtocol -join ', '
        $compliant = $true
        foreach ($proto in $baseline.SecurityProtocol) {
            if ($current -notmatch $proto) { $compliant = $false }
        }
        $results.Add((New-Check -Name 'SecurityProtocol' -Compliant $compliant `
            -Detail "Current: $current, required to include: $required"))
    }

    return $results
}
