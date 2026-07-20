<#
.SYNOPSIS
    Generates a local HTML report from MSObserver evidence.

.DESCRIPTION
    Matches observed domains against the endpoint database and renders a
    self-contained HTML file. No network access, no external resources.
    Sections are rendered only when the corresponding data is present.

.PARAMETER EvidencePath
    Path to a msobserver-*.json file produced by Invoke-MSObserver.ps1.

.PARAMETER DatabasePath
    Path to endpoints.json. Defaults to ..\data\endpoints.json.

.PARAMETER OutputPath
    Path of the HTML output. Defaults to the evidence file with .html extension.

.NOTES
    German text is emitted using HTML entities for umlauts so that the source
    file stays ASCII-safe regardless of how PowerShell interprets its encoding.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EvidencePath,
    [string]$DatabasePath,
    [string]$OutputPath
)

Set-StrictMode -Version 3

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $DatabasePath) { $DatabasePath = Join-Path $scriptRoot '..\data\endpoints.json' }

# -Encoding UTF8 is mandatory in PowerShell 5.1: BOM-less UTF-8 would
# otherwise be read as ANSI and mangle non-ASCII characters.
$evidence = Get-Content $EvidencePath -Raw -Encoding UTF8 | ConvertFrom-Json
$database = Get-Content $DatabasePath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $OutputPath) { $OutputPath = [IO.Path]::ChangeExtension($EvidencePath, 'html') }

function Test-Prop {
    param($Object, [string]$Name)
    $Object -and ($Object.PSObject.Properties.Name -contains $Name)
}
function Test-Section {
    param($Section)
    $Section -and -not (Test-Prop $Section 'skipped')
}
function Get-JsonPath {
    param($Object, [string[]]$Path)
    $current = $Object
    foreach ($segment in $Path) {
        if ($null -eq $current -or -not ($current.PSObject.Properties.Name -contains $segment)) { return $null }
        $current = $current.$segment
    }
    return $current
}
function Find-Endpoint {
    param([string]$Domain)
    foreach ($entry in $database.endpoints) {
        $pattern = $entry.domain -replace '\.', '\.' -replace '\*', '.*'
        if ($Domain -match "^$pattern$" -or $Domain -match "$pattern$") { return $entry }
    }
    return $null
}

# Documented privacy data types (bitmask) - see docs/payload-fields.md
$privacyTypes = @{
    2          = 'Browserverlauf'
    2048       = 'Ger&auml;te-Konnektivit&auml;t und -Konfiguration'
    131072     = 'Eingabe, Tinte und Sprache'
    16777216   = 'Produkt- und Dienstleistungsperformance'
    33554432   = 'Produkt- und Dienstnutzung'
    2147483648 = 'Software-Setup und Inventar'
}
function Convert-PrivacyType {
    param($Value)
    if ($null -eq $Value) { return '' }
    $bits = [long]$Value
    $names = foreach ($key in $privacyTypes.Keys) { if ($bits -band [long]$key) { $privacyTypes[$key] } }
    if ($names) { @($names) -join ', ' } else { "unbekannt ($Value)" }
}

$severityLabel = @{
    security    = @{ name = 'Sicherheitsfunktion'; color = '#0F6E56'; bg = '#E1F5EE' }
    update      = @{ name = 'Update';              color = '#185FA5'; bg = '#E6F1FB' }
    system      = @{ name = 'Systemfunktion';      color = '#5F5E5A'; bg = '#F1EFE8' }
    account     = @{ name = 'Konto';               color = '#5F5E5A'; bg = '#F1EFE8' }
    telemetry   = @{ name = 'Telemetrie';          color = '#854F0B'; bg = '#FAEEDA' }
    content     = @{ name = 'Inhaltsdienst';       color = '#534AB7'; bg = '#EEEDFE' }
    advertising = @{ name = 'Werbung';             color = '#993C1D'; bg = '#FAECE7' }
}

