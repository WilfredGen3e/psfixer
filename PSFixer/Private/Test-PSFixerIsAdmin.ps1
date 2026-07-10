function Test-PSFixerIsAdmin {
    <#
    .SYNOPSIS
        Returns whether the current session is elevated (NFR-04).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($IsLinux -or $IsMacOS) {
        return (id -u) -eq 0
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
