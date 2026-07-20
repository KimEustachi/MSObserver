# Feldreferenz

Bedeutung der Felder, die in Diagnoseereignissen auftreten.

**Diese Referenz ist nicht vollständig und wird es nicht sein.** Sie deckt ab,
was auf Testsystemen tatsächlich beobachtet wurde. Das Common Schema kennt
weitere Erweiterungen — unter anderem `ext.web`, `ext.cloud`, `ext.container`,
`ext.receipts`, `ext.m365a` — sowie mehrere tausend ereignisspezifische
`data`-Felder. Ergänzungen sind willkommen.

## Belegklassen

Jede Deutung trägt eine von drei Klassen:

| Klasse | Bedeutung | Anforderung |
| --- | --- | --- |
| `documented` | Von Microsoft beschrieben | Quellenangabe |
| `derived` | Empirisch belegt durch Experiment oder Kreuzabgleich | Nachweis dokumentiert |
| `hypothesis` | Begründete Vermutung, unbestätigt | Nicht als Fakt zitieren |

Hochstufung von `hypothesis` auf `derived` per Pull Request mit
Versuchsbeschreibung und Ergebnis.

## Kopffelder

| Feld | Bedeutung | Beleg |
| --- | --- | --- |
| `ver` | Version des Schemas, aktuell 4.0 | documented |
| `name` | Vollständiger Ereignistypname | documented |
| `time` | Erzeugungszeitpunkt in UTC | documented |
| `iKey` | Zielpipeline. Präfix `o:` steht für den zentralen Collector, `P-ARIA-` für Anwendungstelemetrie | derived — Präfix korreliert durchgehend mit `pgName` |

## ext.utc — Telemetrieclient

| Feld | Bedeutung | Beleg |
| --- | --- | --- |
| `aId` | Aktivitätskennung, verknüpft Ereignisse desselben Vorgangs | documented |
| `raId` | Übergeordnete Aktivitätskennung | documented |
| `epoch`, `seq` | Zähler zur Reihenfolge- und Verlustprüfung | documented |
| `pgName` | Kurzname der Providergruppe, etwa `WINCORE`, `WINEXT`, `ARIA` | documented |
| `eventFlags` | Bitmaske zu Übertragung und Verarbeitung | documented |
| `sqmId`, `stId`, `bSeq`, `cat` | Gerätekennung in Altform, Auslösepunkt, Puffersequenz, Schlüsselwortmaske | documented |
| `dvcSample` | Sampling-Kohorte in Prozent | **derived** — der Wert erscheint im selben Datenbestand als `msedge.sampling.device_sample_rate` wieder |
| `shellId` | Konstante Kennung, vermutlich Betriebssystem- oder Shell-Version | hypothesis |
| `edition` | Numerischer Editionscode | hypothesis |
| `flags` | Interne Verarbeitungsmaske, Einzelbits unbekannt | hypothesis |

## ext.privacy — Datenschutzklassifizierung

| Feld | Bedeutung | Beleg |
| --- | --- | --- |
| `isRequired` | `true` = auch auf Stufe Required, `false` = nur auf Optional | documented |
| `dataType` | Bitmaske der Datenkategorien, siehe unten | documented |
| `privTags` | Spiegelung der Kategorien auf Feldebene | **derived** — im Datenbestand stets identisch mit `dataType` |
| `dataCategory`, `product` | Grobzuordnung | hypothesis |

### Kategoriemaske

| Wert | Hexadezimal | Kategorie |
| --- | --- | --- |
| 2 | 0x2 | Browserverlauf |
| 2048 | 0x800 | Gerätekonnektivität und -konfiguration |
| 131072 | 0x20000 | Eingabe, Tinte und Sprache |
| 16777216 | 0x1000000 | Produkt- und Dienstleistungsperformance |
| 33554432 | 0x2000000 | Produkt- und Dienstnutzung |
| 2147483648 | 0x80000000 | Software-Setup und Inventar |

Kombinationen sind Summen. Der Wert `2197817344` entspricht
`0x83000000` — Inventar, Nutzung und Performance zugleich. MSObserver
dekodiert das Feld automatisch.

## ext.mscv

`cV` ist der Correlation Vector. Er verkettet zusammengehörige Ereignisse über
Dienstgrenzen hinweg. Die Spezifikation ist öffentlich unter
`github.com/microsoft/CorrelationVector`. (documented)

## ext.os

