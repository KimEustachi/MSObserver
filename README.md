# MSObserver

**Sehen, was Windows über einen sendet.** MSObserver macht sichtbar, welche
Daten ein Windows-Gerät an Microsoft überträgt: was erhoben wird, wohin es
fließt, wodurch es ausgelöst wird und was konkret in den Datenpaketen steht.

Das Werkzeug beobachtet ausschließlich. Es blockiert nichts, verändert keine
Systemeinstellungen und überträgt selbst keinerlei Daten. Alle Ergebnisse
bleiben als lokale Dateien auf dem eigenen Rechner.

```powershell
git clone https://github.com/KimEustachi/MSObserver.git
cd MSObserver\src
.\Invoke-MSObserver.ps1 -DurationSeconds 300 -OpenReport
```

---

## Warum

Für Windows existieren zahlreiche Werkzeuge, die Telemetrie *abschalten*.
Es fehlt eines, das sie zuerst *erklärt*. Wer nicht weiß, welche Daten sein
Gerät sendet, kann weder begründet abschalten noch begründet zustimmen.

MSObserver liefert diese Grundlage — und trennt dabei konsequent zwischen
belegten Fakten und Vermutungen. Jeder Endpunkt und jedes Datenfeld trägt eine
Belegklasse: von Microsoft dokumentiert, empirisch nachgewiesen oder
ausdrücklich als Hypothese markiert.

## Was der Report zeigt

| Sektion | Inhalt |
| --- | --- |
| Konfiguration | Effektive Diagnosestufe, Werbe-ID, Aktivitätsverlauf, Defender-Cloudschutz |
| Erhebungsmechanismen | Geräte-ID, Zwischenablage-Synchronisierung, Eingabe- und Spracherkennung, Standort, Recall — mit Status und Rohwerten |
| Diagnoseereignisse | Welche Ereignistypen erzeugt werden, wie oft, von welchen Prozessen — optional mit vollständigem Inhalt |
| Übertragungsnachweis | Betriebszähler des Telemetriedienstes: Anzahl und Zeitpunkt tatsächlicher Uploads |
| Endpunkte | Beobachtete Zieldomains, zugeordnet zu Dienst, Datenkategorie und Auslöser |
| Systemaufgaben | Letzte Ausführung der Aufgaben, die Datenerhebung anstoßen |

Der Report ist eine einzelne HTML-Datei mit Suche, Sortierung und
Syntaxhervorhebung — ohne externe Ressourcen, vollständig offline nutzbar.

## Installation

Voraussetzung ist Windows 10 oder 11 mit Windows PowerShell 5.1
(vorinstalliert) oder PowerShell 7.

Für die Auswertung der Ereignisinhalte zusätzlich:

1. **Diagnosedatenanzeige aktivieren** — Einstellungen → Datenschutz und
   Sicherheit → Diagnose und Feedback → *Diagnosedaten anzeigen*.
   Windows legt die Ereignishistorie erst ab diesem Zeitpunkt an.
2. **SQLite installieren** — `winget install SQLite.SQLite`

Fehlt eine Voraussetzung, weist der Report die betreffende Sektion als
übersprungen aus und nennt den Grund.

## Verwendung

```powershell
# Einmalig als Administrator: Namensauflösung protokollieren
.\Invoke-MSObserver.ps1 -EnableDnsLog -NoReport

# Standardlauf: alle Module, fünf Minuten beobachten, Report öffnen
.\Invoke-MSObserver.ps1 -DurationSeconds 300 -OpenReport

# Nur Konfigurationszustand, ohne Wartezeit
.\Invoke-MSObserver.ps1 -Modules Registry,Tracking

# Mit vollständigen Ereignisinhalten
.\Invoke-MSObserver.ps1 -DurationSeconds 300 -PayloadSamples 5 -OpenReport
```

| Parameter | Wirkung |
| --- | --- |
| `-Modules` | Auswahl aus `Registry`, `Tracking`, `Tcp`, `Tasks`, `Dns`, `Diagnosis`, `DiagnosisEvents`. Standard: alle |
| `-DurationSeconds` | Beobachtungsfenster. Verbindungen werden periodisch abgetastet, Namensauflösungen auf das Fenster begrenzt |
| `-PayloadSamples` | Anzahl vollständiger Ereignisinhalte im Report. Standard 0 |
| `-EnableDnsLog` | Aktiviert das DNS-Ereignisprotokoll (Administrator, einmalig) |
| `-NoReport` / `-OpenReport` | Report unterdrücken beziehungsweise direkt öffnen |

Einzelne Ereignisse lassen sich interaktiv untersuchen:

```powershell
.\Show-EventPayload.ps1 -ListTypes
.\Show-EventPayload.ps1 -EventName AppInteractivitySummary -Last 2
```

## Datenschutz in eigener Sache

Zwei Dinge, die vor der Weitergabe von Ergebnissen zu beachten sind:

- Ergebnisdateien enthalten Hostname und Prozesspfade. Das Verzeichnis
  `src/output/` ist deshalb von der Versionskontrolle ausgeschlossen.
- Mit `-PayloadSamples` kommen Gerätekennungen hinzu, unter anderem die
  eindeutige Telemetrie-Geräte-ID. Solche Reports gehören nicht in ein
  öffentliches Repository.

## Grenzen

Der Datenverkehr zur Diagnosepipeline ist TLS-verschlüsselt und nutzt
Certificate Pinning. Ein eigener Abfangproxy scheitert daran. Auf dem
Netzwerkweg sind deshalb nur Ziel, Zeitpunkt, Häufigkeit und Prozess sichtbar.

Die Inhaltsebene erschließt MSObserver stattdessen lokal: aus der
Ereignishistorie, die Windows vor der Übertragung anlegt. Zwei Einschränkungen
bleiben — die Historie existiert erst ab ihrer Aktivierung, und für die Stufe
*Optional* hat Microsoft keine abschließende Feldliste veröffentlicht.

Details in [docs/methodology.md](docs/methodology.md).

## Dokumentation

- [Methodik und Grenzen](docs/methodology.md) — wie gemessen wird und was nicht messbar ist
- [Aufbau eines Diagnoseereignisses](docs/payload-anatomy.md) — Struktur und beobachtete Ereignisfamilien
- [Feldreferenz](docs/payload-fields.md) — Bedeutung der einzelnen Felder, nach Belegklasse
- [Bedeutung der Datenkategorien](docs/data-categories.md) — allgemeinverständliche Einordnung
- [Editionsunterschiede](docs/editions.md) — Home, Pro, Education, Enterprise

## Mitwirken

Die Endpunktdatenbank und die Feldreferenz leben von Beiträgen. Erwünscht sind
insbesondere neue Endpunkte mit Nachweis und abgeschlossene Experimente aus der
Forschungsliste in der Feldreferenz. Anforderungen an Belege:
[CONTRIBUTING.md](CONTRIBUTING.md).

## Lizenz

[MIT](LICENSE)