# ---------------------------------------------------------------- summary chips
$chips = @()
if (Test-Prop $evidence 'edition') {
    $chips += "<span class='chip'>Edition <b>$($evidence.edition)</b></span>"
}
if ((Test-Prop $evidence 'registryState') -and $evidence.registryState) {
    $chips += "<span class='chip'>Diagnosestufe <b>$($evidence.registryState.telemetry.effectiveName)</b></span>"
}
if ((Test-Prop $evidence 'diagnosisEvents') -and (Test-Section $evidence.diagnosisEvents)) {
    $chips += "<span class='chip'>Diagnoseereignisse <b>$($evidence.diagnosisEvents.totalEvents)</b></span>"
}
if (Test-Prop $evidence 'tcpConnections') {
    $chips += "<span class='chip'>TCP-Verbindungen <b>$(@($evidence.tcpConnections).Count)</b></span>"
}
if ((Test-Prop $evidence 'windowSeconds') -and $evidence.windowSeconds -gt 0) {
    $chips += "<span class='chip'>Beobachtungsfenster <b>$($evidence.windowSeconds) s</b></span>"
}
$chipHtml = $chips -join "`n"

$body = ''

# ---------------------------------------------------------------- registry
if (Test-Prop $evidence 'registryState') {
    $reg = $evidence.registryState
    $body += @"
<section id="konfiguration"><h2>Konfiguration der Datenerhebung</h2>
<table>
<tr><th>Einstellung</th><th>Wert</th></tr>
<tr><td>Diagnosedatenstufe (effektiv)</td><td>$($reg.telemetry.effectiveName)</td></tr>
<tr><td>Werbe-ID</td><td>$($reg.advertisingId.enabled)</td></tr>
<tr><td>Aktivit&auml;tsverlauf, Upload</td><td>$($reg.activityHistory.uploadUserActivities)</td></tr>
<tr><td>Bing-Suche im Startmen&uuml;</td><td>$($reg.search.bingSearchEnabled)</td></tr>
<tr><td>Defender-Cloudschutz</td><td>$($reg.defenderMaps.spynetReporting)</td></tr>
<tr><td>Defender-Beispiel&uuml;bermittlung</td><td>$($reg.defenderMaps.submitSamplesConsent)</td></tr>
<tr><td>Fehlerberichterstattung deaktiviert</td><td>$($reg.errorReporting.disabled)</td></tr>
</table>
<p class="meta">Leere Werte bedeuten: Schl&uuml;ssel nicht gesetzt, es gilt der Systemstandard.</p></section>
"@
}

# ---------------------------------------------------------------- tracking
if ((Test-Prop $evidence 'trackingMechanisms') -and $evidence.trackingMechanisms) {
    $rows = (@($evidence.trackingMechanisms) | ForEach-Object {
        $class = if ($_.state -match 'deaktiviert|verweigert|eingeschraenkt') { 'st-off' }
                 elseif ($_.state -match 'aktiv|erlaubt|vorhanden|Sammlung|Cloud') { 'st-on' }
                 else { 'st-na' }
        "<tr><td>$($_.area)</td><td>$($_.name)</td><td><span class='state $class'>$($_.state)</span></td><td><code>$($_.value)</code></td><td class='meta'>$($_.note)</td></tr>"
    }) -join "`n"
    $body += @"
<section id="mechanismen"><h2>Eingebaute Erhebungsmechanismen</h2>
<table>
<tr><th>Bereich</th><th>Mechanismus</th><th>Status</th><th>Rohwert</th><th>Bedeutung</th></tr>
$rows
</table></section>
"@
}

