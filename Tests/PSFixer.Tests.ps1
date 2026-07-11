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
                [pscustomobject]@{ Name = 'Az.Accounts'; Version = [version]'3.0.0'; Path = 'C:\A\Az.Accounts\3.0.0'; Scope = 'CurrentUser (PS7)'; Managed = $true }
                [pscustomobject]@{ Name = 'Az.Accounts'; Version = [version]'2.0.0'; Path = 'C:\B\Az.Accounts\2.0.0'; Scope = 'AllUsers (PS7)'; Managed = $true }
                [pscustomobject]@{ Name = 'MSOnline'; Version = [version]'1.1.183.66'; Path = 'C:\C\MSOnline\1.1.183.66'; Scope = 'CurrentUser (PS7)'; Managed = $true }
                [pscustomobject]@{ Name = 'Microsoft.Graph'; Version = [version]'2.0.0'; Path = 'C:\D\Microsoft.Graph\2.0.0'; Scope = 'CurrentUser (PS7)'; Managed = $true }
            )
            Repositories      = @(
                [pscustomobject]@{ Name = 'PSGallery'; Uri = 'https://www.powershellgallery.com/api/v2'; Trusted = $false; Priority = $null; Provider = 'PowerShellGet' }
            )
            PackageProviders  = @(
                [pscustomobject]@{ Name = 'NuGet'; Version = [version]'2.8.5.201' }
            )
        }

        $findings = $fakeInventory | Invoke-PSFixerAnalysis -NoReport
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

Describe 'Invoke-PSFixerAnalysis unmanaged module filtering' {
    BeforeAll {
        $fakeInventory = [pscustomobject]@{
            PSTypeName       = 'PSFixer.Inventory'
            Modules          = @(
                # In-box Windows module: two copies, neither ever installed via the package
                # manager - should NOT be flagged by default (nothing a user can fix).
                [pscustomobject]@{ Name = 'PackageManagement'; Version = [version]'1.4.8.1'; Path = 'C:\A\PackageManagement\1.4.8.1'; Scope = 'AllUsers (WindowsPowerShell)'; Managed = $false }
                [pscustomobject]@{ Name = 'PackageManagement'; Version = [version]'1.4.8.1'; Path = 'C:\B\PackageManagement\1.4.8.1'; Scope = 'Custom'; Managed = $false }
                # Genuine actionable duplicate: both copies are package-manager managed.
                [pscustomobject]@{ Name = 'Az.Tools.Predictor'; Version = [version]'1.0.0'; Path = 'C:\C\Az.Tools.Predictor\1.0.0'; Scope = 'CurrentUser (PS7)'; Managed = $true }
                [pscustomobject]@{ Name = 'Az.Tools.Predictor'; Version = [version]'1.0.0'; Path = 'C:\D\Az.Tools.Predictor\1.0.0'; Scope = 'AllUsers (PS7)'; Managed = $true }
            )
            Repositories     = @([pscustomobject]@{ Name = 'PSGallery'; Uri = 'https://www.powershellgallery.com/api/v2'; Trusted = $true; Priority = $null; Provider = 'PowerShellGet' })
            PackageProviders = @([pscustomobject]@{ Name = 'NuGet'; Version = [version]'2.8.5.201' })
        }
    }

    It 'excludes unmanaged (in-box) modules from DuplicateModule by default' {
        $findings = $fakeInventory | Invoke-PSFixerAnalysis -NoReport
        $findings | Where-Object { $_.Category -eq 'DuplicateModule' -and $_.Item -eq 'PackageManagement' } | Should -BeNullOrEmpty
    }

    It 'still flags a genuine duplicate between two managed entries' {
        $findings = $fakeInventory | Invoke-PSFixerAnalysis -NoReport
        $findings | Where-Object { $_.Category -eq 'DuplicateModule' -and $_.Item -eq 'Az.Tools.Predictor' } | Should -Not -BeNullOrEmpty
    }

    It 'includes unmanaged modules again with -IncludeUnmanaged' {
        $findings = $fakeInventory | Invoke-PSFixerAnalysis -NoReport -IncludeUnmanaged
        $findings | Where-Object { $_.Category -eq 'DuplicateModule' -and $_.Item -eq 'PackageManagement' } | Should -Not -BeNullOrEmpty
    }
}

