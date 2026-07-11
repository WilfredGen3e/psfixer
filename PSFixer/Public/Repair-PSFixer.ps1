function Repair-PSFixer {
    <#
    .SYNOPSIS
        Repairs the local PowerShell environment: cleanup, apply the baseline, and/or install a profile.
    .DESCRIPTION
        One entry point for every fix action PSFixer can perform. Without
        parameters (in an interactive session) you're walked through a guided
        menu that determines what needs to happen based on a quick diagnosis.
        With parameters, Repair-PSFixer works non-interactively/scriptably and
        delegates directly to Reset-PSFixerEnvironment, Set-PSFixerBaseline,
        Install-PSFixerProfile, and Restore-PSFixerSnapshot - those cmdlets
        remain usable on their own too. As soon as you pass any parameter
        (even -WhatIf alone), the guided menu is skipped.

        Cleanup (Reset-PSFixerEnvironment) runs by default unless you specify
        -Profile and/or -Baseline without -Scope - in that case it's assumed
        you want only that specific action, not cleanup as well. Pass -Scope
        explicitly to force cleanup alongside -Profile/-Baseline.
    .PARAMETER Scope
        Which part(s) of the environment to clean up: 'All' (default),
        'Modules', 'Repositories', 'Providers'. Passed through to
        Reset-PSFixerEnvironment.
    .PARAMETER TargetEdition
        Which PowerShell edition(s) this applies to: 'PS7',
        'WindowsPowerShell', or 'Both'. Applies to both the cleanup and any
        profile installation. If omitted: asked interactively, or the current
        edition for scripted use.
    .PARAMETER Profile
        Name of a PSFixer profile (e.g. 'M365Admin') to install/update
        alongside (or instead of) the cleanup. Passed through to
        Install-PSFixerProfile.
    .PARAMETER Baseline
        Also applies the PSFixer baseline (Set-PSFixerBaseline) - repository
        trust, package providers, TLS settings.
    .PARAMETER KeepVersion
        Hashtable of ModuleName -> version to keep when cleaning up
        duplicate/old module versions. Only relevant when a cleanup runs.
    .PARAMETER NoImport
        Don't automatically import an installed profile into the current session.
    .PARAMETER Rollback
        Run a rollback instead of a fix: reinstalls modules/versions from the
        most recent (or specified) Reset-PSFixerEnvironment snapshot.
    .PARAMETER SnapshotPath
        Path to a specific snapshot file for -Rollback. If omitted, the most
        recent snapshot under $env:TEMP\PSFixer is used.
    .EXAMPLE
        Repair-PSFixer
        Starts the guided menu (only in an interactive session).
    .EXAMPLE
        Repair-PSFixer -WhatIf
        Shows a preview of a full cleanup (Scope=All) without changing anything.
    .EXAMPLE
        Repair-PSFixer -Scope Modules -TargetEdition Both -Confirm:$false
        Cleans up duplicate/old module versions in both PS7 and Windows PowerShell 5.1, without prompting.
    .EXAMPLE
        Repair-PSFixer -Profile M365Admin -TargetEdition PS7
        Installs only the M365Admin profile in PS7, no cleanup.
    .EXAMPLE
        Repair-PSFixer -Scope All -Baseline -Profile M365Admin -Confirm:$false
        Full cleanup + baseline + profile installation in one call.
    .EXAMPLE
        Repair-PSFixer -Rollback -WhatIf
        Shows which modules/versions would be restored from the latest snapshot.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'Fix')]
    param(
        [Parameter(ParameterSetName = 'Fix')]
        [ValidateSet('All', 'Modules', 'Repositories', 'Providers')]
        [string[]]$Scope,

        [Parameter(ParameterSetName = 'Fix')]
        [ValidateSet('PS7', 'WindowsPowerShell', 'Both')]
        [string]$TargetEdition,

        [Parameter(ParameterSetName = 'Fix')]
        [string]$Profile,

        [Parameter(ParameterSetName = 'Fix')]
        [switch]$Baseline,

        [Parameter(ParameterSetName = 'Fix')]
        [hashtable]$KeepVersion = @{},

        [Parameter(ParameterSetName = 'Fix')]
        [switch]$NoImport,

        [Parameter(ParameterSetName = 'Rollback', Mandatory)]
        [switch]$Rollback,

        [Parameter(ParameterSetName = 'Rollback')]
        [string]$SnapshotPath
    )

    if ($PSBoundParameters.Count -eq 0) {
        if (-not (Test-PSFixerInteractive)) {
            throw 'Repair-PSFixer heeft zonder parameters een interactieve sessie nodig voor het vragenmenu. Geef expliciete parameters op (bv. -Scope, -Profile, -WhatIf) voor non-interactief/scriptgebruik.'
        }
        Invoke-PSFixerInteractiveMenu
        return
    }

    if ($PSCmdlet.ParameterSetName -eq 'Rollback') {
        $restoreParams = @{}
        if ($SnapshotPath) { $restoreParams['SnapshotPath'] = $SnapshotPath }
        Restore-PSFixerSnapshot @restoreParams -WhatIf:$WhatIfPreference -Confirm:$ConfirmPreference
        return
    }

    $runCleanup = $PSBoundParameters.ContainsKey('Scope') -or (-not $Profile -and -not $Baseline)

    if ($runCleanup) {
        $resetParams = @{ Scope = if ($Scope) { $Scope } else { 'All' } }
        if ($TargetEdition) { $resetParams['TargetEdition'] = $TargetEdition }
        if ($KeepVersion.Count) { $resetParams['KeepVersion'] = $KeepVersion }
        Reset-PSFixerEnvironment @resetParams -WhatIf:$WhatIfPreference -Confirm:$ConfirmPreference
    }

    if ($Baseline) {
        Set-PSFixerBaseline -WhatIf:$WhatIfPreference -Confirm:$ConfirmPreference
    }

    if ($Profile) {
        $installParams = @{ Name = $Profile }
        if ($TargetEdition) { $installParams['TargetEdition'] = $TargetEdition }
        if ($NoImport) { $installParams['NoImport'] = $true }
        Install-PSFixerProfile @installParams -WhatIf:$WhatIfPreference -Confirm:$ConfirmPreference
    }
}
