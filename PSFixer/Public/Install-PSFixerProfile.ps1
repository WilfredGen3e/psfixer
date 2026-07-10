function Install-PSFixerProfile {
    <#
    .SYNOPSIS
        Installs the modules for a named PSFixer profile (§5.5).
    .DESCRIPTION
        Installs every module listed in the profile definition, always in a
        consistent scope (default: CurrentUser, PS7) (PRO-04). Built-in profiles
        are M365Admin and AzureEngineer; custom profiles can be supplied via
        -DefinitionPath (PRO-05).
    .PARAMETER Name
        Name of the profile to install.
    .PARAMETER Scope
        Install scope for all modules in the profile. Defaults to CurrentUser.
    .PARAMETER DefinitionPath
        Path to a custom profiles JSON file. Entries override built-in profiles
        with the same name.
    .PARAMETER TargetEdition
        Which PowerShell edition(s) to install into: 'PS7', 'WindowsPowerShell',
        or 'Both'. If omitted, prompts interactively when possible; falls back
        to whichever edition is currently running for non-interactive/scripted
        use. Installing into the "other" edition runs a real Install-Module in
        that edition's own host process (never edits $env:PSModulePath), always
        CurrentUser scope by default so no admin rights are required.
    .EXAMPLE
        Install-PSFixerProfile -Name M365Admin -WhatIf
    .EXAMPLE
        Install-PSFixerProfile -Name M365Admin -TargetEdition Both -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser',

        [string]$DefinitionPath,

        [ValidateSet('PS7', 'WindowsPowerShell', 'Both')]
        [string]$TargetEdition
    )

    $profiles = Get-PSFixerProfileDefinition -Path $DefinitionPath

    if (-not $profiles.ContainsKey($Name)) {
        throw "PSFixer profile '$Name' not found. Available profiles: $($profiles.Keys -join ', ')"
    }

    $profileDef = $profiles[$Name]
    $editions = Resolve-PSFixerTargetEdition -TargetEdition $TargetEdition
    $currentEdition = Get-PSFixerCurrentEdition

    foreach ($edition in $editions) {
        foreach ($module in $profileDef.Modules) {
            $target = if ($module.MinimumVersion) { "$($module.Name) >= $($module.MinimumVersion)" } else { $module.Name }
            $target = "$target [$edition]"

            if ($PSCmdlet.ShouldProcess($target, "Install module (Scope=$Scope)")) {
                if ($edition -eq $currentEdition) {
                    $installParams = @{
                        Name         = $module.Name
                        Scope        = $Scope
                        Force        = $true
                        AllowClobber = $true
                        ErrorAction  = 'Stop'
                    }
                    if ($module.MinimumVersion) {
                        $installParams['MinimumVersion'] = $module.MinimumVersion
                    }
                    Install-Module @installParams
                }
                else {
                    Install-PSFixerModuleInEdition -Edition $edition -Name $module.Name -MinimumVersion $module.MinimumVersion -Scope $Scope
                }
            }
        }
    }
}
