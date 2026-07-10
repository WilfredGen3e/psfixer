function Get-PSFixerManagedModuleKeys {
    <#
    .SYNOPSIS
        Returns the set of "Name|Version" pairs actually tracked by the package
        manager (PSResourceGet or PowerShellGet).
    .DESCRIPTION
        Modules that ship in-box with Windows (e.g. the Pester 3.4.0 bundled
        with Windows PowerShell, or PackageManagement itself) show up in
        Get-Module -ListAvailable but were never "installed" via Install-Module/
        Install-PSResource, so the package manager cannot remove them and they
        are not something a user can act on. This set is used to filter those
        out of duplicate/multiple-version findings (ANA-01/ANA-02) by default.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.HashSet[string]])]
    param()

    $keys = [System.Collections.Generic.HashSet[string]]::new()

    if (Get-Command -Name Get-InstalledPSResource -ErrorAction SilentlyContinue) {
        foreach ($resource in Get-InstalledPSResource -ErrorAction SilentlyContinue) {
            [void]$keys.Add("$($resource.Name)|$($resource.Version)")
        }
        return $keys
    }

    if (Get-Command -Name Get-InstalledModule -ErrorAction SilentlyContinue) {
        foreach ($module in Get-InstalledModule -ErrorAction SilentlyContinue) {
            [void]$keys.Add("$($module.Name)|$($module.Version)")
        }
    }

    return $keys
}
