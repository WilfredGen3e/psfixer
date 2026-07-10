# Product Requirements Document — PSFixer

| | |
|---|---|
| **Product** | PSFixer — PowerShell-module |
| **Versie document** | 1.0 (concept) |
| **Datum** | 10 juli 2026 |
| **Status** | Ter review |
| **Eigenaar** | *[naam productowner]* |

---

## 1. Samenvatting

PSFixer is een PowerShell-module die fungeert als diagnose-, herstel- en beheerframework voor PowerShell-beheerwerkplekken. De module stelt beheerders in staat om binnen enkele minuten een volledig beeld te krijgen van hun PowerShell-omgeving (versies, modules, repositories, providers), conflicten en vervuiling te detecteren, en de omgeving terug te brengen naar een schone, ondersteunde en moderne baseline — zonder handmatige ingrepen in modulepaden, registry-instellingen of repositoryconfiguraties.

## 2. Achtergrond en probleemstelling

PowerShell is het primaire beheerplatform voor Microsoft 365, Entra ID, Exchange Online, Azure en Intune. In de praktijk raken beheerwerkplekken na verloop van tijd vervuild en inconsistent door:

1. **Meerdere PowerShell-versies** naast elkaar (Windows PowerShell 5.1, PowerShell 7.2 t/m 7.5), waarbij onduidelijk is welke versie actief is, welke standaard start en welke door een module wordt ondersteund.
2. **Modules op meerdere locaties**: AllUsers (`C:\Program Files\PowerShell\Modules`), CurrentUser (`%USERPROFILE%\Documents\PowerShell\Modules`), Windows PowerShell (`C:\Program Files\WindowsPowerShell\Modules`) en custom locaties via `$env:PSModulePath`. Dezelfde module kan daardoor meerdere keren aanwezig zijn.
3. **Meerdere moduleversies** op één systeem (bijv. Az 11.x t/m 14.x), waardoor onvoorspelbaar is welke versie geladen wordt en scripts zich per machine anders gedragen.
4. **Legacy modules** (AzureAD, AzureADPreview, MSOnline) naast moderne modules (Microsoft.Graph, ExchangeOnlineManagement, Az), met command conflicts, afwijkende authenticatiemethoden en verouderde dependencies tot gevolg.
5. **Installatiecontextproblemen**: installaties als Administrator vs. normale gebruiker, vanuit verschillende PowerShell- en PowerShellGet-versies, met installatiefouten, updateproblemen en import errors tot gevolg.
6. **Gallery-configuratieproblemen**: PSGallery niet geregistreerd of Untrusted, foutieve repositories, oude NuGet-providers en defecte PowerShellGet-configuraties.

Typische symptomen zijn: "Bij mij werkt het wel", "Command not found", "Module cannot be loaded", falende `Connect-AzAccount` en `Update-Module`. Troubleshooting kost hierdoor regelmatig uren per incident. Er bestaat op dit moment geen eenvoudig hulpmiddel dat inventariseert, analyseert, herstelt en een baseline afdwingt.

## 3. Doelstellingen

**Productdoel:** een beheerder met een volledig vervuilde PowerShell-omgeving kan binnen enkele minuten (a) zien wat er mis is, (b) begrijpen waarom, (c) terugkeren naar een schone baseline en (d) weer veilig modules installeren vanuit PowerShell 7.

**Meetbare doelen (v1):**

| Doel | Meetwaarde |
|---|---|
| Volledige inventarisatie van een werkplek | < 60 seconden op een standaardwerkplek |
| Herstel naar schone baseline | < 10 minuten, zonder handmatige stappen |
| Detectiegraad bekende probleemcategorieën | 100% van de in §2 genoemde categorieën |
| Reductie troubleshooting-tijd | Van uren naar minuten (kwalitatief te valideren via pilot) |

**Niet-doelen (out of scope v1):**

- Beheer van modules buiten het PowerShell-ecosysteem (chocolatey, winget-pakketten anders dan PowerShell 7 zelf)
- Tenant- of cloudconfiguratie (PSFixer beheert de werkplek, niet de omgeving waarmee verbonden wordt)
- GUI/desktop-applicatie; v1 is uitsluitend een PowerShell-module met CLI-cmdlets
- Cross-platform (macOS/Linux) — Windows first; cross-platform is een latere fase