Describe 'Invoke-PSFixerAnalysis HTML report' {
    BeforeAll {
        $fakeInventory = [pscustomobject]@{
            PSTypeName       = 'PSFixer.Inventory'
            Modules          = @()
            Repositories     = @([pscustomobject]@{ Name = 'PSGallery'; Uri = 'https://www.powershellgallery.com/api/v2'; Trusted = $true; Priority = $null; Provider = 'PowerShellGet' })
            PackageProviders = @([pscustomobject]@{ Name = 'NuGet'; Version = [version]'2.8.5.201' })
            PowerShellVersions = @([pscustomobject]@{ Edition = 'Core'; Version = [version]'7.4.0'; Path = 'pwsh.exe'; IsActiveSession = $true })
        }
        $reportDir = Join-Path $HOME 'psfixerreports'
        $before = if (Test-Path $reportDir) { @(Get-ChildItem $reportDir -Filter 'psfixer-report-*.html').Count } else { 0 }
    }

    It 'writes an HTML report file by default' {
        # -NoOpenReport only suppresses the browser launch, not the file write, so this still
        # exercises the real default report-writing path without popping a window during CI.
        $fakeInventory | Invoke-PSFixerAnalysis -NoOpenReport *> $null
        $after = @(Get-ChildItem $reportDir -Filter 'psfixer-report-*.html').Count
        $after | Should -Be ($before + 1)
    }

    It 'skips writing a report with -NoReport' {
        $before2 = @(Get-ChildItem $reportDir -Filter 'psfixer-report-*.html').Count
        $fakeInventory | Invoke-PSFixerAnalysis -NoReport *> $null
        $after2 = @(Get-ChildItem $reportDir -Filter 'psfixer-report-*.html').Count
        $after2 | Should -Be $before2
    }

    It 'produces a self-contained HTML document with severity tiles' {
        InModuleScope PSFixer -Parameters @{ fakeInventory = $fakeInventory } {
            param($fakeInventory)
            $html = New-PSFixerHtmlReport -Inventory $fakeInventory -Findings @()
            $html | Should -Match '<!doctype html>'
            $html | Should -Match 'No findings'
        }
    }

    It 'opens the report in the default browser by default' {
        InModuleScope PSFixer -Parameters @{ fakeInventory = $fakeInventory } {
            param($fakeInventory)
            Mock Start-Process {}
            $fakeInventory | Invoke-PSFixerAnalysis *> $null
            Should -Invoke Start-Process -Times 1
        }
    }

    It 'does not open the report with -NoOpenReport' {
        InModuleScope PSFixer -Parameters @{ fakeInventory = $fakeInventory } {
            param($fakeInventory)
            Mock Start-Process {}
            $fakeInventory | Invoke-PSFixerAnalysis -NoOpenReport *> $null
            Should -Invoke Start-Process -Times 0
        }
    }
}

Describe 'Get-PSFixerProfileDefinition built-in profiles' {
    It 'defines all five built-in profiles (PRO-01/02/03) with a description and at least one module' {
        InModuleScope PSFixer {
            $profiles = Get-PSFixerProfileDefinition
            $profiles.Keys | Sort-Object | Should -Be @('AzureEngineer', 'Helpdesk', 'IntuneAdmin', 'M365Admin', 'SecurityConsultant')
            foreach ($name in $profiles.Keys) {
                $profiles[$name].Description | Should -Not -BeNullOrEmpty -Because "$name needs a Description"
                @($profiles[$name].Modules).Count | Should -BeGreaterThan 0 -Because "$name needs at least one module"
                foreach ($module in $profiles[$name].Modules) {
                    $module.Name | Should -Not -BeNullOrEmpty -Because "every module entry in $name needs a Name"
                }
            }
        }
    }
}

Describe 'Install-PSFixerProfile' {
    It 'throws a clear error for an unknown profile name' {
        { Install-PSFixerProfile -Name 'DoesNotExist' -WhatIf } | Should -Throw "*DoesNotExist*"
    }

    It 'installs in-process for the current edition and via the other-edition helper for the other one' {
        InModuleScope PSFixer {
            Mock Get-PSFixerCurrentEdition { 'PS7' }
            Mock Install-Module {}
            Mock Install-PSFixerModuleInEdition {}
            Mock Import-Module {}

            Install-PSFixerProfile -Name AzureEngineer -TargetEdition Both -Confirm:$false

            Should -Invoke Install-Module -Times 1 -ParameterFilter { $Name -eq 'Az' }
            Should -Invoke Install-PSFixerModuleInEdition -Times 1 -ParameterFilter { $Edition -eq 'WindowsPowerShell' -and $Name -eq 'Az' }
        }
    }

    It 'does not touch the other edition when -TargetEdition is a single edition' {
        InModuleScope PSFixer {
            Mock Get-PSFixerCurrentEdition { 'PS7' }
            Mock Install-Module {}
            Mock Install-PSFixerModuleInEdition {}
            Mock Import-Module {}

            Install-PSFixerProfile -Name AzureEngineer -TargetEdition PS7 -Confirm:$false

            Should -Invoke Install-Module -Times 1
            Should -Invoke Install-PSFixerModuleInEdition -Times 0
        }
    }

    It 'imports each installed module for the current edition unless -NoImport' {
        InModuleScope PSFixer {
            Mock Get-PSFixerCurrentEdition { 'PS7' }
            Mock Install-Module {}
            Mock Import-Module {}

            Install-PSFixerProfile -Name M365Admin -TargetEdition PS7 -Confirm:$false

            Should -Invoke Import-Module -Times 1 -ParameterFilter { $Name -eq 'Microsoft.Graph' }
            Should -Invoke Import-Module -Times 1 -ParameterFilter { $Name -eq 'ExchangeOnlineManagement' }
        }
    }

    It 'does not import anything with -NoImport' {
        InModuleScope PSFixer {
            Mock Get-PSFixerCurrentEdition { 'PS7' }
            Mock Install-Module {}
            Mock Import-Module {}

            Install-PSFixerProfile -Name M365Admin -TargetEdition PS7 -Confirm:$false -NoImport

            Should -Invoke Import-Module -Times 0
        }
    }
}

