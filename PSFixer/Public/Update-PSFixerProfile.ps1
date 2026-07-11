function Update-PSFixerProfile {
    <#
    .SYNOPSIS
        Updates all modules belonging to a named PSFixer profile.
    .PARAMETER Name
        Name of the profile to update.
    .PARAMETER DefinitionPath
        Path to a custom profiles JSON file. Entries override built-in profiles
        with the same name.
    .EXAMPLE
        Update-PSFixerProfile -Name M365Admin -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [string]$DefinitionPath
    )

    $profiles = Get-PSFixerProfileDefinition -Path $DefinitionPath

    if (-not $profiles.ContainsKey($Name)) {
        throw "PSFixer profile '$Name' not found. Available profiles: $($profiles.Keys -join ', ')"
    }

    $profileDef = $profiles[$Name]

    foreach ($module in $profileDef.Modules) {
        if ($PSCmdlet.ShouldProcess($module.Name, 'Update module to latest version')) {
            if (Get-Module -ListAvailable -Name $module.Name -ErrorAction SilentlyContinue) {
                Update-Module -Name $module.Name -Force -ErrorAction Stop
            }
            else {
                Write-Warning "Module '$($module.Name)' is not installed; run Install-PSFixerProfile -Name $Name first."
            }
        }
    }
}
