@{
    RootModule            = 'PSFixer.psm1'
    ModuleVersion         = '0.11.1'
    GUID                  = '7793cad2-78b4-4ad4-ac95-6e8ba0112bd0'
    Author                = 'Stefan Siemerink'
    CompanyName            = 'Unknown'
    Copyright              = '(c) 2026 Stefan Siemerink. Licensed under the MIT License.'
    Description           = 'Diagnose, repair, and baseline framework for PowerShell administration workstations.'
    PowerShellVersion     = '5.1'
    CompatiblePSEditions  = @('Desktop', 'Core')

    FunctionsToExport     = @(
        'Test-PSFixer'
        'Repair-PSFixer'
        'Show-PSFixerCatalog'
        'Set-PSFixerLanguage'
        'Get-PSFixerInventory'
        'Get-PSFixerModule'
        'Get-PSFixerRepository'
        'Get-PSFixerVersion'
        'Invoke-PSFixerAnalysis'
        'Reset-PSFixerEnvironment'
        'Set-PSFixerBaseline'
        'Test-PSFixerBaseline'
        'Install-PSFixerProfile'
        'Install-PSFixerModule'
        'Update-PSFixerProfile'
        'Update-PSFixerModule'
        'Restore-PSFixerSnapshot'
    )
    CmdletsToExport       = @()
    VariablesToExport     = @()
    AliasesToExport       = @('psdiag', 'psfix', 'pscat')

    PrivateData = @{
        PSData = @{
            Tags         = @('PowerShell', 'Modules', 'Diagnostics', 'M365', 'Azure', 'Baseline')
            ProjectUri   = 'https://github.com/WilfredGen3e/psfixer'
            LicenseUri   = 'https://github.com/WilfredGen3e/psfixer/blob/main/LICENSE'
            ReleaseNotes = 'Import failures after Install-PSFixerProfile/Install-PSFixerModule now surface as a warning instead of being silently swallowed.'
        }
    }
}
