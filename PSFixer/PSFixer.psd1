@{
    RootModule            = 'PSFixer.psm1'
    ModuleVersion         = '0.11.0'
    GUID                  = '7793cad2-78b4-4ad4-ac95-6e8ba0112bd0'
    Author                = 'Stefan Siemerink'
    CompanyName            = 'Unknown'
    Copyright              = '(c) Stefan Siemerink. All rights reserved.'
    Description           = 'Diagnose, repair, and baseline framework for PowerShell administration workstations.'
    PowerShellVersion     = '5.1'
    CompatiblePSEditions  = @('Desktop', 'Core')

    FunctionsToExport     = @(
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
    AliasesToExport       = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('PowerShell', 'Modules', 'Diagnostics', 'M365', 'Azure', 'Baseline')
            ProjectUri   = ''
            LicenseUri   = ''
            ReleaseNotes = 'Install-PSFixerProfile now auto-imports installed modules for the current edition, same as Install-PSFixerModule (-NoImport to skip), for consistent behavior between the two.'
        }
    }
}