| Feld | Bedeutung | Beleg |
| --- | --- | --- |
| `name`, `ver` | Betriebssystem und vollständiger Build-String | documented |
| `bootId` | Fortlaufender Zähler der Systemstarts | derived — Experiment 1 |
| `expId` | Zugewiesene Experiment- und Rollout-Kennungen. Präfixe: `RS:` Release, `FX:` Funktionsexperiment, `MD:`, `ME:`, `PD:`, `CD:` weitere Steuerungen. Die Kombination ist gerätespezifisch und wirkt als zusätzliches Unterscheidungsmerkmal | Deutung der Präfixe: hypothesis; Gerätespezifik: derived |

## ext.app

| Feld | Bedeutung | Beleg |
| --- | --- | --- |
| `id` | Anwendungsidentität. Präfix `U:` für paketierte Anwendungen mit vollem Paketnamen, `W:` für klassische Win32-Programme mit Hashkennung | derived |
| `ver` | Version samt Erstellungszeitpunkt und Binärdatei | derived |
| `is1P` | 1 kennzeichnet Anwendungen von Microsoft selbst | hypothesis — Experiment 4 |
| `asId` | Sitzungszähler der Anwendung | hypothesis — Experiment 3 |

## ext.device und ext.protocol

| Feld | Bedeutung | Beleg |
| --- | --- | --- |
| `device.localId` | Telemetrie-Geräte-ID, identisch mit `HKLM\SOFTWARE\Microsoft\SQMClient\MachineId` | documented; Identität zusätzlich derived durch Registryabgleich |
| `device.deviceClass` | Geräteklasse, etwa `Windows.Desktop` | documented |
| `protocol.devMake`, `devModel` | Hardwarehersteller und -modell | documented |
| `protocol.ticketKeys` | Verweise auf Authentifizierungstickets | hypothesis — Experiment 7 |

## ext.user und ext.xbl

| Feld | Bedeutung | Beleg |
| --- | --- | --- |
| `user.localId` | Lokale Nutzerkennung | hypothesis — Experiment 2 |
| `xbl.did` | Xbox-Gerätekennung | Deutung: hypothesis; Übertragung ohne Xbox-Nutzung: **derived** |
| `xbl.sbx` | Umgebung, `RETAIL` für Produktivsysteme | derived |

## Weitere Erweiterungen

| Feld | Bedeutung | Beleg |
| --- | --- | --- |
| `ext.net.cost`, `type` | Netzwerktyp und Taktung, steuert das Übertragungsverhalten | documented |
| `ext.loc.tz` | Zeitzonenversatz | documented |
| `ext.metadata.f` | Typbeschreibung der Nutzdatenfelder | derived — Feldnamen decken sich mit `data` |
| `ext.ariaMD` | Feldbeschreibungen der Anwendungstelemetrie | derived |

## data — die Nutzdaten

Ereignisspezifisch; beobachtete Familien beschreibt
[payload-anatomy.md](payload-anatomy.md). Drei Faustregeln:

- `data` beschreibt, **was** geschehen ist. Der Umschlag beschreibt **wer**,
  **wo** und **womit**. Die Kennungen stecken fast immer im Umschlag.
- `name_hash`-Felder in Browsermetriken sind gehashte Metriknamen. Ohne
  Zuordnungstabelle sind sie nicht auflösbar.
- Zeitstempel als Zeichenkette, etwa `install_date`, sind Sekunden seit 1970
  und meist auf Tagesgrenzen gerundet.

## Forschungsliste

Offene Hypothesen mit jeweils einem Experiment, das auf einem einzelnen
Rechner durchführbar ist. Ergebnisse mit Vorher-Nachher-Vergleich als Pull
Request einreichen; das Feld wird dann auf `derived` hochgestuft.

| Nr. | Feld | Experiment |
| --- | --- | --- |
| 1 | `os.bootId` | Ereignisse vor und nach einem Neustart vergleichen. Erhöht sich der Wert um genau eins? |
| 2 | `user.localId` | Zweites lokales Benutzerkonto anlegen und dort Ereignisse erzeugen. Andere Nutzerkennung bei gleicher Geräte-ID? |
| 3 | `app.asId` | Anwendung schließen und neu starten. Erhöht sich der Zähler? Was geschieht nach einem Neustart? |
| 4 | `app.is1P` | Ereignis einer Drittanbieteranwendung mit Telemetrie-SDK suchen. Steht dort `0`? |
| 5 | `utc.shellId` | Wert auf zwei Geräten mit gleichem Build vergleichen, dann mit abweichendem Build. Konstant je Build oder je Gerät? |
| 6 | `utc.flags` | Gleiche Ereignistypen auf Stufe Required und Optional vergleichen. Welche Bits ändern sich? |
| 7 | `protocol.ticketKeys` | Mit und ohne angemeldetes Microsoft-Konto vergleichen. Entfällt das Feld ohne Konto? |
