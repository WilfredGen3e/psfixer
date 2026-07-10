# PSFixer

Diagnose, repair, and baseline framework for PowerShell administration workstations. See [`docs/PRD.md`](docs/PRD.md) for the full product requirements.

## Layout

```
PSFixer/
  PSFixer.psd1        module manifest
  PSFixer.psm1         root module (dot-sources Public/Private)
  Public/               exported cmdlets
  Private/              internal helpers
  Data/                 baseline / legacy-module / profile definitions (JSON)
Tests/
  PSFixer.Tests.ps1     Pester 5+ unit tests
docs/
  PRD.md                product requirements document
```

## Cmdlets (v1 scaffold)

| Cmdlet | PRD section |
|---|---|
| `Get-PSFixerInventory` | §5.1 |
| `Get-PSFixerModule` | §5.1 |
| `Get-PSFixerRepository` | §5.1 |
| `Invoke-PSFixerAnalysis` | §5.2 |
| `Reset-PSFixerEnvironment` | §5.3 |
| `Set-PSFixerBaseline` / `Test-PSFixerBaseline` | §5.4 |
| `Install-PSFixerProfile` / `Update-PSFixerProfile` | §5.5 |
| `Restore-PSFixerSnapshot` | HER-06 rollback |

All destructive cmdlets implement `SupportsShouldProcess` — use `-WhatIf` before running for real.

## Install / update on a workstation

No PSGallery/PowerShellGet dependency, no admin rights required — installs to the CurrentUser module path:

```powershell
irm https://raw.githubusercontent.com/WilfredGen3e/psfixer/main/Install-PSFixer.ps1 | iex
```

This always pulls the latest commit on `main`, replaces any existing CurrentUser install, imports the module, and prints the available commands. Re-run the same line any time to update. Check the installed version with `Get-PSFixerVersion`.

Once installed, you can also update from within an already-loaded session — no need to re-paste the `irm | iex` line:

```powershell
Update-PSFixerModule
```

This downloads and re-runs the same `Install-PSFixer.ps1` bootstrap script, so both paths share a single source of truth.

## Try it locally (from a clone)

```powershell
Import-Module .\PSFixer\PSFixer.psd1 -Force

Get-PSFixerInventory | Invoke-PSFixerAnalysis | Format-Table Category, Severity, Message -AutoSize

Reset-PSFixerEnvironment -Scope Modules -WhatIf
Set-PSFixerBaseline -WhatIf
Install-PSFixerProfile -Name M365Admin -WhatIf
```

## HTML report

Every `Invoke-PSFixerAnalysis` run (INV-08) writes a self-contained HTML report to `~\psfixerreports\psfixer-report-<timestamp>.html` — severity tiles (Critical/Warning/Info) plus a plain-language findings table — prints a `file://` link to it, and opens it in the default browser. Use `-NoOpenReport` to skip the browser launch, or `-NoReport` to skip report generation entirely (findings are still returned to the pipeline either way).

## Rollback

`Reset-PSFixerEnvironment` writes a full inventory snapshot to `$env:TEMP\PSFixer\inventory-<timestamp>.json` before touching anything. If a cleanup turns out to be wrong, `Restore-PSFixerSnapshot` reinstalls any module+version pair from that snapshot that is no longer present (requires PSGallery connectivity):

```powershell
Restore-PSFixerSnapshot -WhatIf
Restore-PSFixerSnapshot                                 # uses the most recent snapshot under $env:TEMP\PSFixer
Restore-PSFixerSnapshot -SnapshotPath 'C:\...\inventory-20260710-113622.json'
```

## Tests

Requires Pester 5+ (`Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser -Force`):

```powershell
Invoke-Pester -Path .\Tests\PSFixer.Tests.ps1
```

## Status

Early scaffold. `Get-PSFixerInventory`, `Get-PSFixerModule`, `Get-PSFixerRepository`, and `Invoke-PSFixerAnalysis` are functionally complete against real environments. `Reset-PSFixerEnvironment`, `Set-PSFixerBaseline`, and `Install-PSFixerProfile` implement the core flows from the PRD but have not yet been run destructively end-to-end (only smoke-tested via `-WhatIf`).

NFR-06 (<60s inventory) verified: 4.2s in a fresh session on a workstation with ~275 installed modules. An earlier one-off ~158s reading turned out to be a cold-cache/antivirus first-scan cost (Windows Defender scanning each module file on first touch), not a defect — later runs on the same machine were consistently in the single-digit seconds.