# ---------------------------------------------------------------- events
if (Test-Prop $evidence 'diagnosisEvents') {
    $events = $evidence.diagnosisEvents
    if (Test-Section $events) {
        $eventRows = (@($events.topEvents) | ForEach-Object {
            "<tr><td><code>$($_.eventName)</code></td><td class='num'>$($_.count)</td></tr>"
        }) -join "`n"
        $binaryRows = (@($events.topBinaries) | ForEach-Object {
            "<tr><td><code>$($_.binary)</code></td><td class='num'>$($_.count)</td></tr>"
        }) -join "`n"
        $body += @"
<section id="ereignisse"><h2>Inhalt der Diagnoseereignisse</h2>
<p class="meta">$($events.totalEvents) Ereignisse im Zeitraum $($events.timeRange.from) bis $($events.timeRange.to).
Quelle: lokale Ereignishistorie &ndash; dieselben Objekte, die an Microsoft &uuml;bertragen werden.</p>
<div class="cols">
<div><h3>Ereignistypen</h3><table><tr><th>Typ</th><th>Anzahl</th></tr>
$eventRows
</table></div>
<div><h3>Erzeugende Prozesse</h3><table><tr><th>Prozess</th><th>Anzahl</th></tr>
$binaryRows
</table></div>
</div>
"@
        if ((Test-Prop $events 'samplePayloads') -and $events.samplePayloads) {
            $body += @"
<div class="warn"><b>Payload-Beispiele enthalten.</b> Die folgenden Ereignisse sind vollst&auml;ndig
wiedergegeben und enthalten Ger&auml;tekennungen. Diesen Report nicht ver&ouml;ffentlichen.
<button id="plToggle" class="btn" type="button">Alle auf- oder zuklappen</button></div>
<div class="payloads">
"@
            foreach ($sample in @($events.samplePayloads)) {
                $pretty = try { $sample.payload | ConvertFrom-Json | ConvertTo-Json -Depth 12 } catch { $sample.payload }
                $escaped = $pretty -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
                $shortName = ($sample.eventName -split '\.')[-1]
                $timeShort = if ($sample.timeUtc) { $sample.timeUtc -replace 'T', ' ' -replace '\.\d+Z', ' UTC' } else { '' }

                $envelopeHtml = ''
                $parsed = try { $sample.payload | ConvertFrom-Json } catch { $null }
                if ($parsed) {
                    $isRequired = Get-JsonPath $parsed @('ext','privacy','isRequired')
                    $hardware = ('{0} {1}' -f (Get-JsonPath $parsed @('ext','protocol','devMake')),
                                               (Get-JsonPath $parsed @('ext','protocol','devModel'))).Trim()
                    $requiredText = if ($null -ne $isRequired) {
                        if ($isRequired) { 'ja, auch auf Stufe Required' } else { 'nein, nur auf Stufe Optional' }
                    } else { '' }

                    $pairs = @(
                        ,@('Ger&auml;te-ID',        (Get-JsonPath $parsed @('ext','device','localId')))
                        ,@('Nutzer-ID',             (Get-JsonPath $parsed @('ext','user','localId')))
                        ,@('Xbox-Ger&auml;te-ID',   (Get-JsonPath $parsed @('ext','xbl','did')))
                        ,@('Hardware',              $hardware)
                        ,@('Anwendung',             (Get-JsonPath $parsed @('ext','app','id')))
                        ,@('Betriebssystem-Build',  (Get-JsonPath $parsed @('ext','os','ver')))
                        ,@('Sampling-Kohorte',      (Get-JsonPath $parsed @('ext','utc','dvcSample')))
                        ,@('Datenkategorie',        (Convert-PrivacyType (Get-JsonPath $parsed @('ext','privacy','dataType'))))
                        ,@('Erhebungsstufe',        $requiredText)
                    )
                    $envelopeRows = ($pairs | Where-Object { $_[1] } | ForEach-Object {
                        "<tr><th>$($_[0])</th><td><code>$($_[1])</code></td></tr>"
                    }) -join "`n"
                    if ($envelopeRows) {
                        $envelopeHtml = "<div class='envwrap'><div class='envtitle'>Kennungen im Umschlag &ndash; Felderkl&auml;rung in docs/payload-fields.md</div><table>$envelopeRows</table></div>"
                    }
                }

                $body += @"
<details class="pl">
<summary>
  <span class="pl-name" title="$($sample.eventName)">$shortName</span>
  <span class="pl-full">$($sample.eventName)</span>
  <span class="pl-meta">$timeShort &middot; $($sample.binary)</span>
</summary>
$envelopeHtml
<pre class="json">$escaped</pre>
</details>
"@
            }
            $body += '</div>'
        }
        $body += '</section>'
    } else {
        $body += "<section id='ereignisse'><h2>Inhalt der Diagnoseereignisse</h2><p class='meta'>$($events.skipped)</p></section>"
    }
}