Describe 'Install-PSFixerModule' {
    It 'skips the catalog picker when -Name is given' {
        InModuleScope PSFixer {
            Mock Get-PSFixerCurrentEdition { 'PS7' }
            Mock Read-PSFixerModuleSelection {}
            Mock Test-PSFixerInteractive { $false }
            Mock Install-Module {}

            Install-PSFixerModule -Name 'Az.Accounts' -TargetEdition PS7 -Confirm:$false -NoImport

            Should -Invoke Read-PSFixerModuleSelection -Times 0
            Should -Invoke Install-Module -Times 1 -ParameterFilter { $Name -eq 'Az.Accounts' }
        }
    }

    It 'shows the picker and stops cleanly when nothing is selected' {
        InModuleScope PSFixer {
            Mock Read-PSFixerModuleSelection { @() }
            Mock Install-Module {}

            Install-PSFixerModule -Confirm:$false

            Should -Invoke Install-Module -Times 0
        }
    }

    It 'uses the picker result when -Name is omitted' {
        InModuleScope PSFixer {
            Mock Get-PSFixerCurrentEdition { 'PS7' }
            Mock Read-PSFixerModuleSelection { @('Pester') }
            Mock Test-PSFixerInteractive { $false }
            Mock Install-Module {}

            Install-PSFixerModule -TargetEdition PS7 -Confirm:$false -NoImport

            Should -Invoke Install-Module -Times 1 -ParameterFilter { $Name -eq 'Pester' }
        }
    }

    It 'pins the version from -Version without prompting for that module' {
        InModuleScope PSFixer {
            Mock Get-PSFixerCurrentEdition { 'PS7' }
            Mock Test-PSFixerInteractive { $true }
            Mock Read-Host {}
            Mock Install-Module {}

            Install-PSFixerModule -Name 'Pester' -Version @{ Pester = '5.5.0' } -TargetEdition PS7 -Confirm:$false -NoImport

            Should -Invoke Read-Host -Times 0
            Should -Invoke Install-Module -Times 1 -ParameterFilter { $Name -eq 'Pester' -and $RequiredVersion -eq '5.5.0' }
        }
    }

    It 'installs in-process for the current edition and via the other-edition helper for the other one' {
        InModuleScope PSFixer {
            Mock Get-PSFixerCurrentEdition { 'PS7' }
            Mock Test-PSFixerInteractive { $false }
            Mock Install-Module {}
            Mock Install-PSFixerModuleInEdition {}

            Install-PSFixerModule -Name 'Pester' -TargetEdition Both -Confirm:$false -NoImport

            Should -Invoke Install-Module -Times 1 -ParameterFilter { $Name -eq 'Pester' }
            Should -Invoke Install-PSFixerModuleInEdition -Times 1 -ParameterFilter { $Edition -eq 'WindowsPowerShell' -and $Name -eq 'Pester' }
        }
    }

    It 'imports the module after installing for the current edition unless -NoImport' {
        InModuleScope PSFixer {
            Mock Get-PSFixerCurrentEdition { 'PS7' }
            Mock Test-PSFixerInteractive { $false }
            Mock Install-Module {}
            Mock Import-Module {}

            Install-PSFixerModule -Name 'Pester' -TargetEdition PS7 -Confirm:$false

            Should -Invoke Import-Module -Times 1 -ParameterFilter { $Name -eq 'Pester' }
        }
    }

    It 'does not install or import anything under -WhatIf' {
        InModuleScope PSFixer {
            Mock Get-PSFixerCurrentEdition { 'PS7' }
            Mock Test-PSFixerInteractive { $false }
            Mock Install-Module {}
            Mock Import-Module {}

            Install-PSFixerModule -Name 'Pester' -TargetEdition PS7 -WhatIf

            Should -Invoke Install-Module -Times 0
            Should -Invoke Import-Module -Times 0
        }
    }
}

Describe 'Resolve-PSFixerTargetEdition' {
    InModuleScope PSFixer {
        It 'returns the explicit single edition without prompting' {
            Mock Read-PSFixerTargetEdition {}
            Resolve-PSFixerTargetEdition -TargetEdition 'WindowsPowerShell' | Should -Be 'WindowsPowerShell'
            Should -Invoke Read-PSFixerTargetEdition -Times 0
        }

        It 'expands Both into both editions' {
            Resolve-PSFixerTargetEdition -TargetEdition 'Both' | Should -Be @('PS7', 'WindowsPowerShell')
        }

        It 'prompts interactively when omitted and the session is interactive' {
            Mock Test-PSFixerInteractive { $true }
            Mock Read-PSFixerTargetEdition { 'WindowsPowerShell' }
            Resolve-PSFixerTargetEdition | Should -Be 'WindowsPowerShell'
            Should -Invoke Read-PSFixerTargetEdition -Times 1
        }

        It 'falls back to the current edition when omitted and non-interactive' {
            Mock Test-PSFixerInteractive { $false }
            Mock Get-PSFixerCurrentEdition { 'PS7' }
            Mock Read-PSFixerTargetEdition {}
            Resolve-PSFixerTargetEdition | Should -Be 'PS7'
            Should -Invoke Read-PSFixerTargetEdition -Times 0
        }
    }
}

