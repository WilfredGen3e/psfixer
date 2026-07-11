# PSFixer

Diagnose, repair, and baseline framework for PowerShell administration workstations.

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

## Quick start

Three commands are enough to get going — you never need to memorize the pipeline steps or the granular cmdlets below to diagnose or fix a workstation:

| Command | Alias | Purpose |
|---|---|---|
| `Test-PSFixer` | `psdiag` | **What's wrong?** Runs the full diagnosis (inventory + analysis), opens the HTML report. |
| `Repair-PSFixer` | `psfix` | **Fix it.** No parameters + interactive session → a guided menu. With parameters → scriptable. |
| `Show-PSFixerCatalog` | `pscat` | **What can I add?** Shows the profile/module picker and installs what you choose. |

```powershell
Test-PSFixer            # or: psdiag
Repair-PSFixer          # or: psfix   - guided menu in an interactive session
Show-PSFixerCatalog     # or: pscat
```

### Example: `Repair-PSFixer` with no parameters

```
PS> Repair-PSFixer

Diagnose draaien...

Ik heb de volgende problemen gevonden:
  [ 3x] DuplicateModule - bv. Module 'Az.Accounts' is installed in 3 locations.
  [ 1x] Repository - bv. PSGallery is registered but not Trusted, which will prompt on every install.
(J)a voor alles oplossen / (N)ee, per categorie kiezen / (S)la over [J]: J

In welke PowerShell-editie wil je dit uitvoeren?
  [1] Alleen PowerShell 7 (aanbevolen)
  [2] Alleen Windows PowerShell 5.1
  [3] Beide
Keuze [1]: 1

Beschikbare profielen:
  [ 1] AzureEngineer - Az module family for Azure infrastructure engineers.
  [ 2] M365Admin - Modules for day-to-day Microsoft 365 administration.
Wil je een profiel installeren/updaten? Typ het nummer, of laat leeg om over te slaan: 2

Dit ga ik doen:
  - Reset-PSFixerEnvironment -Scope Modules,Repositories -TargetEdition PS7
  - Install-PSFixerProfile -Name M365Admin -TargetEdition PS7
Wil je dit eerst als preview zien (-WhatIf) voordat ik het echt uitvoer? (j/n) [N]: n
Doorgaan? (j/n) [N]: j

Snapshot voor rollback: C:\Users\jdoe\AppData\Local\Temp\PSFixer\inventory-20260711-072519.json
Terugdraaien kan met: Restore-PSFixerSnapshot -SnapshotPath '...' (of Repair-PSFixer -Rollback)
Klaar.
```

The menu only asks about what's actually relevant — no edition question if only one PowerShell edition is installed, no "clean up legacy modules" question if none were found. Outside an interactive session (CI, scheduled tasks), `Repair-PSFixer` without parameters fails fast with a clear error instead of hanging on a prompt.

For scripted/non-interactive use, skip the menu entirely by passing any parameter:

```powershell
Repair-PSFixer -Scope Modules -TargetEdition Both -Confirm:$false
Repair-PSFixer -Profile M365Admin -TargetEdition PS7          # profile only, no cleanup
Repair-PSFixer -Scope All -Baseline -Profile M365Admin -Confirm:$false
Repair-PSFixer -Rollback -WhatIf
```

See `Get-Help Repair-PSFixer -Full` for every parameter and example.

## Advanced / scripted use

The three Quick start commands are thin wrappers — every cmdlet they call remains available on its own for targeted or scripted use:

| Cmdlet | Purpose |
|---|---|
| `Get-PSFixerInventory` | Collect PS versions, modules, repositories, providers as one pipeline-friendly object |
| `Get-PSFixerModule` | Inventory of installed modules across all locations |
| `Get-PSFixerRepository` | Inventory of registered repositories and their trust status |
| `Invoke-PSFixerAnalysis` | Detect problems in an inventory, with severity and recommendation |
| `Reset-PSFixerEnvironment` | Clean up modules/repositories/providers |
| `Set-PSFixerBaseline` / `Test-PSFixerBaseline` | Apply / check compliance against the recommended baseline |
| `Install-PSFixerProfile` / `Update-PSFixerProfile` | Install/update the modules for a named profile |
| `Install-PSFixerModule` | Ad-hoc module picker (see below) |
| `Restore-PSFixerSnapshot` | Roll back a cleanup using its pre-change snapshot |

All destructive cmdlets implement `SupportsShouldProcess` — use `-WhatIf` before running for real.

```powershell
Import-Module .\PSFixer\PSFixer.psd1 -Force

Get-PSFixerInventory | Invoke-PSFixerAnalysis | Format-Table Category, Severity, Message -AutoSize

Reset-PSFixerEnvironment -Scope Modules -WhatIf
Set-PSFixerBaseline -WhatIf
Install-PSFixerProfile -Name M365Admin -WhatIf
```

`Test-PSFixer` is exactly `Get-PSFixerInventory | Invoke-PSFixerAnalysis` behind one call — reach for the pipeline directly whenever you need a custom inventory object or want to compose it differently.

## HTML report

