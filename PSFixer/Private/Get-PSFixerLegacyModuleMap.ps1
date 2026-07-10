function Get-PSFixerLegacyModuleMap {
    <#
    .SYNOPSIS
        Loads the legacy/unsupported module definitions used by ANA-05.
    .DESCRIPTION
        Kept as external data (Data\LegacyModules.json) rather than hardcoded,
        per PRD risk mitigation: "Legacy-detectielijst veroudert".
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $path = Join-Path -Path $PSFixerModuleRoot -ChildPath 'Data\LegacyModules.json'
    $json = Get-Content -Path $path -Raw | ConvertFrom-Json

    $map = @{}
    foreach ($property in $json.PSObject.Properties) {
        $map[$property.Name] = $property.Value
    }
    return $map
}