# ---------------------------------------------------------------- uploads
if (Test-Prop $evidence 'diagnosisState') {
    $state = $evidence.diagnosisState
    if ((Test-Section $state) -and (Test-Prop $state 'uploadStats') -and $state.uploadStats) {
        $stats = $state.uploadStats
        $body += @"
<section id="uploads"><h2>Nachweis erfolgter &Uuml;bertragungen</h2>
<table>
<tr><th>Z&auml;hler</th><th>Wert</th></tr>
<tr><td>HTTP-Uploads gesamt</td><td class='num'>$($stats.httpRequestCount)</td></tr>
<tr><td>Dienststarts gesamt</td><td class='num'>$($stats.launchCount)</td></tr>
<tr><td>Letzte erfolgreiche &Uuml;bertragung</td><td>$($stats.lastSuccessfulUploadUtc)</td></tr>
<tr><td>Letzte Echtzeit&uuml;bertragung</td><td>$($stats.lastSuccessfulRealtimeUtc)</td></tr>
<tr><td>Letzte regul&auml;re &Uuml;bertragung</td><td>$($stats.lastSuccessfulNormalUtc)</td></tr>
</table>
<p class="meta">Quelle: Betriebsz&auml;hler des Telemetriedienstes. Belegt tats&auml;chlich erfolgte
&Uuml;bertragungen unabh&auml;ngig von Namensaufl&ouml;sung und Netzwerkmitschnitt. Zeiten in UTC.</p></section>
"@
    }
}

# ---------------------------------------------------------------- dns
if (Test-Prop $evidence 'dnsQueries') {
    if (Test-Section $evidence.dnsQueries) {
        $matched = @(); $unmatched = @()
        foreach ($query in @($evidence.dnsQueries)) {
            $hit = Find-Endpoint -Domain $query.domain
            if ($hit) {
                $matched += [pscustomobject]@{ domain = $query.domain; count = $query.count; endpoint = $hit }
            } elseif ($query.domain -match '(microsoft|msedge|live|msn|bing|windows|azure|office|skype|xbox)') {
                $unmatched += $query
            }
        }
        $rows = ($matched | Sort-Object { $_.endpoint.severity }, domain | ForEach-Object {
            $label = $severityLabel[$_.endpoint.severity]
            $categories = ($_.endpoint.categories -join ', ')
            "<tr><td><span class='pill' style='color:$($label.color);background:$($label.bg)'>$($label.name)</span></td>" +
            "<td><code>$($_.domain)</code></td><td>$($_.endpoint.service)</td>" +
            "<td>$categories</td><td>$($_.endpoint.trigger)</td>" +
            "<td class='num'>$($_.count)</td><td>$($_.endpoint.evidence)</td></tr>"
        }) -join "`n"
        $unmatchedRows = ($unmatched | Sort-Object -Property count -Descending | ForEach-Object {
            "<tr><td><code>$($_.domain)</code></td><td class='num'>$($_.count)</td></tr>"
        }) -join "`n"
        $body += @"
<section id="endpunkte"><h2>Beobachtete Microsoft-Endpunkte</h2>
<table>
<tr><th>Kategorie</th><th>Domain</th><th>Dienst</th><th>Datenkategorien</th><th>Ausl&ouml;ser</th><th>Anfragen</th><th>Beleg</th></tr>
$rows
</table>
<h3>Nicht zugeordnete Domains</h3>
<p class="meta">Kandidaten f&uuml;r neue Datenbankeintr&auml;ge. Beitr&auml;ge willkommen &ndash; siehe CONTRIBUTING.md.</p>
<table><tr><th>Domain</th><th>Anfragen</th></tr>
$unmatchedRows
</table></section>
"@
    } else {
        $body += "<section id='endpunkte'><h2>Beobachtete Microsoft-Endpunkte</h2><p class='meta'>$($evidence.dnsQueries.skipped)</p></section>"
    }
}

