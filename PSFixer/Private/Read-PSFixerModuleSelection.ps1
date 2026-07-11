function Read-PSFixerModuleSelection {
    <#
    .SYNOPSIS
        Prints a numbered, categorized module catalog and asks the user to pick
        one or more entries. Returns the selected module names.
    .PARAMETER Catalog
        Ordered dictionary of category -> [{Name, Description}], e.g. from
        Get-PSFixerPopularModuleCatalog.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        $Catalog
    )

    $indexed = [System.Collections.Generic.List[pscustomobject]]::new()

    Write-Host ''
    Write-Host (Get-PSFixerString -Key 'ModuleSelection.Header') -ForegroundColor Cyan
    foreach ($category in $Catalog.Keys) {
        Write-Host ''
        Write-Host $category -ForegroundColor Yellow
        foreach ($item in $Catalog[$category]) {
            $entry = [pscustomobject]@{ Index = $indexed.Count + 1; Name = $item.Name; Description = $item.Description }
            $indexed.Add($entry)
            Write-Host ('  [{0,2}] {1} - {2}' -f $entry.Index, $entry.Name, $entry.Description)
        }
    }

    Write-Host ''

    try {
        $selection = Read-Host -Prompt (Get-PSFixerString -Key 'ModuleSelection.Prompt')
    }
    catch {
        # Read-Host can still fail even when Test-PSFixerInteractive says yes (host
        # quirks) - fall back to "nothing selected" rather than crashing.
        Write-Verbose "Could not interactively ask for a module selection: $_. No modules selected."
        return @()
    }

    $selectedIndexes = @($selection -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ })
    return @($indexed | Where-Object { $selectedIndexes -contains $_.Index } | Select-Object -ExpandProperty Name)
}
