function Get-PSFixerVersion {
    <#
    .SYNOPSIS
        Returns the installed PSFixer module version.
    .EXAMPLE
        Get-PSFixerVersion
    #>
    [CmdletBinding()]
    [OutputType([version])]
    param()

    $MyInvocation.MyCommand.Module.Version
}
