function Install-PSFixerModule {
    <#
    .SYNOPSIS
        Interactively pick and install one or more popular modules (or specify
        exactly which ones), in the right PowerShell edition and version.
    .DESCRIPTION
        Without -Name, shows a categorized checklist of commonly used modules
        (see Data/PopularModules.json, override with -CatalogPath) and asks
        which to install. For each selected module, asks which version to pin
        (blank = latest) unless already supplied via -Version. Modules
        installed for the currently running edition are imported immediately
        afterward unless -NoImport is specified.
    .PARAMETER Name
        Module name(s) to install. Skips the interactive catalog picker.
    .PARAMETER Version
        Optional hashtable of ModuleName -> exact version to pin. Modules not
        listed here fall back to an interactive per-module version prompt
        (blank = latest) when the session is interactive, or latest otherwise.
    .PARAMETER Scope
        Install scope. Defaults to CurrentUser (no admin rights required).
    .PARAMETER TargetEdition
        Which PowerShell edition(s) to install into: 'PS7', 'WindowsPowerShell',
        or 'Both'. If omitted, prompts interactively when possible; falls back
        to whichever edition is currently running for non-interactive/scripted
        use. See Install-PSFixerProfile for how cross-edition installs work.
    .PARAMETER NoImport
        Don't Import-Module the freshly installed modules into the current
        session afterward.
    .PARAMETER CatalogPath
        Path to a custom catalog JSON file (same shape as Data/PopularModules.json).
        Entries override built-in entries with the same category.
    .EXAMPLE
        Install-PSFixerModule
    .EXAMPLE
        Install-PSFixerModule -Name Az.Accounts, Microsoft.Graph.Authentication -TargetEdition Both -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [string[]]$Name,

        [hashtable]$Version = @{},

        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser',

        [ValidateSet('PS7', 'WindowsPowerShell', 'Both')]
        [string]$TargetEdition,

        [switch]$NoImport,

        [string]$CatalogPath
    )

    if (-not $Name) {
        $catalog = Get-PSFixerPopularModuleCatalog -Path $CatalogPath
        $Name = Read-PSFixerModuleSelection -Catalog $catalog

        if (-not $Name) {
            Write-Host 'Geen modules geselecteerd.' -ForegroundColor Yellow
            return
        }
    }

    $resolvedVersions = @{}
    foreach ($moduleName in $Name) {
        if ($Version.ContainsKey($moduleName)) {
            $resolvedVersions[$moduleName] = $Version[$moduleName]
        }
        elseif (Test-PSFixerInteractive) {
            try {
                $answer = Read-Host -Prompt "Versie voor '$moduleName' (leeg = nieuwste)"
            }
            catch {
                # Read-Host can still fail even when Test-PSFixerInteractive says yes (host
                # quirks) - fall back to "latest" rather than crashing.
                Write-Verbose "Kon niet interactief om een versie vragen voor '$moduleName': $_. Gebruik nieuwste."
                $answer = $null
            }
            if ($answer) {
                $resolvedVersions[$moduleName] = $answer
            }
        }
    }

    $editions = Resolve-PSFixerTargetEdition -TargetEdition $TargetEdition
    $currentEdition = Get-PSFixerCurrentEdition

    foreach ($edition in $editions) {
        foreach ($moduleName in $Name) {
            $requiredVersion = $resolvedVersions[$moduleName]
            $target = if ($requiredVersion) { "$moduleName $requiredVersion" } else { $moduleName }
            $target = "$target [$edition]"

            if ($PSCmdlet.ShouldProcess($target, "Install module (Scope=$Scope)")) {
                if ($edition -eq $currentEdition) {
                    $installParams = @{
                        Name         = $moduleName
                        Scope        = $Scope
                        Force        = $true
                        AllowClobber = $true
                        ErrorAction  = 'Stop'
                    }
                    if ($requiredVersion) {
                        $installParams['RequiredVersion'] = $requiredVersion
                    }
                    Install-Module @installParams

                    if (-not $NoImport) {
                        try {
                            Import-Module -Name $moduleName -Force -ErrorAction Stop
                        }
                        catch {
                            Write-Warning "Module '$moduleName' is installed but could not be imported into this session: $_"
                        }
                    }
                }
                else {
                    Install-PSFixerModuleInEdition -Edition $edition -Name $moduleName -RequiredVersion $requiredVersion -Scope $Scope
                }
            }
        }
    }
}
