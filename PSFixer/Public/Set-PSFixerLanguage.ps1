function Set-PSFixerLanguage {
    <#
    .SYNOPSIS
        Sets the language PSFixer uses for interactive prompts and the HTML report.
    .DESCRIPTION
        Defaults to English. Switch to Dutch with -Language nl. Applies for the
        rest of the current session (or until changed again). Cmdlet/parameter
        names and comment-based help (Get-Help) are always English, regardless
        of this setting - that's the standard PowerShell convention and isn't
        language-sensitive. This only affects Read-Host/Write-Host prompts and
        the generated HTML analysis report.
    .PARAMETER Language
        'en' (default) or 'nl'.
    .EXAMPLE
        Set-PSFixerLanguage -Language nl
        Switches interactive prompts and the HTML report to Dutch.
    .EXAMPLE
        Set-PSFixerLanguage en
        Switches back to English.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('en', 'nl')]
        [string]$Language
    )

    $script:PSFixerLanguage = $Language
}
