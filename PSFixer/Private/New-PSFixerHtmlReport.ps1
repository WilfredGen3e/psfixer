function New-PSFixerHtmlReport {
    <#
    .SYNOPSIS
        Builds a self-contained HTML analysis report.
    .DESCRIPTION
        Returns the report as an HTML string; the caller decides where to write it.
        No external assets (fonts/scripts/images) so it opens standalone via file://.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Inventory,

        [AllowEmptyCollection()]
        [pscustomobject[]]$Findings = @()
    )

    function ConvertTo-PSFixerHtmlSafeText {
        param([string]$Text)
        if ($null -eq $Text) { return '' }
        [System.Net.WebUtility]::HtmlEncode($Text)
    }

    $severityIcon = @{ Critical = '&#9940;'; Warning = '&#9888;'; Info = '&#8505;' }
    $severityOrder = @{ Critical = 0; Warning = 1; Info = 2 }

    $generated = Get-Date
    $version = $MyInvocation.MyCommand.Module.Version
    $critical = @($Findings | Where-Object Severity -eq 'Critical')
    $warning = @($Findings | Where-Object Severity -eq 'Warning')
    $info = @($Findings | Where-Object Severity -eq 'Info')

    $sortedFindings = @($Findings | Sort-Object { $severityOrder[$_.Severity] }, Category)

    $rows = if ($sortedFindings.Count -eq 0) {
        "<tr><td colspan=`"4`" class=`"empty-state`">$(Get-PSFixerString -Key 'HtmlReport.EmptyState')</td></tr>"
    }
    else {
        ($sortedFindings | ForEach-Object {
            $sevClass = $_.Severity.ToLower()
            $icon = $severityIcon[$_.Severity]
            @"
<tr>
  <td><span class="badge badge-$sevClass">$icon $(ConvertTo-PSFixerHtmlSafeText $_.Severity)</span></td>
  <td>$(ConvertTo-PSFixerHtmlSafeText $_.Category)</td>
  <td>$(ConvertTo-PSFixerHtmlSafeText $_.Message)</td>
  <td>$(ConvertTo-PSFixerHtmlSafeText $_.Recommendation)</td>
</tr>
"@
        }) -join "`n"
    }

    $moduleCount = @($Inventory.Modules | Select-Object -ExpandProperty Name -Unique).Count
    $repoCount = @($Inventory.Repositories).Count
    $psVersionCount = @($Inventory.PowerShellVersions).Count
    $computerName = ConvertTo-PSFixerHtmlSafeText $env:COMPUTERNAME

    $langCode = Get-PSFixerString -Key 'HtmlReport.LangCode'
    $pageTitle = Get-PSFixerString -Key 'HtmlReport.PageTitle' -FormatArgs @($computerName)
    $heading = Get-PSFixerString -Key 'HtmlReport.Heading'
    $generatedOn = Get-PSFixerString -Key 'HtmlReport.GeneratedOn' -FormatArgs @($generated.ToString('dd-MM-yyyy HH:mm'))
    $versionLabel = Get-PSFixerString -Key 'HtmlReport.VersionLabel' -FormatArgs @((ConvertTo-PSFixerHtmlSafeText $version))
    $modulesFoundLabel = Get-PSFixerString -Key 'HtmlReport.ModulesFoundLabel' -FormatArgs @($moduleCount)
    $repositoriesLabel = Get-PSFixerString -Key 'HtmlReport.RepositoriesLabel' -FormatArgs @($repoCount)
    $psVersionsLabel = Get-PSFixerString -Key 'HtmlReport.PowerShellVersionsLabel' -FormatArgs @($psVersionCount)
    $columnSeverity = Get-PSFixerString -Key 'HtmlReport.ColumnSeverity'
    $columnCategory = Get-PSFixerString -Key 'HtmlReport.ColumnCategory'
    $columnMessage = Get-PSFixerString -Key 'HtmlReport.ColumnMessage'
    $columnRecommendation = Get-PSFixerString -Key 'HtmlReport.ColumnRecommendation'
    $footer = Get-PSFixerString -Key 'HtmlReport.Footer' -FormatArgs @((ConvertTo-PSFixerHtmlSafeText $version), $generated.ToString('o'))

    @"