Every `Test-PSFixer` / `Invoke-PSFixerAnalysis` run writes a self-contained HTML report to `~\psfixerreports\psfixer-report-<timestamp>.html` — severity tiles (Critical/Warning/Info) plus a plain-language findings table — prints a `file://` link to it, and opens it in the default browser. Use `-NoOpenReport` to skip the browser launch, or `-NoReport` to skip report generation entirely (findings are still returned to the pipeline either way).

## Rollback

`Reset-PSFixerEnvironment` (and therefore `Repair-PSFixer`) writes a full inventory snapshot to `$env:TEMP\PSFixer\inventory-<timestamp>.json` before touching anything. If a cleanup turns out to be wrong, `Restore-PSFixerSnapshot` reinstalls any module+version pair from that snapshot that is no longer present (requires PSGallery connectivity):

```powershell
Restore-PSFixerSnapshot -WhatIf
Restore-PSFixerSnapshot                                 # uses the most recent snapshot under $env:TEMP\PSFixer
Restore-PSFixerSnapshot -SnapshotPath 'C:\...\inventory-20260710-113622.json'

Repair-PSFixer -Rollback -WhatIf                         # equivalent, via the Quick start entry point
```

## Tests

Requires Pester 5+ (`Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser -Force`):

```powershell
Invoke-Pester -Path .\Tests\PSFixer.Tests.ps1
```

## Status

Core v1.0 flows have been run for real (not just `-WhatIf`) against a live, genuinely cluttered workstation and validated:

- `Reset-PSFixerEnvironment -Scope Modules` removed ~80 duplicate/old Az module versions; all key modules (Az.Accounts, Az.Resources, Az.KeyVault, Microsoft.Graph.Authentication, ExchangeOnlineManagement, PnP.PowerShell) still imported correctly afterward at their kept (newest) version.
- `Install-PSFixerProfile -Name M365Admin` really installed/updated Microsoft.Graph, ExchangeOnlineManagement, MicrosoftTeams, and Az.Accounts to current versions.
- Idempotent: a second `-Scope Modules`/`-Scope Providers`/`-Scope Repositories` run, and a second `Set-PSFixerBaseline` run, both found nothing left to change.
- Inventory performance verified: 4.2s in a fresh session on a workstation with ~275 installed modules (well under the 60s target). An earlier one-off ~158s reading turned out to be a cold-cache/antivirus first-scan cost (Windows Defender scanning each module file on first touch), not a defect.
- `Connect-MgGraph`, `Connect-ExchangeOnline`, `Connect-AzAccount` are all present and resolvable after `Install-PSFixerProfile M365Admin`. Actually completing an interactive sign-in (browser/MFA) has to be done by a human, not automatable — not yet exercised end-to-end.

Two real bugs were found and fixed by this testing:

- `-Scope Providers` (and `Set-PSFixerBaseline`) used to unconditionally try to reinstall NuGet at a fixed old minimum version even when a newer one was already present, which could fail if that exact old version was no longer resolvable from the provider catalog. Both now check the currently installed version first and skip if it already satisfies the minimum.
- `Reset-PSFixerEnvironment` could log a module version as "Removed" when it wasn't: `Uninstall-Module`/`Uninstall-PSResource` report failure to remove an in-box Windows module (e.g. the Pester 3.4.0 that ships with Windows PowerShell) via a non-terminating warning, not an exception, so the original `try/catch` missed it. The cmdlet now verifies the file is actually gone before logging success.

Known limitation: modules that ship in-box with Windows (Pester 3.4.0, PackageManagement) cannot be removed via the package manager at all — PSFixer now reports this as a failure rather than silently pretending to succeed, but doesn't attempt a filesystem-level force-delete (would need elevation and risks touching a protected OS component).

**In-box modules are filtered out of findings by default.** `Get-PSFixerModule` marks every entry `Managed` — `$true` if it shows up in `Get-InstalledPSResource`/`Get-InstalledModule` (i.e. was actually installed via the package manager), `$false` if it's just something Windows ships (in-box Pester, PackageManagement, etc.). `Invoke-PSFixerAnalysis`'s `DuplicateModule` and `MultipleVersions` findings only consider `Managed` entries by default, since unmanaged ones can't be acted on anyway — pass `-IncludeUnmanaged` to see them. `Reset-PSFixerEnvironment -Scope Modules` does the same: it no longer attempts to touch unmanaged entries at all. Real-world result on a validated workstation: 17 findings → 0 after cleanup, with the 3 structurally-unfixable in-box duplicates still visible via `-IncludeUnmanaged` but no longer cluttering the default report.

## Windows PowerShell 5.1 vs. PowerShell 7

