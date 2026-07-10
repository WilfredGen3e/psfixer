function Get-PSFixerPopularModuleCatalog {
    <#
    .SYNOPSIS
        Loads the curated "popular modules" catalog used by Install-PSFixerModule's
        interactive picker, grouped by category.
    .PARAMETER Path
        Path to a custom catalog JSON file (same shape: category -> [{Name, Description}]).
        Entries override built-in entries with the same category+name.
    #>
    [CmdletBinding()]
    [OutputType([ordered])]
    param(
        [string]$Path
    )

    $builtInPath = Join-Path -Path $PSFixerModuleRoot -ChildPath 'Data\PopularModules.json'
    $catalog = [ordered]@{}

    $builtIn = Get-Content -Path $builtInPath -Raw | ConvertFrom-Json
    foreach ($category in $builtIn.PSObject.Properties) {
        $catalog[$category.Name] = @($category.Value)
    }

    if ($Path) {
        if (-not (Test-Path -Path $Path)) {
            throw "PSFixer popular-module catalog file not found at '$Path'."
        }
        $custom = Get-Content -Path $Path -Raw | ConvertFrom-Json
        foreach ($category in $custom.PSObject.Properties) {
            $catalog[$category.Name] = @($category.Value)
        }
    }

    return $catalog
}
