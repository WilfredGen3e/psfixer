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
            $html | Should -Match 'Geen bevindingen'
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

Describe 'Install-PSFixerProfile' {
    It 'throws a clear error for an unknown profile name' {
        { Install-PSFixerProfile -Name 'DoesNotExist' -WhatIf } | Should -Throw "*DoesNotExist*"
    }

    It 'installs in-process for the current edition and via the other-edition helper for the other one' {
        InModuleScope PSFixer {
            Mock Get-PSFixerCurrentEdition { 'PS7' }
            Mock Install-Module {}
            Mock Install-PSFixerModuleInEdition {}

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

            Install-PSFixerProfile -Name AzureEngineer -TargetEdition PS7 -Confirm:$false

            Should -Invoke Install-Module -Times 1
            Should -Invoke Install-PSFixerModuleInEdition -Times 0
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