Describe 'Reset-PSFixerEnvironment -Scope Modules with -TargetEdition' {
    It 'cleans up the other edition via the cross-process helper, not the in-process cmdlets' {
        InModuleScope PSFixer {
            Mock Get-PSFixerInventory {
                [pscustomobject]@{
                    Modules           = @()
                    Repositories      = @()
                    PackageProviders  = @()
                    PowerShellVersions = @()
                }
            }
            Mock Get-PSFixerCurrentEdition { 'PS7' }
            Mock Get-PSFixerEditionModuleDump {
                @(
                    [pscustomobject]@{ Name = 'Az.Accounts'; Version = [version]'2.0.0'; Path = 'C:\Fake\Az.Accounts\2.0.0'; Managed = $true }
                    [pscustomobject]@{ Name = 'Az.Accounts'; Version = [version]'1.0.0'; Path = 'C:\Fake\Az.Accounts\1.0.0'; Managed = $true }
                )
            }
            Mock Uninstall-PSFixerModuleInEdition {}
            Mock Uninstall-Module {}
            Mock Uninstall-PSResource {}
            Mock Test-Path { $false }

            Reset-PSFixerEnvironment -Scope Modules -TargetEdition WindowsPowerShell -Confirm:$false

            Should -Invoke Uninstall-PSFixerModuleInEdition -Times 1 -ParameterFilter {
                $Edition -eq 'WindowsPowerShell' -and $Name -eq 'Az.Accounts' -and $Version -eq '1.0.0'
            }
            Should -Invoke Uninstall-Module -Times 0
            Should -Invoke Uninstall-PSResource -Times 0
        }
    }
}

Describe 'Repository trust fixes PowerShellGet and PSResourceGet both' {
    # Regression: PowerShellGet (Set-PSRepository) and PSResourceGet (Set-PSResourceRepository)
    # keep entirely separate trust settings for PSGallery. Get-PSFixerRepository/ANA-06 prefer
    # PSResourceGet when present, so a remediation that only touches PowerShellGet never actually
    # clears the "PSGallery ... not Trusted" finding when PSResourceGet is installed.

    It 'Reset-PSFixerEnvironment -Scope Repositories trusts PSGallery in both' {
        InModuleScope PSFixer {
            Mock Get-PSFixerInventory {
                [pscustomobject]@{ Modules = @(); Repositories = @(); PackageProviders = @(); PowerShellVersions = @() }
            }
            Mock Get-PSRepository { [pscustomobject]@{ Name = 'PSGallery' } }
            Mock Set-PSRepository {}
            Mock Register-PSRepository {}
            Mock Get-PSResourceRepository { [pscustomobject]@{ Name = 'PSGallery'; Trusted = $false } }
            Mock Set-PSResourceRepository {}
            Mock Register-PSResourceRepository {}

            Reset-PSFixerEnvironment -Scope Repositories -Confirm:$false

            Should -Invoke Set-PSRepository -Times 1 -ParameterFilter { $Name -eq 'PSGallery' -and $InstallationPolicy -eq 'Trusted' }
            Should -Invoke Set-PSResourceRepository -Times 1 -ParameterFilter { $Name -eq 'PSGallery' -and $Trusted -eq $true }
        }
    }

    It 'Set-PSFixerBaseline trusts PSGallery in both' {
        InModuleScope PSFixer {
            Mock Get-PSRepository { [pscustomobject]@{ Name = 'PSGallery' } }
            Mock Set-PSRepository {}
            Mock Register-PSRepository {}
            Mock Get-PSResourceRepository { [pscustomobject]@{ Name = 'PSGallery'; Trusted = $false } }
            Mock Set-PSResourceRepository {}
            Mock Register-PSResourceRepository {}
            Mock Get-PackageProvider { [pscustomobject]@{ Name = 'NuGet'; Version = [version]'3.0.0.1' } }
            Mock Get-Module { [pscustomobject]@{ Name = 'Microsoft.PowerShell.PSResourceGet' } } -ParameterFilter { $ListAvailable }
            Mock Test-PSFixerBaseline {}

            Set-PSFixerBaseline -Confirm:$false

            Should -Invoke Set-PSRepository -Times 1 -ParameterFilter { $Name -eq 'PSGallery' -and $InstallationPolicy -eq 'Trusted' }
            Should -Invoke Set-PSResourceRepository -Times 1 -ParameterFilter { $Name -eq 'PSGallery' -and $Trusted -eq $true }
        }
    }
}

