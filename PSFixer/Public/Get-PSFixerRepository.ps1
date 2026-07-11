function Get-PSFixerRepository {
    <#
    .SYNOPSIS
        Inventories registered PowerShell repositories and their trust status.
    .DESCRIPTION
        Reports repositories from both PowerShellGet (Get-PSRepository) and, when
        available, PSResourceGet (Get-PSResourceRepository).
    #>
    [CmdletBinding()]
    [OutputType('PSFixer.RepositoryInfo')]
    param()

    if (Get-Command -Name Get-PSResourceRepository -ErrorAction SilentlyContinue) {
        foreach ($repo in Get-PSResourceRepository) {
            [pscustomobject]@{
                PSTypeName = 'PSFixer.RepositoryInfo'
                Name       = $repo.Name
                Uri        = $repo.Uri
                Trusted    = $repo.Trusted
                Priority   = $repo.Priority
                Provider   = 'PSResourceGet'
            }
        }
        return
    }

    if (Get-Command -Name Get-PSRepository -ErrorAction SilentlyContinue) {
        foreach ($repo in Get-PSRepository) {
            [pscustomobject]@{
                PSTypeName = 'PSFixer.RepositoryInfo'
                Name       = $repo.Name
                Uri        = $repo.SourceLocation
                Trusted    = ($repo.InstallationPolicy -eq 'Trusted')
                Priority   = $null
                Provider   = 'PowerShellGet'
            }
        }
    }
}
