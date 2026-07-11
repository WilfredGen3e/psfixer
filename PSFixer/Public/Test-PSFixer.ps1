function Test-PSFixer {
    <#
    .SYNOPSIS
        Diagnose entry point: one call to see "what's wrong".
    .DESCRIPTION
        Combines Get-PSFixerInventory and Invoke-PSFixerAnalysis behind a
        single cmdlet, without needing to build a pipeline yourself. Behavior
        and output are unchanged from those two separate steps: findings are
        still returned to the pipeline, and a self-contained HTML report is
        written under ~\psfixerreports (unless -NoReport), which opens
        automatically in the browser (unless -NoOpenReport).
    .PARAMETER Online
        Also check the gallery for newer versions. Requires internet
        connectivity.
    .PARAMETER NoReport
        Skip writing the HTML report. Findings are still returned to the
        pipeline.
    .PARAMETER NoOpenReport
        Write the HTML report as usual but don't open it automatically in the
        browser. Has no effect when -NoReport is also specified.
    .PARAMETER IncludeUnmanaged
        Also include duplicate/multiple-version findings for modules that
        weren't installed via the package manager (e.g. in-box Windows
        modules). Those can't be removed by Reset-PSFixerEnvironment anyway,
        so they're excluded by default.
    .EXAMPLE
        Test-PSFixer
        Runs a full diagnosis and opens the HTML report.
    .EXAMPLE
        Test-PSFixer -Online -NoOpenReport
        Diagnosis including gallery versions; the report is written but not opened.
    .EXAMPLE
        Test-PSFixer -NoReport | Where-Object Severity -eq Critical
        Only the critical findings, without writing an HTML report.
    #>
    [CmdletBinding()]
    [OutputType('PSFixer.Finding')]
    param(
        [switch]$Online,

        [switch]$NoReport,

        [switch]$NoOpenReport,

        [switch]$IncludeUnmanaged
    )

    Get-PSFixerInventory | Invoke-PSFixerAnalysis @PSBoundParameters
}
