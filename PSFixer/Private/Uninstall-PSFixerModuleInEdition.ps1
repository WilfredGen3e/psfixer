function Uninstall-PSFixerModuleInEdition {
    <#
    .SYNOPSIS
        Uninstalls one module+version by running Uninstall-Module/-PSResource
        inside the target PowerShell edition's own host process.
    .PARAMETER Edition
        'PS7' or 'WindowsPowerShell'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('PS7', 'WindowsPowerShell')]
        [string]$Edition,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Version
    )

    $exe = Get-PSFixerEditionExecutable -Edition $Edition

    $script = @"
`$ErrorActionPreference = 'Stop'
if (Get-Command -Name Uninstall-PSResource -ErrorAction SilentlyContinue) {
    Uninstall-PSResource -Name '$Name' -Version '$Version' -SkipDependencyCheck -ErrorAction Stop -WarningAction Stop
}
else {
    Uninstall-Module -Name '$Name' -RequiredVersion '$Version' -Force -ErrorAction Stop -WarningAction Stop
}
"@

    $tempScript = Join-Path -Path $env:TEMP -ChildPath "psfixer-uninstall-$([guid]::NewGuid()).ps1"
    Set-Content -Path $tempScript -Value $script -Encoding UTF8

    try {
        & $exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $tempScript 2>&1 | ForEach-Object { Write-Verbose $_ }
    }
    finally {
        Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
    }
}
