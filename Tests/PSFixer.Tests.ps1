#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

$modulePath = Join-Path $PSScriptRoot '..\PSFixer\PSFixer.psd1'
Import-Module $modulePath -Force

Describe 'Get-PSFixerModuleScope (private, via module scope)' {
    InModuleScope PSFixer {
        It 'classifies AllUsers PS7 paths' {
            Get-PSFixerModuleScope -Path 'C:\Program Files\PowerShell\Modules\Az\1.0.0' | Should -Be 'AllUsers (PS7)'
        }
        It 'classifies CurrentUser PS7 paths' {
            Get-PSFixerModuleScope -Path 'C:\Users\jdoe\Documents\PowerShell\Modules\Az\1.0.0' | Should -Be 'CurrentUser (PS7)'
        }
        It 'classifies WindowsPowerShell AllUsers paths' {
            Get-PSFixerModuleScope -Path 'C:\Program Files\WindowsPowerShell\Modules\Az\1.0.0' | Should -Be 'AllUsers (WindowsPowerShell)'
        }
        It 'falls back to Custom for unrecognized paths' {
            Get-PSFixerModuleScope -Path 'D:\Tools\MyModules\Az\1.0.0' | Should -Be 'Custom'
        }
    }
}

Describe 'Invoke-PSFixerAnalysis' {
    BeforeAll {
        $fakeInventory = [pscustomobject]@{
            PSTypeName        = 'PSFixer.Inventory'
            Modules           = @(
                [pscustomobject]@{ Name = 'Az.Accounts'; Version = [version]'3.0.0'; Path = 'C:\A\Az.Accounts\3.0.0'; Scope = 'CurrentUser (PS7)' }
                [pscustomobject]@{ Name = 'Az.Accounts'; Version = [version]'2.0.0'; Path = 'C:\B\Az.Accounts\2.0.0'; Scope = 'AllUsers (PS7)' }
                [pscustomobject]@{ Name = 'MSOnline'; Version = [version]'1.1.183.66'; Path = 'C:\C\MSOnline\1.1.183.66'; Scope = 'CurrentUser (PS7)' }
                [pscustomobject]@{ Name = 'Microsoft.Graph'; Version = [version]'2.0.0'; Path = 'C:\D\Microsoft.Graph\2.0.0'; Scope = 'CurrentUser (PS7)' }
            )
            Repositories      = @(
                [pscustomobject]@{ Name = 'PSGallery'; Uri = 'https://www.powershellgallery.com/api/v2'; Trusted = $false; Priority = $null; Provider = 'PowerShellGet' }
            )
            PackageProviders  = @(
                [pscustomobject]@{ Name = 'NuGet'; Version = [version]'2.8.5.201' }
            )
        }

        $findings = $fakeInventory | Invoke-PSFixerAnalysis
    }

    It 'detects duplicate modules across locations (ANA-01)' {
        $findings | Where-Object { $_.Category -eq 'DuplicateModule' -and $_.Item -eq 'Az.Accounts' } | Should -Not -BeNullOrEmpty
    }

    It 'detects multiple installed versions (ANA-02)' {
        $findings | Where-Object { $_.Category -eq 'MultipleVersions' -and $_.Item -eq 'Az.Accounts' } | Should -Not -BeNullOrEmpty
    }

    It 'detects legacy modules (ANA-05)' {
        $finding = $findings | Where-Object { $_.Category -eq 'LegacyModule' -and $_.Item -eq 'MSOnline' }
        $finding | Should -Not -BeNullOrEmpty
        $finding.Severity | Should -Be 'Critical'
    }

    It 'detects command conflicts between legacy and modern modules (ANA-04)' {
        $findings | Where-Object { $_.Category -eq 'CommandConflict' } | Should -Not -BeNullOrEmpty
    }

    It 'detects an untrusted PSGallery (ANA-06)' {
        $finding = $findings | Where-Object { $_.Category -eq 'Repository' -and $_.Item -eq 'PSGallery' }
        $finding | Should -Not -BeNullOrEmpty
        $finding.Severity | Should -Be 'Warning'
    }

    It 'does not flag a compliant NuGet provider (ANA-07)' {
        $findings | Where-Object { $_.Category -eq 'PackageProvider' -and $_.Item -eq 'NuGet' } | Should -BeNullOrEmpty
    }
}

Describe 'Install-PSFixerProfile' {
    It 'throws a clear error for an unknown profile name' {
        { Install-PSFixerProfile -Name 'DoesNotExist' -WhatIf } | Should -Throw "*DoesNotExist*"
    }
}