## 4. Doelgroep en persona's

**Primair:** Microsoft 365-beheerders, MSP-engineers, Azure-engineers, Intune-beheerders, security consultants.
**Secundair:** PowerShell-beginners, servicedeskmedewerkers, trainings- en labomgevingen.

**Persona 1 — MSP-engineer:** werkt op meerdere klantomgevingen, gebruikt scripts die "bij de één wel en bij de ander niet" werken. Heeft behoefte aan snelle diagnose en een reproduceerbare baseline op elke werkplek.

**Persona 2 — M365-beheerder:** heeft door de jaren heen MSOnline, AzureAD én Microsoft.Graph geïnstalleerd. Loopt vast op command conflicts en authenticatiefouten. Heeft behoefte aan opschoning en migratie naar moderne modules.

**Persona 3 — servicedeskmedewerker / beginner:** weet niet welke PowerShell-versie actief is of waar modules staan. Heeft behoefte aan begrijpelijke rapportage en één "maak het goed"-commando.

## 5. Functionele requirements

Prioritering volgens MoSCoW. Alle cmdlets volgen de PowerShell verb-noun-conventie met prefix `PSFixer`.

### 5.1 Inventariseren (Must have)

**Cmdlet:** `Get-PSFixerInventory` (met sub-cmdlets zoals `Get-PSFixerModule`, `Get-PSFixerRepository`)

| ID | Requirement |
|---|---|
| INV-01 | Detecteer alle geïnstalleerde PowerShell-versies (Windows PowerShell 5.1, alle PowerShell 7.x-installaties) |
| INV-02 | Toon de actieve PowerShell-versie en de standaardversie |
| INV-03 | Inventariseer alle geïnstalleerde modules inclusief versie(s) per module |
| INV-04 | Toon per module-installatie de locatie (AllUsers, CurrentUser, Windows PowerShell, custom via `$env:PSModulePath`) en de installatiescope |
| INV-05 | Inventariseer geregistreerde repositories inclusief trust-status |
| INV-06 | Inventariseer package providers (o.a. NuGet) inclusief versies |
| INV-07 | Toon de geïnstalleerde versies van PowerShellGet en PSResourceGet |
| INV-08 | Exporteer de inventarisatie als object (pipeline-vriendelijk) én als leesbaar rapport (console; JSON/HTML-export: Should have) |

### 5.2 Analyseren (Must have)

**Cmdlet:** `Invoke-PSFixerAnalysis` (of `Test-PSFixerEnvironment`)

| ID | Requirement |
|---|---|
| ANA-01 | Detecteer dubbele modules (zelfde module op meerdere locaties) |
| ANA-02 | Detecteer meerdere versies van dezelfde module en markeer welke versie daadwerkelijk geladen wordt |
| ANA-03 | Detecteer verouderde versies (nieuwere versie beschikbaar in de gallery) |
| ANA-04 | Detecteer conflicterende versies en command conflicts |
| ANA-05 | Detecteer legacy/unsupported modules (o.a. AzureAD, AzureADPreview, MSOnline) en adviseer de moderne opvolger |
| ANA-06 | Detecteer repository-problemen: PSGallery ontbreekt, Untrusted, foutieve registraties |
| ANA-07 | Detecteer verouderde/defecte NuGet-providers en PowerShellGet-configuraties |
| ANA-08 | Presenteer bevindingen met ernst (Info / Warning / Critical), oorzaak-uitleg in begrijpelijke taal en een concrete aanbevolen actie |

### 5.3 Herstellen (Must have)

**Cmdlet:** `Reset-PSFixerEnvironment`

