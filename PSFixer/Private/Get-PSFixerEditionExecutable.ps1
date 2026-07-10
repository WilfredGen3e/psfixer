function Get-PSFixerEditionExecutable {
    <#
    .SYNOPSIS
        Resolves the executable path for a given PowerShell edition.
    .PARAMETER Edition
        'PS7' or 'WindowsPowerShell'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('PS7', 'WindowsPowerShell')]
        [string]$Edition
    )

    if ($Edition -eq 'PS7') {
        $cmd = Get-Command -Name pwsh -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd) { return $cmd.Source }

        foreach ($candidate in @("$env:ProgramFiles\PowerShell\7\pwsh.exe", "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe")) {
            if ($candidate -and (Test-Path -Path $candidate)) { return $candidate }
        }

        throw 'PowerShell 7 (pwsh.exe) is niet gevonden op dit systeem.'
    }

    $candidate = Join-Path -Path $env:WINDIR -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path -Path $candidate) { return $candidate }

    throw 'Windows PowerShell 5.1 (powershell.exe) is niet gevonden op dit systeem.'
}
