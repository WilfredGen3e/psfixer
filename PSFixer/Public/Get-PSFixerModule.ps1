function Get-PSFixerModule {
    <#
    .SYNOPSIS
        Inventories installed PowerShell modules across all locations (INV-03, INV-04).
    .DESCRIPTION
        Enumerates every module found on $env:PSModulePath (all locations, all scopes)
        and reports its name, version, path, and resolved scope label.
    .PARAMETER Name
        Optional module name filter (wildcards supported).
    .EXAMPLE
        Get-PSFixerModule -Name Az.*
    #>
    [CmdletBinding()]
    [OutputType('PSFixer.ModuleInfo')]
    param(
        [SupportsWildcards()]
        [string]$Name = '*'
    )

    $modules = Get-Module -Name $Name -ListAvailable -ErrorAction SilentlyContinue

    foreach ($module in $modules) {
        [pscustomobject]@{
            PSTypeName = 'PSFixer.ModuleInfo'
            Name       = $module.Name
            Version    = $module.Version
            Path       = $module.ModuleBase
            Scope      = Get-PSFixerModuleScope -Path $module.ModuleBase
            Edition    = $module.CompatiblePSEditions -join ','
            Repository = $module.RepositorySourceLocation
        }
    }
}
