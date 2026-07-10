function Install-PSFixerModuleInEdition {
    <#
    .SYNOPSIS
        Installs a module by actually running Install-Module inside the target
        PowerShell edition's own host process, so it lands in that edition's
        module path.
    .PARAMETER Edition
        'PS7' or 'WindowsPowerShell'.
    .PARAMETER Scope
        Install scope. Defaults to CurrentUser, which never requires admin
        rights - AllUsers does, same as when installing in-process.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('PS7', 'WindowsPowerShell')]
        [string]$Edition,

        [Parameter(Mandatory)]
        [string]$Name,

        [string]$MinimumVersion,

        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser'
    )

    $exe = Get-PSFixerEditionExecutable -Edition $Edition

    $minVersionArg = if ($MinimumVersion) { " -MinimumVersion '$MinimumVersion'" } else { '' }
    $script = "`$ErrorActionPreference = 'Stop'`nInstall-Module -Name '$Name' -Scope $Scope -Force -AllowClobber$minVersionArg"

    $tempScript = Join-Path -Path $env:TEMP -ChildPath "psfixer-install-$([guid]::NewGuid()).ps1"
    Set-Content -Path $tempScript -Value $script -Encoding UTF8

    try {
        & $exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $tempScript 2>&1 | ForEach-Object { Write-Verbose $_ }
        if ($LASTEXITCODE -ne 0) {
            throw "Install-Module voor '$Name' in $Edition gaf exit code $LASTEXITCODE."
        }
    }
    finally {
        Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
    }
}