Describe 'Get-PSFixerEditionModuleDump' {
    It 'still writes and executes its discovery script when the ambient WhatIfPreference is true' {
        # Regression test: a colleague hit "Conversion from JSON failed... Unexpected character T"
        # running Reset-PSFixerEnvironment -TargetEdition Both -WhatIf. Root cause: Set-Content
        # silently no-ops under an inherited $WhatIfPreference, so the temp discovery script never
        # got written, and the exe's "cannot find the file" error text was fed into ConvertFrom-Json.
        # This is a real subprocess call (like the live validation done for this function), not
        # mocked, since the bug was specifically in that Set-Content-then-execute plumbing.
        InModuleScope PSFixer {
            $WhatIfPreference = $true
            try {
                { Get-PSFixerEditionModuleDump -Edition WindowsPowerShell } | Should -Not -Throw
            }
            finally {
                $WhatIfPreference = $false
            }
        }
    }
}

Describe 'Get-PSFixerVersion' {
    It 'returns the version from the module manifest' {
        $manifest = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot '..\PSFixer\PSFixer.psd1')
        Get-PSFixerVersion | Should -Be ([version]$manifest.ModuleVersion)
    }
}

Describe 'Restore-PSFixerSnapshot' {
    BeforeAll {
        $snapshotFile = Join-Path $TestDrive 'inventory-test.json'
        [pscustomobject]@{
            Modules = @(
                [pscustomobject]@{ Name = 'Az.Accounts'; Version = [version]'3.0.4'; Path = 'C:\A\Az.Accounts\3.0.4'; Scope = 'CurrentUser (PS7)' }
                [pscustomobject]@{ Name = 'Az.Advisor'; Version = [version]'2.0.1'; Path = 'C:\A\Az.Advisor\2.0.1'; Scope = 'AllUsers (PS7)' }
            )
        } | ConvertTo-Json -Depth 6 | Set-Content -Path $snapshotFile -Encoding UTF8
    }

    It 'reinstalls only the module+version pairs that are no longer present, using a real [version] (not the deserialized PSCustomObject)' {
        InModuleScope PSFixer -Parameters @{ snapshotFile = $snapshotFile } {
            param($snapshotFile)
            # Az.Accounts 3.0.4 is "still there"; Az.Advisor 2.0.1 is "missing" and must be restored.
            Mock Get-PSFixerModule { [pscustomobject]@{ Name = 'Az.Accounts'; Version = [version]'3.0.4'; Path = 'C:\A\Az.Accounts\3.0.4'; Scope = 'CurrentUser (PS7)' } }
            Mock Install-Module {}

            Restore-PSFixerSnapshot -SnapshotPath $snapshotFile -Confirm:$false

            # Install-Module declares -RequiredVersion as [string], so Pester's mock proxy
            # coerces the [version] we pass into a string during parameter binding - compare as such.
            Should -Invoke Install-Module -Times 1 -ParameterFilter {
                $Name -eq 'Az.Advisor' -and $RequiredVersion -eq '2.0.1' -and $Scope -eq 'AllUsers'
            }
            Should -Invoke Install-Module -Times 0 -ParameterFilter { $Name -eq 'Az.Accounts' }
        }
    }

    It 'does not reinstall anything under -WhatIf' {
        InModuleScope PSFixer -Parameters @{ snapshotFile = $snapshotFile } {
            param($snapshotFile)
            Mock Get-PSFixerModule { }
            Mock Install-Module {}

            Restore-PSFixerSnapshot -SnapshotPath $snapshotFile -WhatIf

            Should -Invoke Install-Module -Times 0
        }
    }

    It 'throws when no snapshot path is given and none exists under TEMP' {
        InModuleScope PSFixer {
            Mock Get-ChildItem { }
            { Restore-PSFixerSnapshot } | Should -Throw '*Geen snapshot gevonden*'
        }
    }
}

Describe 'Update-PSFixerModule' {
    It 'does not contact GitHub under -WhatIf' {
        InModuleScope PSFixer {
            Mock Invoke-RestMethod {}
            Update-PSFixerModule -WhatIf
            Should -Invoke Invoke-RestMethod -Times 0
        }
    }

    It 'downloads the bootstrap script and invokes it when confirmed' {
        InModuleScope PSFixer {
            Mock Invoke-RestMethod { 'param($Repo, $Branch) $script:capturedArgs = @($Repo, $Branch)' }
            Update-PSFixerModule -Confirm:$false
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -eq 'https://raw.githubusercontent.com/WilfredGen3e/psfixer/main/Install-PSFixer.ps1'
            }
        }
    }
}

