function Read-PSFixerTargetEdition {
    <#
    .SYNOPSIS
        Interactively asks which PowerShell edition(s) to target.
    .DESCRIPTION
        Used by cmdlets that touch modules (Install-PSFixerProfile,
        Reset-PSFixerEnvironment) when -TargetEdition wasn't specified and the
        session is interactive. Non-interactive callers should skip this and
        fall back to Get-PSFixerCurrentEdition instead.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    Write-Host ''
    Write-Host (Get-PSFixerString -Key 'TargetEdition.Question') -ForegroundColor Cyan
    Write-Host (Get-PSFixerString -Key 'TargetEdition.OptionPS7')
    Write-Host (Get-PSFixerString -Key 'TargetEdition.OptionWindowsPowerShell')
    Write-Host (Get-PSFixerString -Key 'TargetEdition.OptionBoth')

    try {
        $choice = Read-Host -Prompt (Get-PSFixerString -Key 'TargetEdition.ChoicePrompt')
    }
    catch {
        # Read-Host can still fail even when Test-PSFixerInteractive says yes (host
        # quirks) - fall back to the safe/recommended default rather than crashing.
        Write-Verbose "Could not interactively ask which edition: $_. Falling back to PS7."
        return 'PS7'
    }

    switch ($choice) {
        '2' { 'WindowsPowerShell' }
        '3' { 'Both' }
        default { 'PS7' }
    }
}
