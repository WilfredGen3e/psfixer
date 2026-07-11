function Get-PSFixerLegacyModuleMap {
    <#
    .SYNOPSIS
        Loads the legacy/unsupported module definitions used by Invoke-PSFixerAnalysis.
    .DESCRIPTION
        Kept as external data (Data\LegacyModules.json) rather than hardcoded,
        since the list of legacy modules changes over time.
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
