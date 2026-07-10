function Update-PSFixerModule {
    <#
    .SYNOPSIS
        Updates the installed PSFixer module in place to the latest commit on GitHub.
    .DESCRIPTION
        Downloads and re-runs the same Install-PSFixer.ps1 bootstrap script used for the
        initial install, so there is a single source of truth for how PSFixer gets onto a
        machine. No PSGallery/PowerShellGet dependency; always targets the CurrentUser
        module path (same as the bootstrap script).
    .PARAMETER Repo
        GitHub "owner/name" of the PSFixer repository.
    .PARAMETER Branch
        Branch to update from.
    .EXAMPLE
        Update-PSFixerModule
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [string]$Repo = 'WilfredGen3e/psfixer',
        [string]$Branch = 'main'
    )

    if (-not $PSCmdlet.ShouldProcess('PSFixer module files', "Download and reinstall from $Repo ($Branch)")) {
        return
    }

    Write-Verbose "Huidige versie: $(Get-PSFixerVersion)"

    $scriptUrl = "https://raw.githubusercontent.com/$Repo/$Branch/Install-PSFixer.ps1"
    $bootstrap = Invoke-RestMethod -Uri $scriptUrl -UseBasicParsing
    $installer = [scriptblock]::Create($bootstrap)
    & $installer -Repo $Repo -Branch $Branch
}
