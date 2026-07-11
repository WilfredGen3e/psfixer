function Read-PSFixerProfileSelection {
    <#
    .SYNOPSIS
        Prints a numbered list of available PSFixer profiles and asks the
        user to pick at most one (Install-PSFixerProfile -Name is singular).
        Returns the selected profile name, or $null if none was picked.
    .PARAMETER Profiles
        Hashtable of profile name -> definition (Description, Modules), e.g.
        from Get-PSFixerProfileDefinition.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Profiles
    )

    $indexed = [System.Collections.Generic.List[pscustomobject]]::new()

    Write-Host 'Beschikbare profielen:' -ForegroundColor Cyan
    # Hashtable key order isn't guaranteed stable (Get-PSFixerProfileDefinition
    # doesn't return an [ordered] hashtable) - sort explicitly so the numbering
    # stays consistent across calls.
    foreach ($name in ($Profiles.Keys | Sort-Object)) {
        $entry = [pscustomobject]@{ Index = $indexed.Count + 1; Name = $name; Description = $Profiles[$name].Description }
        $indexed.Add($entry)
        Write-Host ('  [{0,2}] {1} - {2}' -f $entry.Index, $entry.Name, $entry.Description)
    }

    try {
        $selection = Read-Host -Prompt 'Wil je een profiel installeren/updaten? Typ het nummer, of laat leeg om over te slaan'
    }
    catch {
        # Read-Host can still fail even when Test-PSFixerInteractive says yes (host
        # quirks) - fall back to "nothing selected" rather than crashing.
        Write-Verbose "Kon niet interactief om een profielkeuze vragen: $_. Geen profiel geselecteerd."
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($selection) -or $selection -notmatch '^\d+$') {
        return $null
    }

    $match = $indexed | Where-Object { $_.Index -eq [int]$selection }
    if (-not $match) {
        return $null
    }

    return $match.Name
}