Describe 'Test-PSFixer' {
    It 'pipes a fresh inventory into Invoke-PSFixerAnalysis and passes all switches through' {
        InModuleScope PSFixer {
            Mock Get-PSFixerInventory { [pscustomobject]@{ PSTypeName = 'PSFixer.Inventory' } }
            Mock Invoke-PSFixerAnalysis { }

            Test-PSFixer -Online -NoReport -NoOpenReport -IncludeUnmanaged

            Should -Invoke Get-PSFixerInventory -Times 1
            Should -Invoke Invoke-PSFixerAnalysis -Times 1 -ParameterFilter {
                $Online -eq $true -and $NoReport -eq $true -and $NoOpenReport -eq $true -and $IncludeUnmanaged -eq $true
            }
        }
    }

    It 'returns the findings Invoke-PSFixerAnalysis produces' {
        InModuleScope PSFixer {
            Mock Get-PSFixerInventory { [pscustomobject]@{ PSTypeName = 'PSFixer.Inventory' } }
            Mock Invoke-PSFixerAnalysis { [pscustomobject]@{ PSTypeName = 'PSFixer.Finding'; Category = 'Repository' } }

            $result = Test-PSFixer -NoReport
            $result.Category | Should -Be 'Repository'
        }
    }
}

Describe 'Repair-PSFixer parameter mode' {
    It 'throws a clear, non-hanging error with no parameters in a non-interactive session' {
        InModuleScope PSFixer {
            Mock Test-PSFixerInteractive { $false }
            Mock Invoke-PSFixerInteractiveMenu { }

            { Repair-PSFixer } | Should -Throw '*interactive session*'
            Should -Invoke Invoke-PSFixerInteractiveMenu -Times 0
        }
    }

    It 'launches the interactive menu with no parameters in an interactive session' {
        InModuleScope PSFixer {
            Mock Test-PSFixerInteractive { $true }
            Mock Invoke-PSFixerInteractiveMenu { }

            Repair-PSFixer

            Should -Invoke Invoke-PSFixerInteractiveMenu -Times 1
        }
    }

    It 'defaults to a full cleanup (Scope=All) when only -WhatIf is given' {
        InModuleScope PSFixer {
            Mock Reset-PSFixerEnvironment { }

            Repair-PSFixer -WhatIf

            Should -Invoke Reset-PSFixerEnvironment -Times 1 -ParameterFilter {
                $Scope -eq 'All' -and $WhatIf -eq $true
            }
        }
    }

    It 'passes -WhatIf through to Reset-PSFixerEnvironment for a scoped cleanup' {
        InModuleScope PSFixer {
            Mock Reset-PSFixerEnvironment { }

            Repair-PSFixer -Scope Modules -WhatIf

            Should -Invoke Reset-PSFixerEnvironment -Times 1 -ParameterFilter {
                $Scope -eq 'Modules' -and $WhatIf -eq $true
            }
        }
    }

    It 'installs a profile without any cleanup when only -Profile is given' {
        InModuleScope PSFixer {
            Mock Reset-PSFixerEnvironment { }
            Mock Install-PSFixerProfile { }

            Repair-PSFixer -Profile M365Admin -TargetEdition PS7 -Confirm:$false

            Should -Invoke Reset-PSFixerEnvironment -Times 0
            Should -Invoke Install-PSFixerProfile -Times 1 -ParameterFilter {
                $Name -eq 'M365Admin' -and $TargetEdition -eq 'PS7'
            }
        }
    }

    It 'runs cleanup and a profile install together when -Scope and -Profile are both given' {
        InModuleScope PSFixer {
            Mock Reset-PSFixerEnvironment { }
            Mock Install-PSFixerProfile { }

            Repair-PSFixer -Scope Modules -Profile M365Admin -Confirm:$false

            Should -Invoke Reset-PSFixerEnvironment -Times 1 -ParameterFilter { $Scope -eq 'Modules' }
            Should -Invoke Install-PSFixerProfile -Times 1 -ParameterFilter { $Name -eq 'M365Admin' }
        }
    }

    It 'also applies the baseline when -Baseline is given' {
        InModuleScope PSFixer {
            Mock Reset-PSFixerEnvironment { }
            Mock Set-PSFixerBaseline { }

            Repair-PSFixer -Baseline -Confirm:$false

            Should -Invoke Reset-PSFixerEnvironment -Times 0
            Should -Invoke Set-PSFixerBaseline -Times 1
        }
    }

    It 'delegates -Rollback to Restore-PSFixerSnapshot' {
        InModuleScope PSFixer {
            Mock Restore-PSFixerSnapshot { }

            Repair-PSFixer -Rollback -SnapshotPath 'C:\snap.json' -WhatIf

            Should -Invoke Restore-PSFixerSnapshot -Times 1 -ParameterFilter {
                $SnapshotPath -eq 'C:\snap.json' -and $WhatIf -eq $true
            }
        }
    }

    It 'rejects combining -Rollback with -Scope' {
        { Repair-PSFixer -Rollback -Scope Modules } | Should -Throw
    }
}

