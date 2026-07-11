function Get-PSFixerInventory {
    <#
    .SYNOPSIS
        Produces a full inventory of the local PowerShell environment.
    .DESCRIPTION
        Collects installed PowerShell versions, modules, repositories, package
        providers, and the installed PowerShellGet/PSResourceGet versions.
        Returns a single pipeline-friendly object; pass it to
        Invoke-PSFixerAnalysis to detect problems.
    .EXAMPLE
        Get-PSFixerInventory | Format-List
    .EXAMPLE
        Get-PSFixerInventory | Invoke-PSFixerAnalysis
    #>
    [CmdletBinding()]
    [OutputType('PSFixer.Inventory')]
    param()

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # INV-01 / INV-02: installed PowerShell versions
    $psVersions = [System.Collections.Generic.List[pscustomobject]]::new()

    $psVersions.Add([pscustomobject]@{
        Edition = $PSVersionTable.PSEdition
        Version = $PSVersionTable.PSVersion
        Path    = (Get-Process -Id $PID).Path
        IsActiveSession = $true
    })

    if ($IsWindows -or $null -eq $IsWindows) {
        $winPSKey = 'HKLM:\SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine'
        if (Test-Path -Path $winPSKey) {
            $winPS = Get-ItemProperty -Path $winPSKey -ErrorAction SilentlyContinue
            if ($winPS -and $PSVersionTable.PSEdition -ne 'Desktop') {
                $psVersions.Add([pscustomobject]@{
                    Edition         = 'Desktop'
                    Version         = [version]$winPS.PCVersion
                    Path            = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
                    IsActiveSession = $false
                })
            }
        }

        Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\PowerShellCore\InstalledVersions' -ErrorAction SilentlyContinue |
            ForEach-Object {
                $install = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
                if ($install.SemanticVersion -and $install.SemanticVersion -ne $PSVersionTable.PSVersion.ToString()) {
                    $psVersions.Add([pscustomobject]@{
                        Edition         = 'Core'
                        Version         = [version]($install.SemanticVersion -replace '-.*$')
                        Path            = $install.InstallLocation
                        IsActiveSession = $false
                    })
                }
            }
    }

    # INV-03 / INV-04: modules
    $modules = @(Get-PSFixerModule)

    # INV-05: repositories
    $repositories = @(Get-PSFixerRepository)

    # INV-06: package providers
    $packageProviders = @(Get-PackageProvider -ErrorAction SilentlyContinue | ForEach-Object {
        [pscustomobject]@{
            Name    = $_.Name
            Version = $_.Version
        }
    })

    # INV-07: PowerShellGet / PSResourceGet versions
    $getModules = Get-Module -ListAvailable -Name PowerShellGet, Microsoft.PowerShell.PSResourceGet -ErrorAction SilentlyContinue |
        Group-Object -Property Name |
        ForEach-Object {
            [pscustomobject]@{
                Name     = $_.Name
                Versions = @($_.Group.Version | Sort-Object -Descending)
            }
        }

    $stopwatch.Stop()

    [pscustomobject]@{
        PSTypeName           = 'PSFixer.Inventory'
        CollectedAt          = Get-Date
        DurationMs           = $stopwatch.ElapsedMilliseconds
        PowerShellVersions   = $psVersions
        Modules              = $modules
        Repositories         = $repositories
        PackageProviders     = $packageProviders
        PackageManagement    = $getModules
        IsElevated           = Test-PSFixerIsAdmin
    }
}
