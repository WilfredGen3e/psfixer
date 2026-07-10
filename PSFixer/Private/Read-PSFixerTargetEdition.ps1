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
    Write-Host 'In welke PowerShell-editie wil je dit uitvoeren?' -ForegroundColor Cyan
    Write-Host '  [1] Alleen PowerShell 7 (aanbevolen)'
    Write-Host '  [2] Alleen Windows PowerShell 5.1'
    Write-Host '  [3] Beide'
    $choice = Read-Host -Prompt 'Keuze [1]'

    switch ($choice) {
        '2' { 'WindowsPowerShell' }
        '3' { 'Both' }
        default { 'PS7' }
    }
}