Describe 'Invoke-PSFixerInteractiveMenu' {
    It 'throws a clear error in a non-interactive session' {
        InModuleScope PSFixer {
            Mock Test-PSFixerInteractive { $false }
            { Invoke-PSFixerInteractiveMenu } | Should -Throw '*interactive session*'
        }
    }

    It 'resolves answers via Read-Host and calls Reset-PSFixerEnvironment / Install-PSFixerProfile with the right parameters' {
        InModuleScope PSFixer {
            # $env:TEMP is a Windows-only env var; the final snapshot-path lookup needs *some*
            # value here. On a real Windows host it's already set - this only backfills it for
            # cross-platform test runs (macOS/Linux), it does not change production behavior.
            $originalTemp = $env:TEMP
            if (-not $env:TEMP) { $env:TEMP = [System.IO.Path]::GetTempPath() }

            Mock Test-PSFixerInteractive { $true }

            Mock Get-PSFixerInventory {
                [pscustomobject]@{
                    PSTypeName         = 'PSFixer.Inventory'
                    PowerShellVersions = @(
                        [pscustomobject]@{ Edition = 'Core'; Version = [version]'7.4.0' }
                        [pscustomobject]@{ Edition = 'Desktop'; Version = [version]'5.1.0' }
                    )
                }
            }
            Mock Invoke-PSFixerAnalysis {
                @(
                    [pscustomobject]@{ PSTypeName = 'PSFixer.Finding'; Category = 'DuplicateModule'; Message = 'dup' }
                    [pscustomobject]@{ PSTypeName = 'PSFixer.Finding'; Category = 'Repository'; Message = 'untrusted' }
                )
            }
            Mock Get-PSFixerProfileDefinition {
                @{ TestProfile = [pscustomobject]@{ Description = 'Test profile'; Modules = @() } }
            }
            Mock Reset-PSFixerEnvironment { }
            Mock Install-PSFixerProfile { }
            Mock Get-PSFixerLatestSnapshot { $null }

            # Answers each question based on a unique substring of the (English-default)
            # prompt text, regardless of the exact order Invoke-PSFixerInteractiveMenu asks them in.
            Mock Read-Host { 'Y' } -ParameterFilter { $Prompt -like '*fix*' }
            Mock Read-Host { '3' } -ParameterFilter { $Prompt -like '*Choice*' }
            Mock Read-Host { '1' } -ParameterFilter { $Prompt -like '*install/update a profile*' }
            Mock Read-Host { 'n' } -ParameterFilter { $Prompt -like '*preview*' }
            Mock Read-Host { 'y' } -ParameterFilter { $Prompt -like '*Continue?*' }

            Invoke-PSFixerInteractiveMenu

            Should -Invoke Reset-PSFixerEnvironment -Times 1 -ParameterFilter {
                ($Scope -contains 'Modules') -and ($Scope -contains 'Repositories') -and $TargetEdition -eq 'Both' -and $Confirm -eq $false
            }
            Should -Invoke Install-PSFixerProfile -Times 1 -ParameterFilter {
                $Name -eq 'TestProfile' -and $TargetEdition -eq 'Both' -and $Confirm -eq $false
            }

            $env:TEMP = $originalTemp
        }
    }

    It 'does nothing and does not prompt for confirmation when everything is skipped' {
        InModuleScope PSFixer {
            Mock Test-PSFixerInteractive { $true }
            Mock Get-PSFixerInventory { [pscustomobject]@{ PSTypeName = 'PSFixer.Inventory'; PowerShellVersions = @() } }
            Mock Invoke-PSFixerAnalysis {
                @([pscustomobject]@{ PSTypeName = 'PSFixer.Finding'; Category = 'DuplicateModule'; Message = 'dup' })
            }
            Mock Get-PSFixerProfileDefinition { @{ TestProfile = [pscustomobject]@{ Description = 'Test profile'; Modules = @() } } }
            Mock Reset-PSFixerEnvironment { }
            Mock Install-PSFixerProfile { }

            Mock Read-Host { 'S' } -ParameterFilter { $Prompt -like '*fix*' }
            Mock Read-Host { '' } -ParameterFilter { $Prompt -like '*install/update a profile*' }

            Invoke-PSFixerInteractiveMenu

            Should -Invoke Reset-PSFixerEnvironment -Times 0
            Should -Invoke Install-PSFixerProfile -Times 0
        }
    }

    It 'asks and answers in Dutch once Set-PSFixerLanguage nl is set, and resets to English afterward' {
        InModuleScope PSFixer {
            $originalLanguage = $script:PSFixerLanguage
            $originalTemp = $env:TEMP
            if (-not $env:TEMP) { $env:TEMP = [System.IO.Path]::GetTempPath() }

            try {
                Set-PSFixerLanguage -Language nl

                Mock Test-PSFixerInteractive { $true }
                Mock Get-PSFixerInventory {
                    [pscustomobject]@{ PSTypeName = 'PSFixer.Inventory'; PowerShellVersions = @([pscustomobject]@{ Edition = 'Core'; Version = [version]'7.4.0' }) }
                }
                Mock Invoke-PSFixerAnalysis {
                    @([pscustomobject]@{ PSTypeName = 'PSFixer.Finding'; Category = 'Repository'; Message = 'untrusted' })
                }
                Mock Get-PSFixerProfileDefinition { @{ TestProfile = [pscustomobject]@{ Description = 'Test profile'; Modules = @() } } }
                Mock Reset-PSFixerEnvironment { }
                Mock Install-PSFixerProfile { }
                Mock Get-PSFixerLatestSnapshot { $null }

                # Same scenario as the English test above, but every prompt is now the Dutch string.
                Mock Read-Host { 'J' } -ParameterFilter { $Prompt -like '*oplossen*' }
                Mock Read-Host { '' } -ParameterFilter { $Prompt -like '*profiel installeren*' }
                Mock Read-Host { 'n' } -ParameterFilter { $Prompt -like '*preview*' }
                Mock Read-Host { 'j' } -ParameterFilter { $Prompt -like '*Doorgaan?*' }

                Invoke-PSFixerInteractiveMenu

                Should -Invoke Reset-PSFixerEnvironment -Times 1 -ParameterFilter { $Scope -contains 'Repositories' -and $Confirm -eq $false }
            }
            finally {
                $script:PSFixerLanguage = $originalLanguage
                $env:TEMP = $originalTemp
            }

            Get-PSFixerString -Key 'Menu.Done' | Should -Be 'Done.'
        }
    }
}

