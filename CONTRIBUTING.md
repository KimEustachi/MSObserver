# Mitwirken

Beiträge sind willkommen. Das Projekt lebt von zwei Datenbeständen, die sich
gemeinsam pflegen lassen: der Endpunktdatenbank und der Feldreferenz.

Grundregel: **Behauptungen ohne Nachweis werden nicht übernommen.** Die saubere
Trennung zwischen Beleg und Vermutung ist der Wert dieses Projekts.

## Endpunkte ergänzen

Neue Einträge in `data/endpoints.json` folgen dem Schema in
`data/schema.json`; die Prüfung läuft automatisch.

Pflichtangaben je nach Belegklasse:

- `documented` — Feld `source` mit Verweis auf die Microsoft-Dokumentation
- `observed` oder `community-reported` — Nachweis im Pull Request:
  Windows-Version und Edition, Diagnosestufe, Erfassungswerkzeug,
  Erfassungszeitraum, relevanter Auszug mit auslösendem Prozess und, falls
  ereignisgesteuert, die Schritte zur Reproduktion

Weiteres:

- In `categories` gehört nur, was aus Dokumentation oder Mitschnitt hervorgeht.
  Vermutungen kommen gekennzeichnet in `notes`.
- `severity` konservativ wählen. Schutz- und Wartungsverkehr ist keine
  Telemetrie, nur weil das Ziel bei Microsoft liegt.

Nicht aufgenommen werden Zertifikatsprüfungen beliebiger Stellen, reine
Auslieferungs- und Lastverteilernamen ohne eigenen Dienst sowie Endpunkte von
Drittsoftware. Der Betrachtungsgegenstand ist Windows samt mitgelieferter
Microsoft-Dienste.

## Feldreferenz erweitern

`docs/payload-fields.md` enthält am Ende eine Forschungsliste: offene
Hypothesen mit jeweils einem konkreten Experiment, das auf einem einzelnen
Rechner durchführbar ist.

Wer eines davon abschließt, reicht ein: Versuchsaufbau, Vorher-Nachher-Werte
und die Schlussfolgerung. Das Feld wird dann von `hypothesis` auf `derived`
hochgestuft.

Ebenso willkommen sind bisher nicht dokumentierte Felder oder Erweiterungen,
die auf anderen Systemen auftreten.

## Vor dem Einreichen

Ergebnisdateien und Reports enthalten Hostname, Prozesspfade und — bei
aktivierten Payload-Beispielen — Gerätekennungen. Auszüge in Pull Requests
bitte auf das Nötige kürzen und Kennungen ersetzen.

## Code

- Windows PowerShell 5.1 bleibt Zielplattform; keine Konstrukte, die nur unter
  PowerShell 7 laufen
- Kommentare im Code auf Englisch, Ausgaben für Anwendende auf Deutsch
- Quelldateien ohne Sonderzeichen; deutsche Texte im HTML-Report als Entities
- Vor dem Pull Request: `.\tests\Invoke-Tests.ps1`

Die Tests nutzen Pester 5. Windows liefert nur Pester 3.4 mit, das diese Syntax
nicht versteht — der Runner prüft die Version und nennt den Installationsbefehl:

```powershell
Install-Module Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck -Scope CurrentUser
```

## Scope

MSObserver blockiert nichts. Dafür gibt es O&O ShutUp10, privacy.sexy und
WindowsSpyBlocker — die machen ihre Sache gut, und ein weiteres Werkzeug dieser
Art braucht niemand. Hier geht es um die Frage davor: zu wissen, was man da
eigentlich abschaltet. Pull Requests, die Blockierfunktionen einbauen, lehne ich
ab. Im Report auf ein passendes Werkzeug zu verweisen, ist dagegen in Ordnung.

Außerdem sendet MSObserver selbst nichts. Der Report lädt keine Schriften von
einem CDN, ruft keine Statistik ab und prüft nicht auf Updates. Ein Werkzeug,
das Telemetrie untersucht und dabei eigene erzeugt, wäre schwer zu erklären.
