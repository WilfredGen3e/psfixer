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
        User-facing prompts go through Get-PSFixerString, so they follow
        whatever language Set-PSFixerLanguage last set (default English).
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-PSFixerInteractive)) {
        throw (Get-PSFixerString -Key 'Menu.NonInteractiveError')
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

    $yes = Get-PSFixerString -Key 'Common.Yes'
    $no = Get-PSFixerString -Key 'Common.No'
    $skip = Get-PSFixerString -Key 'Common.Skip'

    Write-Host ''
    Write-Host (Get-PSFixerString -Key 'Menu.RunningDiagnosis') -ForegroundColor Cyan
    $inventory = Get-PSFixerInventory
    $findings = $inventory | Invoke-PSFixerAnalysis -NoReport

    $actionable = @($findings | Where-Object { $categoryScope.ContainsKey($_.Category) })
    $categories = @($actionable | Group-Object -Property Category)

    $selectedCategories = [System.Collections.Generic.List[string]]::new()

    if ($categories.Count -eq 0) {
        Write-Host (Get-PSFixerString -Key 'Menu.NoProblemsFound') -ForegroundColor Green
    }
    else {
        Write-Host ''
        Write-Host (Get-PSFixerString -Key 'Menu.ProblemsFoundHeader') -ForegroundColor Cyan
        foreach ($category in $categories) {
            Write-Host (Get-PSFixerString -Key 'Menu.ProblemSummaryLine' -FormatArgs @($category.Count, $category.Name, $category.Group[0].Message))
        }

        $fixChoice = Read-PSFixerHostSafe -Prompt (Get-PSFixerString -Key 'Menu.FixAllPrompt') -Default $yes

        switch ($fixChoice.ToUpperInvariant()) {
            $no {
                foreach ($category in $categories) {
                    $answer = Read-PSFixerHostSafe -Prompt (Get-PSFixerString -Key 'Menu.FixCategoryPrompt' -FormatArgs @($category.Name, $category.Count)) -Default $yes
                    if ($answer.ToUpperInvariant() -eq $yes) {
                        $selectedCategories.Add($category.Name)
                    }
                }
            }
            $skip {
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
        Write-Host (Get-PSFixerString -Key 'Menu.NothingToDo') -ForegroundColor Yellow
        return
    }

    $resetParams = @{ Scope = $scopesNeeded }
    if ($targetEdition) { $resetParams['TargetEdition'] = $targetEdition }
    $installParams = @{ Name = $profileName }
    if ($targetEdition) { $installParams['TargetEdition'] = $targetEdition }

    Write-Host ''
    Write-Host (Get-PSFixerString -Key 'Menu.WillDoHeader') -ForegroundColor Cyan
    if ($scopesNeeded.Count -gt 0) {
        Write-Host "  - Reset-PSFixerEnvironment -Scope $($scopesNeeded -join ',')$(if ($targetEdition) { " -TargetEdition $targetEdition" })"
    }
    if ($profileName) {
        Write-Host "  - Install-PSFixerProfile -Name $profileName$(if ($targetEdition) { " -TargetEdition $targetEdition" })"
    }

    $alreadyConfirmed = $false
    $previewChoice = Read-PSFixerHostSafe -Prompt (Get-PSFixerString -Key 'Menu.PreviewPrompt') -Default $no
    if ($previewChoice.ToUpperInvariant() -eq $yes) {
        if ($scopesNeeded.Count -gt 0) {
            Reset-PSFixerEnvironment @resetParams -WhatIf
        }
        if ($profileName) {
            Install-PSFixerProfile @installParams -WhatIf
        }

        $continueChoice = Read-PSFixerHostSafe -Prompt (Get-PSFixerString -Key 'Menu.ContinueForRealPrompt') -Default $no
        if ($continueChoice.ToUpperInvariant() -ne $yes) {
            Write-Host (Get-PSFixerString -Key 'Menu.Cancelled') -ForegroundColor Yellow
            return
        }
        $alreadyConfirmed = $true
    }

    if (-not $alreadyConfirmed) {
        $confirmChoice = Read-PSFixerHostSafe -Prompt (Get-PSFixerString -Key 'Menu.ContinuePrompt') -Default $no
        if ($confirmChoice.ToUpperInvariant() -ne $yes) {
            Write-Host (Get-PSFixerString -Key 'Menu.Cancelled') -ForegroundColor Yellow
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
            Write-Host (Get-PSFixerString -Key 'Menu.SnapshotForRollback' -FormatArgs @($snapshot.FullName)) -ForegroundColor Cyan
            Write-Host (Get-PSFixerString -Key 'Menu.RollbackHint' -FormatArgs @($snapshot.FullName))
        }
    }
    Write-Host (Get-PSFixerString -Key 'Menu.Done') -ForegroundColor Green
}
