function Get-PSFixerBaselineDefinition {
    <#
    .SYNOPSIS
        Loads a baseline definition (BAS-06: configurable per organization).
    .PARAMETER Path
        Path to a custom baseline JSON file. Defaults to the built-in baseline.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$Path
    )

    if (-not $Path) {
        $Path = Join-Path -Path $PSFixerModuleRoot -ChildPath 'Data\Baseline.json'
    }

    if (-not (Test-Path -Path $Path)) {
        throw "PSFixer baseline definition not found at '$Path'."
    }

    Get-Content -Path $Path -Raw | ConvertFrom-Json
}
