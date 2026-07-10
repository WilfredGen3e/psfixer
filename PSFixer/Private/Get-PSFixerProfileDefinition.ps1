function Get-PSFixerProfileDefinition {
    <#
    .SYNOPSIS
        Loads built-in and/or custom PSFixer module profiles (PRO-05).
    .PARAMETER Path
        Path to a custom profiles JSON file. Defaults to the built-in profiles.
        Entries in a custom file override built-in entries with the same name.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string]$Path
    )

    $builtInPath = Join-Path -Path $PSFixerModuleRoot -ChildPath 'Data\Profiles.json'
    $profiles = @{}

    foreach ($property in (Get-Content -Path $builtInPath -Raw | ConvertFrom-Json).PSObject.Properties) {
        $profiles[$property.Name] = $property.Value
    }

    if ($Path) {
        if (-not (Test-Path -Path $Path)) {
            throw "PSFixer profile definition file not found at '$Path'."
        }
        foreach ($property in (Get-Content -Path $Path -Raw | ConvertFrom-Json).PSObject.Properties) {
            $profiles[$property.Name] = $property.Value
        }
    }

    return $profiles
}
