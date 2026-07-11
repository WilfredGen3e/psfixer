function Get-PSFixerModuleScope {
    <#
    .SYNOPSIS
        Classifies a module path into a PSFixer scope label.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ($Path -match '\\Program Files\\PowerShell\\Modules') { return 'AllUsers (PS7)' }
    if ($Path -match '\\Program Files\\WindowsPowerShell\\Modules') { return 'AllUsers (WindowsPowerShell)' }
    if ($Path -match '\\Documents\\PowerShell\\Modules') { return 'CurrentUser (PS7)' }
    if ($Path -match '\\Documents\\WindowsPowerShell\\Modules') { return 'CurrentUser (WindowsPowerShell)' }
    if ($Path -match '\\WindowsPowerShell\\Modules') { return 'WindowsPowerShell (System)' }
    return 'Custom'
}
