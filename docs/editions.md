# Editionsunterschiede

Die Windows-Edition bestimmt, welche Endpunkte aktiv sind und wie weit sich die
Datenerhebung absenken lässt.

## Diagnosestufen

| Stufe | Wert | Home | Pro | Education | Enterprise |
| --- | --- | --- | --- | --- | --- |
| Security | 0 | — | wirkt als 1 | ja | ja |
| Required | 1 | ja | ja | ja | ja |
| Optional | 3 | Standard | Standard | ja | ja |

**Home** kennt keine Gruppenrichtlinie für die Diagnosestufe. Steuerbar ist
nur der Schalter in den Einstellungen, der zwischen Required und Optional
wechselt. Stufe 0 ist nicht erreichbar.

**Pro** besitzt den Richtlinienwert, behandelt `0` jedoch wie `1`. Die
niedrigste wirksame Stufe ist Required.

**Education und Enterprise** setzen Stufe 0 wirksam um. Es verbleiben im
Wesentlichen Windows Update, Cloudschutz und Lizenzierung.

Maßgebliche Registrierungspfade:

```
HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection
```

MSObserver liest beide und weist den effektiven Wert aus.

## Umfang der Endpunkte

**Home und Pro** enthalten den vollständigen Verbrauchersatz: Spotlight,
Nachrichten-Widgets, Xbox, Cloudspeicher für Privatkunden, Websuche im
Startmenü. Pro zeigt in Microsofts eigener Leerlaufmessung sogar die längste
Endpunktliste.

**Education** entspricht weitgehend Enterprise, ergänzt um einzelne
Verbraucherdienste.

**Enterprise** lässt sich per Richtlinie auf einen dokumentierten Minimalsatz
reduzieren. Diese Liste ist der kleinste offiziell beschriebene Fußabdruck von
Windows.

## Nicht abschaltbar

In allen Editionen verbleiben:

- Zertifikatsprüfungen gegen Sperrlisten und OCSP, gerichtet an verschiedene
  Zertifizierungsstellen
- Lizenzierung und Aktivierung
- Konnektivitätsprüfung, umkonfigurierbar, aber nicht sinnvoll entfernbar
- die Telemetrie-Geräte-ID als Kennung in Diagnoseereignissen