| ID | Requirement |
|---|---|
| HER-01 | Verwijder oude en dubbele moduleversies |
| HER-02 | Verwijder conflicterende versies (behoud van de gewenste versie configureerbaar) |
| HER-03 | Herconfigureer repositories; herstel PSGallery (registratie + Trusted) |
| HER-04 | Werk package providers en PowerShellGet/PSResourceGet bij naar ondersteunde versies |
| HER-05 | Ondersteun `-WhatIf` en `-Confirm` op alle destructieve acties (verplicht) |
| HER-06 | Maak vóór herstel een backup/snapshot van de huidige staat en bied een rollback-mogelijkheid (Should have voor volledige rollback; snapshot-export is Must) |
| HER-07 | Gefaseerd herstel mogelijk: alleen repositories, alleen modules, alleen providers, of alles |
| HER-08 | Logging van alle uitgevoerde acties naar een transcript/logbestand |

### 5.4 Baseline (Must have)

**Cmdlet:** `Set-PSFixerBaseline` / `Test-PSFixerBaseline`

| ID | Requirement |
|---|---|
| BAS-01 | Installeer/valideer de laatste PowerShell 7-versie |
| BAS-02 | Richt PSGallery correct in (geregistreerd, Trusted) |
| BAS-03 | Zorg dat benodigde package providers aanwezig en actueel zijn |
| BAS-04 | Pas aanbevolen instellingen toe (o.a. TLS 1.2+, execution policy-advies, PSResourceGet als standaard) |
| BAS-05 | `Test-PSFixerBaseline` rapporteert compliance t.o.v. de baseline zonder wijzigingen door te voeren |
| BAS-06 | Baseline-definitie is als configuratie (bijv. JSON) aanpasbaar voor organisaties (Should have) |

### 5.5 Modulebeheer via profielen (Must have)

**Cmdlet:** `Install-PSFixerProfile <profielnaam>`

| ID | Requirement |
|---|---|
| PRO-01 | Ingebouwd profiel `M365Admin`: installeert ExchangeOnlineManagement, Microsoft.Graph, MicrosoftTeams, Az.Accounts |
| PRO-02 | Ingebouwd profiel `AzureEngineer`: installeert alle relevante Az-modules |
| PRO-03 | Aanvullende profielen (Should have): `IntuneAdmin`, `SecurityConsultant`, `Helpdesk` |
| PRO-04 | Profielen installeren altijd in een consistente, aanbevolen scope (default: CurrentUser, PowerShell 7) |
| PRO-05 | Eigen/organisatieprofielen definieerbaar via configuratiebestand (Should have) |
| PRO-06 | `Update-PSFixerProfile` werkt alle modules van een profiel bij naar de laatste ondersteunde versies (Should have) |

### 5.6 Could have (v1.x / v2)

- HTML-dashboardrapport van inventarisatie en analyse
- Scheduled health check (bijv. via geplande taak) met drift-detectie t.o.v. baseline
- Centrale rapportage voor MSP's over meerdere werkplekken
- Cross-platformondersteuning (macOS/Linux)

## 6. Niet-functionele requirements

| ID | Requirement |
|---|---|
| NFR-01 | **Compatibiliteit:** de module zelf draait op Windows PowerShell 5.1 én PowerShell 7.x (juist een vervuilde omgeving heeft mogelijk alleen 5.1 werkend) |
| NFR-02 | **Veiligheid:** geen destructieve actie zonder expliciete bevestiging of `-Force`; volledige `SupportsShouldProcess`-implementatie |
| NFR-03 | **Idempotentie:** herhaald uitvoeren van baseline- en herstelcommando's leidt tot dezelfde eindtoestand |
| NFR-04 | **Rechten:** duidelijke afhandeling van Administrator- vs. gebruikerscontext; heldere foutmelding als verhoogde rechten nodig zijn |
| NFR-05 | **Offline-tolerantie:** inventarisatie en analyse werken zonder internet; alleen gallery-checks en installaties vereisen connectiviteit |
| NFR-06 | **Performance:** volledige inventarisatie < 60 s op een standaardwerkplek |
| NFR-07 | **Distributie:** publicatie via PSGallery; ondertekende module (code signing) |
| NFR-08 | **Taal:** cmdlet-output en helpteksten in het Engels (PowerShell-conventie); documentatie in Engels en Nederlands (Should have) |
| NFR-09 | **Transparantie:** alle wijzigingen worden gelogd; log is achteraf te exporteren voor auditdoeleinden |
| NFR-10 | **Geen telemetrie** zonder expliciete opt-in |

## 7. Gebruikersscenario's

