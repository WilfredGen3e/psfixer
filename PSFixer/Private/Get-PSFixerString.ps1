function Get-PSFixerString {
    <#
    .SYNOPSIS
        Looks up a localized string for the current PSFixer language
        ($script:PSFixerLanguage, set via Set-PSFixerLanguage) and optionally
        formats it with -f style placeholders.
    .PARAMETER Key
        String resource key, e.g. 'Menu.Cancelled'.
    .PARAMETER FormatArgs
        Optional array of values substituted into '{0}', '{1}', ... placeholders.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Key,

        [object[]]$FormatArgs
    )

    if (-not $script:PSFixerStrings) {
        $script:PSFixerStrings = @{}
        foreach ($lang in 'en', 'nl') {
            $path = Join-Path -Path $PSFixerModuleRoot -ChildPath "Data\Strings.$lang.json"
            $json = Get-Content -Path $path -Raw | ConvertFrom-Json

            # ConvertFrom-Json -AsHashtable isn't available on Windows PowerShell 5.1,
            # so rebuild a hashtable by hand like the other Data/*.json loaders in this module.
            $table = @{}
            foreach ($property in $json.PSObject.Properties) {
                $table[$property.Name] = $property.Value
            }
            $script:PSFixerStrings[$lang] = $table
        }
    }

    $language = if ($script:PSFixerLanguage) { $script:PSFixerLanguage } else { 'en' }
    $table = $script:PSFixerStrings[$language]

    $text = if ($table -and $table.ContainsKey($Key)) { $table[$Key] } else { $script:PSFixerStrings['en'][$Key] }
    if (-not $text) {
        throw "PSFixer: unknown string key '$Key'."
    }

    # Deliberately check ContainsKey rather than "if ($FormatArgs)" - a single-element
    # array whose one value is falsy (empty string, 0, $false, $null) would otherwise
    # make PowerShell treat $FormatArgs itself as falsy and silently skip formatting,
    # leaving literal '{0}' placeholders in the output.
    if ($PSBoundParameters.ContainsKey('FormatArgs')) {
        return ($text -f $FormatArgs)
    }
    return $text
}
