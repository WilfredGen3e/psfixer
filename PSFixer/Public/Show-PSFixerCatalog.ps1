function Show-PSFixerCatalog {
    <#
    .SYNOPSIS
        Shows the install menu: which profiles and standalone modules are available to install.
    .DESCRIPTION
        Independent of whether the environment is broken or clean - this is
        purely "what can I add". Shows the available PSFixer profiles first
        (Get-PSFixerProfileDefinition), then the categorized standalone-module
        catalog (Get-PSFixerPopularModuleCatalog, the same one
        Install-PSFixerModule already shows). Installs whatever you pick via
        Install-PSFixerProfile and/or Install-PSFixerModule - those remain
        usable on their own for scripted use with -Name.
    .PARAMETER Scope
        Install scope for modules/profiles. Defaults to CurrentUser (no admin
        rights required).
    .PARAMETER TargetEdition
        Which PowerShell edition(s): 'PS7', 'WindowsPowerShell', or 'Both'.
        If omitted: asked interactively, or the current edition for scripted use.
    .PARAMETER NoImport
        Don't automatically import installed modules/profiles into the
        current session.
    .PARAMETER CatalogPath
        Path to a custom catalog file (same shape as Data/PopularModules.json).
        Overrides built-in entries with the same category+name.
    .PARAMETER ProfileDefinitionPath
        Path to a custom profile definitions file. Overrides built-in
        profiles with the same name.
    .EXAMPLE
        Show-PSFixerCatalog
        Shows the profile/module menu and installs whatever you pick.
    .EXAMPLE
        Show-PSFixerCatalog -TargetEdition Both -Confirm:$false
        Same menu, installs directly into both editions without confirming.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser',

        [ValidateSet('PS7', 'WindowsPowerShell', 'Both')]
        [string]$TargetEdition,

        [switch]$NoImport,

        [string]$CatalogPath,

        [string]$ProfileDefinitionPath
    )

    if (-not (Test-PSFixerInteractive)) {
        throw 'Show-PSFixerCatalog heeft een interactieve sessie nodig om het keuzemenu te tonen. Gebruik Install-PSFixerProfile -Name/Install-PSFixerModule -Name rechtstreeks voor non-interactief/scriptgebruik.'
    }

    $profiles = Get-PSFixerProfileDefinition -Path $ProfileDefinitionPath
    $profileName = Read-PSFixerProfileSelection -Profiles $profiles

    Write-Host ''
    $catalog = Get-PSFixerPopularModuleCatalog -Path $CatalogPath
    $moduleNames = Read-PSFixerModuleSelection -Catalog $catalog

    if (-not $profileName -and -not $moduleNames) {
        Write-Host 'Niets geselecteerd.' -ForegroundColor Yellow
        return
    }

    if ($profileName) {
        $installProfileParams = @{ Name = $profileName; Scope = $Scope }
        if ($TargetEdition) { $installProfileParams['TargetEdition'] = $TargetEdition }
        if ($NoImport) { $installProfileParams['NoImport'] = $true }
        Install-PSFixerProfile @installProfileParams -WhatIf:$WhatIfPreference -Confirm:$ConfirmPreference
    }

    if ($moduleNames) {
        $installModuleParams = @{ Name = $moduleNames; Scope = $Scope }
        if ($TargetEdition) { $installModuleParams['TargetEdition'] = $TargetEdition }
        if ($NoImport) { $installModuleParams['NoImport'] = $true }
        Install-PSFixerModule @installModuleParams -WhatIf:$WhatIfPreference -Confirm:$ConfirmPreference
    }
}
