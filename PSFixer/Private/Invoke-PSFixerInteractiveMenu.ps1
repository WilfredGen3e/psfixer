function Invoke-PSFixerInteractiveMenu {
    <#
    .SYNOPSIS
        Walks through the guided menu for Repair-PSFixer with no parameters
        and runs the chosen actions.
    .DESCRIPTION
        Runs a quiet diagnosis (Get-PSFixerInventory | Invoke-PSFixerAnalysis
        -NoReport), asks per found problem category whether to fix it, asks
        which edition(s) and which profile, shows a summary with an optional
        -WhatIf preview, and after confirmation runs
        Reset-PSFixerEnvironment / Install-PSFixerProfile. Meant to be called
        only by Repair-PSFixer, but testable on its own by mocking Read-Host.
        User-facing prompts are in Dutch, matching the rest of this module's
        interactive helpers (Read-PSFixerModuleSelection,
        Read-PSFixerTargetEdition).
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-PSFixerInteractive)) {
        throw 'Repair-PSFixer kan het vragenmenu niet gebruiken in een niet-interactieve sessie. Geef expliciete parameters op (bv. -Scope, -Profile, -WhatIf).'
    }

    # Each findings category maps to exactly one Reset-PSFixerEnvironment -Scope.
    # OutdatedModule (ANA-03, only with -Online, not used here) is deliberately
    # left out: Reset-PSFixerEnvironment doesn't fix that.
    $categoryScope = @{
        DuplicateModule  = 'Modules'
        MultipleVersions = 'Modules'
        LegacyModule     = 'Modules'
        CommandConflict  = 'Modules'
        Repository       = 'Repositories'
        PackageProvider  = 'Providers'
    }

    Write-Host ''
    Write-Host 'Diagnose draaien...' -ForegroundColor Cyan
    $inventory = Get-PSFixerInventory
    $findings = $inventory | Invoke-PSFixerAnalysis -NoReport

    $actionable = @($findings | Where-Object { $categoryScope.ContainsKey($_.Category) })
    $categories = @($actionable | Group-Object -Property Category)

    $selectedCategories = [System.Collections.Generic.List[string]]::new()

    if ($categories.Count -eq 0) {
        Write-Host 'Geen problemen gevonden - er hoeft niets opgeruimd te worden.' -ForegroundColor Green
    }
    else {
        Write-Host ''
        Write-Host 'Ik heb de volgende problemen gevonden:' -ForegroundColor Cyan
        foreach ($category in $categories) {
            Write-Host ("  [{0,2}x] {1} - bv. {2}" -f $category.Count, $category.Name, $category.Group[0].Message)
        }

        $fixChoice = Read-PSFixerHostSafe -Prompt '(J)a voor alles oplossen / (N)ee, per categorie kiezen / (S)la over' -Default 'J'

        switch ($fixChoice.ToUpperInvariant()) {
            'N' {
                foreach ($category in $categories) {
                    $answer = Read-PSFixerHostSafe -Prompt "  $($category.Name) ($($category.Count)x) oplossen? (j/n)" -Default 'J'
                    if ($answer.ToUpperInvariant() -eq 'J') {
                        $selectedCategories.Add($category.Name)
                    }
                }
            }
            'S' {
                # nothing selected
            }
            default {
                foreach ($category in $categories) { $selectedCategories.Add($category.Name) }
            }
        }
    }

    $scopesNeeded = @($selectedCategories | ForEach-Object { $categoryScope[$_] } | Select-Object -Unique)

    # TargetEdition only matters for the Modules scope (Reset-PSFixerEnvironment
    # ignores it for Repositories/Providers) and for a profile install - only then
    # is it worth asking for.
    $targetEdition = $null
    $multipleEditions = @($inventory.PowerShellVersions).Count -gt 1

    if ($scopesNeeded -contains 'Modules') {
        $targetEdition = if ($multipleEditions) { Read-PSFixerTargetEdition } else { Get-PSFixerCurrentEdition }
    }

    Write-Host ''
    $profiles = Get-PSFixerProfileDefinition
    $profileName = Read-PSFixerProfileSelection -Profiles $profiles

    if ($profileName -and -not $targetEdition) {
        $targetEdition = if ($multipleEditions) { Read-PSFixerTargetEdition } else { Get-PSFixerCurrentEdition }
    }

    if ($scopesNeeded.Count -eq 0 -and -not $profileName) {
        Write-Host 'Niets om te doen.' -ForegroundColor Yellow
        return
    }

    $resetParams = @{ Scope = $scopesNeeded }
    if ($targetEdition) { $resetParams['TargetEdition'] = $targetEdition }
    $installParams = @{ Name = $profileName }
    if ($targetEdition) { $installParams['TargetEdition'] = $targetEdition }

    Write-Host ''
    Write-Host 'Dit ga ik doen:' -ForegroundColor Cyan
    if ($scopesNeeded.Count -gt 0) {
        Write-Host "  - Reset-PSFixerEnvironment -Scope $($scopesNeeded -join ',')$(if ($targetEdition) { " -TargetEdition $targetEdition" })"
    }
    if ($profileName) {
        Write-Host "  - Install-PSFixerProfile -Name $profileName$(if ($targetEdition) { " -TargetEdition $targetEdition" })"
    }

    $alreadyConfirmed = $false
    $previewChoice = Read-PSFixerHostSafe -Prompt 'Wil je dit eerst als preview zien (-WhatIf) voordat ik het echt uitvoer? (j/n)' -Default 'N'
    if ($previewChoice.ToUpperInvariant() -eq 'J') {
        if ($scopesNeeded.Count -gt 0) {
            Reset-PSFixerEnvironment @resetParams -WhatIf
        }
        if ($profileName) {
            Install-PSFixerProfile @installParams -WhatIf
        }

        $continueChoice = Read-PSFixerHostSafe -Prompt 'Doorgaan met de echte uitvoering? (j/n)' -Default 'N'
        if ($continueChoice.ToUpperInvariant() -ne 'J') {
            Write-Host 'Geannuleerd.' -ForegroundColor Yellow
            return
        }
        $alreadyConfirmed = $true
    }

    if (-not $alreadyConfirmed) {
        $confirmChoice = Read-PSFixerHostSafe -Prompt 'Doorgaan? (j/n)' -Default 'N'
        if ($confirmChoice.ToUpperInvariant() -ne 'J') {
            Write-Host 'Geannuleerd.' -ForegroundColor Yellow
            return
        }
    }

    # The user already confirmed explicitly above, so -Confirm:$false to avoid
    # asking again per module (unlike Repair-PSFixer's parameter mode, where the
    # underlying cmdlets show their own ShouldProcess prompt).
    if ($scopesNeeded.Count -gt 0) {
        Reset-PSFixerEnvironment @resetParams -Confirm:$false
    }
    if ($profileName) {
        Install-PSFixerProfile @installParams -Confirm:$false
    }

    Write-Host ''
    if ($scopesNeeded.Count -gt 0) {
        $snapshotDir = Join-Path -Path $env:TEMP -ChildPath 'PSFixer'
        $snapshot = Get-PSFixerLatestSnapshot -SnapshotPath $snapshotDir
        if ($snapshot) {
            Write-Host "Snapshot voor rollback: $($snapshot.FullName)" -ForegroundColor Cyan
            Write-Host "Terugdraaien kan met: Restore-PSFixerSnapshot -SnapshotPath '$($snapshot.FullName)' (of Repair-PSFixer -Rollback)"
        }
    }
    Write-Host 'Klaar.' -ForegroundColor Green
}