<!doctype html>
<html lang="$langCode">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$pageTitle</title>
<style>
  :root {
    --surface-1: #fcfcfb;
    --page: #f9f9f7;
    --text-primary: #0b0b0b;
    --text-secondary: #52514e;
    --text-muted: #898781;
    --gridline: #e1e0d9;
    --border: rgba(11,11,11,0.10);
    --row-hover: rgba(11,11,11,0.03);
    --info: #2a78d6;
    --warning: #fab219;
    --warning-ink: #8a5a00;
    --critical: #d03b3b;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --surface-1: #1a1a19;
      --page: #0d0d0d;
      --text-primary: #ffffff;
      --text-secondary: #c3c2b7;
      --text-muted: #898781;
      --gridline: #2c2c2a;
      --border: rgba(255,255,255,0.10);
      --row-hover: rgba(255,255,255,0.04);
      --info: #3987e5;
      --warning: #fab219;
      --warning-ink: #ffd680;
      --critical: #e66767;
    }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    background: var(--page);
    color: var(--text-primary);
  }
  .wrap { max-width: 980px; margin: 0 auto; padding: 32px 20px 64px; }
  header h1 { font-size: 1.5rem; margin: 0 0 4px; }
  header p { margin: 0; color: var(--text-secondary); font-size: 0.9rem; }
  .meta { display: flex; gap: 20px; flex-wrap: wrap; margin: 16px 0 32px; color: var(--text-muted); font-size: 0.85rem; }
  .tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 12px; margin-bottom: 32px; }
  .tile {
    background: var(--surface-1);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 16px 18px;
    border-top: 3px solid var(--tile-color, var(--gridline));
  }
  .tile .value { font-size: 2rem; font-weight: 600; }
  .tile .label { color: var(--text-secondary); font-size: 0.85rem; margin-top: 2px; }
  .tile.critical { --tile-color: var(--critical); }
  .tile.warning { --tile-color: var(--warning); }
  .tile.info { --tile-color: var(--info); }
  table { width: 100%; border-collapse: collapse; background: var(--surface-1); border: 1px solid var(--border); border-radius: 10px; overflow: hidden; }
  th, td { text-align: left; padding: 10px 14px; border-bottom: 1px solid var(--gridline); font-size: 0.88rem; vertical-align: top; }
  th { color: var(--text-muted); font-weight: 600; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.03em; }
  tr:last-child td { border-bottom: none; }
  tr:hover td { background: var(--row-hover); }
  .badge { display: inline-flex; align-items: center; gap: 5px; padding: 3px 9px; border-radius: 999px; font-size: 0.78rem; font-weight: 600; white-space: nowrap; }
  .badge-critical { background: color-mix(in srgb, var(--critical) 16%, transparent); color: var(--critical); }
  .badge-warning { background: color-mix(in srgb, var(--warning) 24%, transparent); color: var(--warning-ink); }
  .badge-info { background: color-mix(in srgb, var(--info) 16%, transparent); color: var(--info); }
  .empty-state { text-align: center; padding: 32px; color: var(--text-secondary); }
  footer { margin-top: 24px; color: var(--text-muted); font-size: 0.78rem; }
</style>
</head>
<body>
<div class="wrap">
  <header>
    <h1>$heading</h1>
    <p>$computerName &middot; $generatedOn</p>
  </header>
  <div class="meta">
    <span>$versionLabel</span>
    <span>$modulesFoundLabel</span>
    <span>$repositoriesLabel</span>
    <span>$psVersionsLabel</span>
  </div>
  <div class="tiles">
    <div class="tile critical"><div class="value">$($critical.Count)</div><div class="label">Critical</div></div>
    <div class="tile warning"><div class="value">$($warning.Count)</div><div class="label">Warning</div></div>
    <div class="tile info"><div class="value">$($info.Count)</div><div class="label">Info</div></div>
  </div>
  <table>
    <thead>
      <tr><th>$columnSeverity</th><th>$columnCategory</th><th>$columnMessage</th><th>$columnRecommendation</th></tr>
    </thead>
    <tbody>
      $rows
    </tbody>
  </table>
  <footer>$footer</footer>
</div>
</body>
</html>
"@
}