Describe 'Get-PSFixerString / Set-PSFixerLanguage' {
    AfterEach {
        InModuleScope PSFixer { $script:PSFixerLanguage = 'en' }
    }

    It 'defaults to English' {
        InModuleScope PSFixer {
            Get-PSFixerString -Key 'Menu.Done' | Should -Be 'Done.'
        }
    }

    It 'switches to Dutch after Set-PSFixerLanguage nl' {
        InModuleScope PSFixer {
            Set-PSFixerLanguage -Language nl
            Get-PSFixerString -Key 'Menu.Done' | Should -Be 'Klaar.'
        }
    }

    It 'rejects an unsupported language' {
        { Set-PSFixerLanguage -Language de } | Should -Throw
    }

    It 'formats placeholders with -FormatArgs' {
        InModuleScope PSFixer {
            Get-PSFixerString -Key 'Snapshot.Restored' -FormatArgs @('Az.Accounts 3.0.0') | Should -Be 'Restored: Az.Accounts 3.0.0'
        }
    }

    It 'still substitutes a single falsy -FormatArgs value instead of leaving a literal {0}' {
        # Regression: PowerShell treats a single-element array as falsy when that one
        # element is itself falsy (empty string, 0, $false) - "if ($FormatArgs)" would
        # wrongly skip formatting for exactly this case (e.g. an empty computer name in
        # the HTML report title). Must check $PSBoundParameters instead.
        InModuleScope PSFixer {
            Get-PSFixerString -Key 'HtmlReport.PageTitle' -FormatArgs @('') | Should -Be 'PSFixer analysis report - '
            Get-PSFixerString -Key 'HtmlReport.ModulesFoundLabel' -FormatArgs @(0) | Should -Be 'Modules found: 0'
        }
    }

    It 'throws a clear error for an unknown key' {
        InModuleScope PSFixer {
            { Get-PSFixerString -Key 'Does.Not.Exist' } | Should -Throw "*Does.Not.Exist*"
        }
    }
}

Describe 'Show-PSFixerCatalog' {
    It 'throws a clear error in a non-interactive session' {
        InModuleScope PSFixer {
            Mock Test-PSFixerInteractive { $false }
            { Show-PSFixerCatalog } | Should -Throw '*interactive session*'
        }
    }

    It 'installs the chosen profile and modules with the given scope/edition' {
        InModuleScope PSFixer {
            Mock Test-PSFixerInteractive { $true }
            Mock Get-PSFixerProfileDefinition { @{ TestProfile = [pscustomobject]@{ Description = 'Test profile'; Modules = @() } } }
            Mock Read-PSFixerProfileSelection { 'TestProfile' }
            Mock Read-PSFixerModuleSelection { @('Pester') }
            Mock Install-PSFixerProfile { }
            Mock Install-PSFixerModule { }

            Show-PSFixerCatalog -TargetEdition PS7 -Confirm:$false

            Should -Invoke Install-PSFixerProfile -Times 1 -ParameterFilter { $Name -eq 'TestProfile' -and $TargetEdition -eq 'PS7' }
            Should -Invoke Install-PSFixerModule -Times 1 -ParameterFilter { $Name -eq @('Pester') -and $TargetEdition -eq 'PS7' }
        }
    }

    It 'does nothing when both the profile and module picks are empty' {
        InModuleScope PSFixer {
            Mock Test-PSFixerInteractive { $true }
            Mock Read-PSFixerProfileSelection { $null }
            Mock Read-PSFixerModuleSelection { @() }
            Mock Install-PSFixerProfile { }
            Mock Install-PSFixerModule { }

            Show-PSFixerCatalog

            Should -Invoke Install-PSFixerProfile -Times 0
            Should -Invoke Install-PSFixerModule -Times 0
        }
    }
}