**Scenario A — "Bij mij werkt het wel":** een MSP-engineer draait `Get-PSFixerInventory` op twee machines, vergelijkt de export en ziet dat machine B Az 11.x laadt uit een custom pad. `Reset-PSFixerEnvironment -Scope Modules` verwijdert de oude versies; het script werkt daarna op beide machines identiek.

**Scenario B — Vervuilde werkplek saneren:** een M365-beheerder draait `Invoke-PSFixerAnalysis`, ziet Critical-bevindingen (MSOnline naast Microsoft.Graph, PSGallery Untrusted), voert `Reset-PSFixerEnvironment` uit met `-WhatIf`, controleert het plan, en voert het daarna definitief uit. Aansluitend `Set-PSFixerBaseline` en `Install-PSFixerProfile M365Admin`. Totale doorlooptijd: < 10 minuten.

**Scenario C — Nieuwe werkplek inrichten:** een helpdeskmedewerker krijgt een verse laptop en draait `Set-PSFixerBaseline` gevolgd door `Install-PSFixerProfile M365Admin`. De werkplek is direct conform organisatiestandaard.

## 8. Succescriteria en acceptatie

De v1-release is geslaagd wanneer in een testomgeving met een bewust vervuilde werkplek (5.1 + drie PS7-versies, Az in vier versies, MSOnline + AzureAD + Microsoft.Graph, PSGallery Untrusted, oude NuGet-provider):

1. `Get-PSFixerInventory` alle onderdelen correct en volledig rapporteert;
2. `Invoke-PSFixerAnalysis` alle zes probleemcategorieën uit §2 detecteert met correcte ernst en aanbeveling;
3. `Reset-PSFixerEnvironment` de omgeving zonder handmatige stappen terugbrengt naar een schone toestand;
4. `Set-PSFixerBaseline` + `Install-PSFixerProfile M365Admin` resulteert in een werkende omgeving waarin `Connect-MgGraph`, `Connect-ExchangeOnline` en `Connect-AzAccount` slagen;
5. het volledige traject (diagnose → herstel → baseline → profiel) binnen 10 minuten is afgerond;
6. `-WhatIf` op elk moment een correct en volledig wijzigingsplan toont zonder iets te wijzigen.

## 9. Risico's en mitigaties

| Risico | Impact | Mitigatie |
|---|---|---|
| Verwijderen van modules die door andere tooling/scripts vereist zijn | Hoog | `-WhatIf` verplicht ondersteund, snapshot vóór herstel, expliciete uitsluitlijst configureerbaar |
| Herstel faalt halverwege (bijv. locked files, rechten) | Middel | Transactionele fasering, duidelijke resume-instructies, logging |
| Module moet zelf draaien op defecte PowerShellGet-omgeving | Hoog | Minimale dependencies; bootstrap-pad dat zonder PSGallery werkt (bijv. losse installer-script) |
| Legacy-detectielijst veroudert | Middel | Detectiedefinities als updatebare data (niet hardcoded), release-cadans afspreken |
| Organisaties met eigen interne repositories | Middel | Baseline-configuratie ondersteunt custom repositories (BAS-06) |

## 10. Open vragen

1. Moet `Reset-PSFixerEnvironment` ook PowerShell-versies zelf kunnen de-installeren, of alleen adviseren?
2. Hoe ver gaat rollback: alleen moduleherstel, of ook repository- en providerconfiguratie?
3. Worden profieldefinities centraal (door het projectteam) onderhouden of community-driven?
4. Is code signing met een commercieel certificaat beschikbaar vóór de eerste PSGallery-publicatie?
5. Gewenste licentievorm (open source / intern)?

## 11. Fasering (voorstel)

| Fase | Inhoud | Indicatie |
|---|---|---|
| MVP (v0.9) | Inventariseren + analyseren, rapportage in console | Sprint 1–3 |
| v1.0 | Herstel (`Reset-PSFixerEnvironment`), baseline, profielen M365Admin en AzureEngineer | Sprint 4–7 |
| v1.x | Extra profielen, HTML-rapportage, custom baselines/profielen, rollback | Daarna |
| v2.0 | Drift-detectie, MSP-rapportage, cross-platform | Backlog |
