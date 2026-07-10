function Resolve-PSFixerTargetEdition {
    <#
    .SYNOPSIS
        Resolves -TargetEdition into a concrete list of one or two editions to act on.
    .DESCRIPTION
        If -TargetEdition wasn't specified: prompts interactively (session
        permitting) so the user can choose, otherwise falls back to whichever
        edition is currently running (today's behavior, safe for automation).
    .PARAMETER TargetEdition
        'PS7', 'WindowsPowerShell', 'Both', or empty/omitted to resolve.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [string]$TargetEdition
    )

    if (-not $TargetEdition) {
        if (Test-PSFixerInteractive) {
            $TargetEdition = Read-PSFixerTargetEdition
        }
        else {
            $TargetEdition = Get-PSFixerCurrentEdition
        }
    }

    if ($TargetEdition -eq 'Both') {
        return @('PS7', 'WindowsPowerShell')
    }

    return @($TargetEdition)
}
