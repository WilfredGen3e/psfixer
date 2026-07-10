function Test-PSFixerInteractive {
    <#
    .SYNOPSIS
        Returns whether this session can actually use Read-Host, so callers can Mock
        it in tests.
    .DESCRIPTION
        [Environment]::UserInteractive alone isn't enough - it reflects whether the
        OS session is interactive (desktop vs. service), not whether this specific
        PowerShell process was started with -NonInteractive, which is what actually
        makes Read-Host throw ("PowerShell is in NonInteractive mode"). Both are
        checked.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not [Environment]::UserInteractive) {
        return $false
    }

    $commandLineArgs = [Environment]::GetCommandLineArgs()
    if ($commandLineArgs -contains '-NonInteractive' -or $commandLineArgs -contains '-noni') {
        return $false
    }

    return $true
}
