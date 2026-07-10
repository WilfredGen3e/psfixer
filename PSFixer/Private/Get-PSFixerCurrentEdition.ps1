function Get-PSFixerCurrentEdition {
    <#
    .SYNOPSIS
        Returns 'PS7' or 'WindowsPowerShell' for the PowerShell edition currently running.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($PSVersionTable.PSEdition -eq 'Core') { 'PS7' } else { 'WindowsPowerShell' }
}
