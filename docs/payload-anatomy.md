# Aufbau eines Diagnoseereignisses

Jedes Windows-Diagnoseereignis folgt dem Common Schema 4.0 und besteht aus drei
Teilen: einem Kopf, einem Umschlag mit Kennungen (`ext`) und den eigentlichen
Nutzdaten (`data`).

```json
{
  "ver":  "4.0",
  "name": "Ereignistyp",
  "time": "Zeitstempel in UTC",
  "iKey": "Instrumentierungsschlüssel der Zielpipeline",
  "ext":  { "…Umschlag…" },
  "data": { "…Nutzdaten…" }
}
```

Wer verstehen will, was ein Ereignis über ein Gerät preisgibt, muss vor allem
den Umschlag lesen. Er ist bei jedem Ereignis gleich aufgebaut und macht alle
Ereignisse eines Geräts miteinander verknüpfbar. Die Bedeutung der einzelnen
Felder steht in der [Feldreferenz](payload-fields.md).

## Der Umschlag

Die wichtigsten Kennungen, die an jedem Ereignis hängen:

| Feld | Inhalt |
| --- | --- |
| `ext.device.localId` | Die Telemetrie-Geräte-ID. Identisch mit dem Registry-Wert `SQMClient\MachineId`. Nicht abschaltbar |
| `ext.user.localId` | Lokale Nutzerkennung |
| `ext.xbl.did` | Xbox-Gerätekennung, auch ohne Xbox-Nutzung |
| `ext.protocol.devMake` / `devModel` | Hardwarehersteller und -modell, bei Desktopsystemen das Mainboard |
| `ext.os.ver`, `bootId` | Betriebssystem-Build und Anzahl der Systemstarts |
| `ext.os.expId` | Zugewiesene Experiment- und Rollout-Kennungen |
| `ext.utc.dvcSample` | Sampling-Kohorte des Geräts in Prozent |

## Erhebungsstufe pro Ereignis

Das Feld `ext.privacy.isRequired` entscheidet, welche Einstellung ein Ereignis
verursacht:

- `true` — wird auch auf Stufe **Required** übertragen
- `false` — fließt nur auf Stufe **Optional**

Damit lässt sich für jedes beobachtete Ereignis belegen, ob der
Einstellungsschalter überhaupt Wirkung hätte. MSObserver wertet das Feld
automatisch aus und zeigt es in der Kennungstabelle jeder Payload-Karte.

## Beobachtete Ereignisfamilien

Die folgenden Familien wurden auf Testsystemen beobachtet. Die Liste ist nicht
abschließend — Windows kennt mehrere tausend Ereignistypen.

### Win32kTraceLogging.AppInteractivitySummary

Erzeuger: `dwm.exe`. Das App-Nutzungsprotokoll. Erfasst pro Anwendung unter
anderem Fokusdauer, aktive Eingabezeit und Fenstermetriken. Windows misst
damit, welche Anwendung wie lange und wie intensiv genutzt wurde.

### Aria.\*.Microsoft.WebBrowser.Protobuf.UMA.\*

Erzeuger: `msedgewebview2.exe` und verwandte Prozesse. Browsermetriken der
Chromium-Engine mit vollständigem Hardwareprofil: Arbeitsspeicher, Anzahl und
Auflösung der Bildschirme, Grafikkarte samt Treiberversion, Prozessor,
Installationsdaten, Sprache und zugewiesene Feldexperimente.

Bemerkenswert ist `msedge.webview.host_info`: Das Feld meldet, **welche
Drittanwendung** das WebView-Steuerelement eingebettet hat, samt Name, Version
und Herausgeber. Browsertelemetrie entsteht dadurch auch ohne jede Nutzung von
Edge — es genügt, dass eine installierte Anwendung WebView intern verwendet.
Diese Ereignisse tragen `isRequired: false`, fließen also nur auf Stufe
*Optional*.

### Microsoft.Windows.ApplicationModel.Store.Telemetry.\*

Store-Aufrufe von Anwendungen, etwa Aktualisierungsprüfungen, mit Paketname
und Fehlercode. `isRequired: true`.

### Microsoft.Gaming.XboxPC.\*

Zuverlässigkeitsdaten der Xbox-Anwendung: kontaktierte Hosts, Latenzen,
Abonnementstatus, Sprache und Markt. `isRequired: true`.

### TelClientSynthetic.\*

Betriebsmeldungen des Telemetriedienstes selbst — Lebenszeichen und
Statuswechsel.

## Zugriff auf Inhalte

| Weg | Ergebnis |
| --- | --- |
| Report ohne Payloads (Standard) | Typen, Häufigkeiten, Prozesse — teilbar |
| `-PayloadSamples <n>` | Vollständige Ereignisse im Report, mit Kennungstabelle |
| `Show-EventPayload.ps1` | Interaktive Einzelansicht mit Filter, schreibt nichts |
| Diagnosedaten-Viewer | Offizielle Windows-Oberfläche für dieselben Daten |