`Install-Module -Scope CurrentUser` always lands in whichever edition's own personal module path you ran it from — PS7's `Documents\PowerShell\Modules` and Windows PowerShell 5.1's `Documents\WindowsPowerShell\Modules` never share modules. So a workstation can genuinely have Az/Graph/Exchange fully set up in PS7 and nothing in Windows PowerShell 5.1, or vice versa — that's expected PowerShell behavior, not something `Get-PSFixerInventory` alone can fix (it only ever sees the edition it's currently running in).

`Repair-PSFixer`, `Install-PSFixerProfile`, `Show-PSFixerCatalog`/`Install-PSFixerModule`, and `Reset-PSFixerEnvironment -Scope Modules` all take a `-TargetEdition` parameter (`PS7`, `WindowsPowerShell`, or `Both`). If omitted in an interactive session, you're prompted to choose. Targeting the "other" edition genuinely spawns that edition's own `pwsh.exe`/`powershell.exe` to run the install/uninstall there — it never edits `$env:PSModulePath` as a workaround — and always defaults to `CurrentUser` scope, so no admin rights are required either way:

```powershell
Install-PSFixerProfile -Name M365Admin -TargetEdition Both -Confirm:$false
Reset-PSFixerEnvironment -Scope Modules -TargetEdition WindowsPowerShell -WhatIf
```

Validated live: `Install-PSFixerModuleInEdition` installed `Az.Accounts` into Windows PowerShell 5.1 from a PS7 session (confirmed via a separate `powershell.exe` check before/after), and `Get-PSFixerEditionModuleDump` correctly read Windows PowerShell 5.1's own 99-module inventory, including the same `Managed` classification, from within a PS7 session.

**Fixed:** `Reset-PSFixerEnvironment -Scope Modules -TargetEdition Both -WhatIf` (or `-TargetEdition WindowsPowerShell -WhatIf`) used to crash with `Conversion from JSON failed... Unexpected character T`. Root cause: `Get-PSFixerEditionModuleDump`'s temp discovery script is written via `Set-Content`, which silently no-ops under an ambient `$WhatIfPreference` inherited from the caller — the file never got created, then the code tried to execute it anyway and fed the resulting "file not found" error text into `ConvertFrom-Json`. That helper is pure discovery (it's what `-WhatIf` needs in order to preview anything), not the destructive action itself, so its file I/O now explicitly runs with `-WhatIf:$false` regardless of the caller's preview mode.

## Ad-hoc module install: `Install-PSFixerModule` / `Show-PSFixerCatalog`

`Show-PSFixerCatalog` (Quick start, above) is the friendly front door: it shows both the available named profiles and the categorized module checklist in one menu, and installs whatever you pick. `Install-PSFixerModule` is the underlying cmdlet it (and `Install-PSFixerProfile`) delegates to, and remains directly usable for scripting — a categorized, interactive checklist (`Data/PopularModules.json`, override with `-CatalogPath`) instead of typing exact module names:

```powershell
Install-PSFixerModule                                                   # shows the picker, asks per-module version (blank = latest)
Install-PSFixerModule -Name Az.Accounts, Pester -TargetEdition Both     # skip the picker, install specific modules
Install-PSFixerModule -Name Pester -Version @{ Pester = '5.5.0' }       # pin an exact version, no prompt
```

Same `-TargetEdition`/`-Scope` support as `Install-PSFixerProfile`. Modules installed for the currently running edition are `Import-Module`'d right away (`-NoImport` to skip) — `Install-PSFixerProfile` does the same for consistency, so either way you can start using a module immediately after install without a separate `Import-Module`.

This surfaced a real bug in the interactivity detection used by the edition/module prompts: `[Environment]::UserInteractive` reflects whether the OS session is a desktop session, not whether *this specific PowerShell process* was started with `-NonInteractive` — which is what actually makes `Read-Host` throw ("PowerShell is in NonInteractive mode"). `Test-PSFixerInteractive` now also checks `[Environment]::GetCommandLineArgs()` for `-NonInteractive`/`-noni`, and every `Read-Host` call in the interactive-prompt helpers is wrapped so a failure falls back to a safe default (PS7, "latest version", "nothing selected") instead of crashing the cmdlet. `Repair-PSFixer`'s guided menu and `Show-PSFixerCatalog` build on the same `Test-PSFixerInteractive` check: outside an interactive session they fail fast with a clear error instead of attempting to prompt at all.

## PowerShellGet vs. PSResourceGet: two separate trust stores

`Set-PSRepository -InstallationPolicy Trusted` (PowerShellGet) and `Set-PSResourceRepository -Trusted` (PSResourceGet) are **entirely independent** — even though they both point at `https://www.powershellgallery.com`, trusting PSGallery in one does nothing to the other's own trust flag. `Get-PSFixerRepository` (and therefore `Invoke-PSFixerAnalysis`'s `Repository` finding and `Test-PSFixerBaseline`) prefers PSResourceGet when it's installed, since that's the modern default going forward.

This used to mean `Reset-PSFixerEnvironment -Scope Repositories` and `Set-PSFixerBaseline` could report success while the "PSGallery is registered but not Trusted" finding kept coming back — they only ever called the PowerShellGet cmdlets. Both now also call the PSResourceGet equivalents when that module is present, so the finding actually clears. Verified live: deliberately set `Get-PSResourceRepository`'s PSGallery to untrusted, confirmed `Invoke-PSFixerAnalysis` flags it, ran `Reset-PSFixerEnvironment -Scope Repositories`, confirmed both `Get-PSRepository` and `Get-PSResourceRepository` report `Trusted` afterward and the finding count drops to 0.