# ---------------------------------------------------------------- tasks
if (Test-Prop $evidence 'scheduledTasks') {
    $taskRows = (@($evidence.scheduledTasks) | Where-Object { $_.lastRunTime } |
        Sort-Object -Property lastRunTime -Descending | Select-Object -First 12 | ForEach-Object {
        $time = $_.lastRunTime -replace 'T', ' ' -replace '\.\d+', ''
        "<tr><td><code>$($_.taskPath)$($_.taskName)</code></td><td>$($_.state)</td><td>$time</td></tr>"
    }) -join "`n"
    $body += @"
<section id="aufgaben"><h2>Ausl&ouml;sende Systemaufgaben</h2>
<table><tr><th>Aufgabe</th><th>Status</th><th>Letzte Ausf&uuml;hrung</th></tr>
$taskRows
</table></section>
"@
}

# ---------------------------------------------------------------- navigation
$nav = ([regex]::Matches($body, '<section id="([^"]+)"><h2>(.*?)</h2>') | ForEach-Object {
    "<a href='#$($_.Groups[1].Value)'>$($_.Groups[2].Value)</a>"
}) -join "`n"

$css = @'
 :root { --ink:#2C2C2A; --muted:#73726c; --line:#e6e4dd; --bg:#faf9f6; --card:#fff;
         --accent:#185FA5; }
 * { box-sizing:border-box; }
 body { font-family:'Segoe UI', system-ui, sans-serif; margin:0; background:var(--bg);
        color:var(--ink); line-height:1.55; }
 .wrap { max-width:1150px; margin:0 auto; padding:2.2rem 1.5rem 4rem; }
 h1 { font-size:1.45rem; margin:0 0 .2rem; letter-spacing:-.01em; }
 .sub { color:var(--muted); font-size:.86rem; margin:0 0 1rem; }
 .chips { display:flex; flex-wrap:wrap; gap:.5rem; margin:1rem 0; }
 .chip { background:var(--card); border:1px solid var(--line); border-radius:999px;
         padding:.3rem .85rem; font-size:.8rem; color:var(--muted); }
 .chip b { color:var(--ink); font-weight:600; margin-left:.25rem; }
 #q { width:100%; max-width:440px; padding:.5rem .85rem; border:1px solid var(--line);
      border-radius:8px; font-size:.9rem; margin:.2rem 0 1rem; background:#fff; }
 nav { display:flex; flex-wrap:wrap; gap:.3rem 1rem; padding:.7rem 0 1rem;
       border-top:1px solid var(--line); border-bottom:1px solid var(--line);
       margin-bottom:.5rem; font-size:.84rem; }
 nav a { color:var(--accent); text-decoration:none; }
 nav a:hover { text-decoration:underline; }
 section { background:var(--card); border:1px solid var(--line); border-radius:12px;
           padding:1.3rem 1.5rem; margin:1.3rem 0; }
 h2 { font-size:1.02rem; margin:.1rem 0 .9rem; }
 h3 { font-size:.9rem; margin:1.1rem 0 .5rem; color:var(--muted); font-weight:600; }
 table { border-collapse:collapse; width:100%; font-size:.84rem; }
 th, td { text-align:left; padding:.45rem .6rem; border-bottom:1px solid var(--line);
          vertical-align:top; }
 th { color:var(--muted); font-weight:600; }
 tr:last-child td { border-bottom:none; }
 tbody tr:hover td, table tr:hover td { background:#faf9f4; }
 td.num { text-align:right; font-variant-numeric:tabular-nums; white-space:nowrap; }
 code { background:#f2f0ea; padding:.05rem .3rem; border-radius:4px; font-size:.92em;
        overflow-wrap:anywhere; }
 .cols { display:grid; grid-template-columns:1.4fr 1fr; gap:1.5rem; }
 .cols > div { min-width:0; }
 @media (max-width:820px) { .cols { grid-template-columns:1fr; } }
 .meta { color:var(--muted); font-size:.82rem; }
 .pill { border-radius:999px; padding:.13rem .6rem; font-size:.74rem; font-weight:600;
         white-space:nowrap; }
 .state { border-radius:6px; padding:.1rem .45rem; font-size:.77rem; font-weight:600; }
 .st-on { background:#FAECE7; color:#993C1D; }
 .st-off { background:#E1F5EE; color:#0F6E56; }
 .st-na { background:#F1EFE8; color:#5F5E5A; }
 th.sortable { cursor:pointer; user-select:none; }
 th.s-asc::after { content:' \25B4'; } th.s-desc::after { content:' \25BE'; }
 .btn { border:1px solid var(--line); background:#fff; border-radius:8px;
        padding:.25rem .7rem; font-size:.78rem; cursor:pointer; margin-left:.6rem; }
 .btn:hover { border-color:var(--accent); color:var(--accent); }
 .note { background:#FAEEDA; border-left:3px solid #BA7517; border-radius:0 8px 8px 0;
         padding:.75rem 1rem; font-size:.85rem; margin:1rem 0; }
 .warn { background:#FCEBEB; border-left:3px solid #A32D2D; border-radius:0 8px 8px 0;
         padding:.75rem 1rem; font-size:.85rem; margin:1rem 0; }
 .payloads { display:flex; flex-direction:column; gap:.6rem; margin-top:.6rem; }
 details.pl { border:1px solid var(--line); border-radius:10px; background:#fdfcfa;
              overflow:hidden; }
 details.pl[open] { background:#fff; }
 details.pl summary { display:flex; align-items:baseline; gap:.7rem; flex-wrap:wrap;
              padding:.65rem .9rem; cursor:pointer; list-style:none; }
 details.pl summary::-webkit-details-marker { display:none; }
 details.pl summary::before { content:'\25B8'; color:var(--muted); font-size:.8rem;
              transition:transform .15s; }
 details.pl[open] summary::before { transform:rotate(90deg); }
 .pl-name { font-family:Consolas, monospace; font-weight:600; font-size:.84rem;
            background:#EEEDFE; color:#3C3489; border-radius:6px; padding:.08rem .5rem; }
 .pl-full { font-family:Consolas, monospace; font-size:.71rem; color:var(--muted);
            overflow-wrap:anywhere; }
 .pl-meta { font-size:.74rem; color:var(--muted); margin-left:auto; white-space:nowrap; }
 .envwrap { padding:.6rem .9rem .8rem; border-bottom:1px solid var(--line); }
 .envtitle { font-size:.72rem; color:var(--muted); margin-bottom:.35rem; }
 .envwrap table { font-size:.78rem; }
 .envwrap th { width:210px; }
 pre.json { margin:0; padding:.9rem 1rem; background:#23241f; color:#e8e6df;
            font-size:.74rem; line-height:1.5; overflow:auto; max-height:480px; }
 pre.json .k { color:#8ab4f0; } pre.json .s { color:#9fe1cb; }
 pre.json .n { color:#fac775; } pre.json .b { color:#f09bb1; }
 footer { color:var(--muted); font-size:.79rem; margin-top:2.2rem;
          border-top:1px solid var(--line); padding-top:1rem; }
'@

$js = @'
document.querySelectorAll('pre.json').forEach(function (pre) {
  var t = pre.textContent;
  t = t.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  t = t.replace(/("(?:\\.|[^"\\])*")(\s*:)?/g, function (m, str, colon) {
        return colon ? '<span class="k">' + str + '</span>' + colon
                     : '<span class="s">' + str + '</span>';
      })
       .replace(/\b(true|false|null)\b/g, '<span class="b">$1</span>')
       .replace(/(-?\d+(?:\.\d+)?(?:[eE][+\-]?\d+)?)(?=[,\s\]}])/g, '<span class="n">$1</span>');
  pre.innerHTML = t;
});

var filter = document.getElementById('q');
if (filter) {
  filter.addEventListener('input', function () {
    var needle = filter.value.toLowerCase();
    document.querySelectorAll('section table tr').forEach(function (tr) {
      if (tr.closest('.envwrap') || !tr.querySelector('td')) return;
      tr.style.display = tr.textContent.toLowerCase().indexOf(needle) > -1 ? '' : 'none';
    });
    document.querySelectorAll('details.pl').forEach(function (d) {
      d.style.display = d.textContent.toLowerCase().indexOf(needle) > -1 ? '' : 'none';
    });
  });
}

document.querySelectorAll('section table').forEach(function (table) {
  if (table.closest('.envwrap')) return;
  var header = table.rows[0];
  if (!header || !header.querySelector('th')) return;
  Array.prototype.forEach.call(header.cells, function (th, index) {
    th.classList.add('sortable');
    th.title = 'Klicken zum Sortieren';
    th.addEventListener('click', function () {
      var rows = Array.prototype.slice.call(table.rows, 1);
      var ascending = th.dataset.asc !== '1';
      Array.prototype.forEach.call(header.cells, function (cell) {
        delete cell.dataset.asc;
        cell.classList.remove('s-asc', 's-desc');
      });
      th.dataset.asc = ascending ? '1' : '0';
      th.classList.add(ascending ? 's-asc' : 's-desc');
      rows.sort(function (a, b) {
        var x = a.cells[index] ? a.cells[index].textContent.trim() : '';
        var y = b.cells[index] ? b.cells[index].textContent.trim() : '';
        var nx = parseFloat(x.replace(',', '.')), ny = parseFloat(y.replace(',', '.'));
        var result = (!isNaN(nx) && !isNaN(ny) && /^[\d.,\-]+$/.test(x) && /^[\d.,\-]+$/.test(y))
                   ? nx - ny : x.localeCompare(y, 'de');
        return ascending ? result : -result;
      });
      rows.forEach(function (row) { table.appendChild(row); });
    });
  });
});

var toggle = document.getElementById('plToggle');
if (toggle) {
  toggle.addEventListener('click', function () {
    var all = document.querySelectorAll('details.pl');
    var anyClosed = Array.prototype.some.call(all, function (d) { return !d.open; });
    all.forEach(function (d) { d.open = anyClosed; });
  });
}
'@

$collected = $evidence.collectedAt -replace 'T', ' ' -replace '\.\d+.*', ''

$html = @"
<!DOCTYPE html>
<html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MSObserver &ndash; Report $($evidence.hostname)</title>
<style>
$css
</style></head><body><div class="wrap">
<header>
<h1>MSObserver</h1>
<p class="sub">$($evidence.hostname) &middot; Windows $($evidence.osVersion) &middot; erfasst am $collected</p>
<div class="chips">
$chipHtml
</div>
<input id="q" type="search" placeholder="Filtern nach Domain, Ereignistyp, Prozess ...">
<div class="note">Dieser Report zeigt, <b>was</b> erhoben wird, <b>wohin</b> es flie&szlig;t und
<b>wodurch</b> es ausgel&ouml;st wird. Sicherheitsfunktionen und Updates sind Schutz- beziehungsweise
Wartungsverkehr und kein Hinweis auf &Uuml;berwachung.</div>
<nav>
$nav
</nav>
</header>
$body
<footer>Erstellt mit MSObserver. Alle Daten verbleiben auf diesem Ger&auml;t.</footer>
</div>
<script>
$js
</script>
</body></html>
"@

$html | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "  Report: $OutputPath" -ForegroundColor Green
