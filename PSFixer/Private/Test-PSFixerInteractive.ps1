function Test-PSFixerInteractive {
    <#
    .SYNOPSIS
        Thin wrapper around [Environment]::UserInteractive, so callers can Mock it in tests.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    [Environment]::UserInteractive
}
