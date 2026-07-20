# Bedeutung der Datenkategorien

MSObserver ordnet jeden beobachteten Endpunkt einer von sieben Kategorien zu.
Nicht jeder Kontakt zu Microsoft ist Überwachung — die Unterscheidung ist der
Kern einer ehrlichen Bewertung.

## Sicherheitsfunktion

Der Defender-Cloudschutz übermittelt Prüfsummen und Metadaten verdächtiger
Dateien zum Abgleich mit der Cloudreputation; bei aktivierter
Beispielübermittlung auch die Datei selbst. SmartScreen prüft Adressen und
heruntergeladene Programme gegen Reputationslisten.

Beides sind reale Datenflüsse. Sie existieren jedoch, um das Gerät zu
schützen. Wer sie unterbindet, tauscht Datensparsamkeit gegen Schutzverlust.
MSObserver macht den Fluss sichtbar, wertet ihn aber als Schutzfunktion.

## Update und Systemfunktion

Windows Update überträgt den Aktualisierungsstand und Hardwarekennungen zur
Treiberzuordnung. Die Aktivierung übermittelt eine Hardwareprüfsumme. Die
Konnektivitätsprüfung stellt mit einer minimalen Anfrage fest, ob eine
Internetverbindung besteht. Funktional notwendig, zweckgebunden, geringer
Umfang.

## Telemetrie

Der Kern dessen, was umgangssprachlich Windows-Telemetrie heißt:

**Diagnosedienst.** Anwendungs- und Funktionsnutzung, Startzeiten,
Gerätekonfiguration, eindeutige Gerätekennung. Der Umfang hängt von der
eingestellten Diagnosestufe ab.

**Fehlerberichterstattung.** Absturzberichte mit Modulnamen und
Aufrufverläufen. Speicherabbilder können Ausschnitte des Arbeitsspeichers des
abgestürzten Programms enthalten — und damit potenziell persönliche Daten, die
gerade verarbeitet wurden.

**Kompatibilitätsprüfung.** Inventar installierter Programme und Treiber zur
Beurteilung der Upgradefähigkeit. Läuft als geplante Aufgabe, auch nachts.

**Aktivitätsverlauf.** Bei angemeldetem Microsoft-Konto und aktiviertem
Verlauf werden geöffnete Anwendungen und Dokumente mit Zeitstempel
synchronisiert.

## Inhaltsdienst

Suche, Widgets, Cloudspeicher, Wetter. Hier folgt der Datenfluss aus der
Nutzung: Wer im Startmenü sucht, sendet die Eingabe an die Websuche; wer
Cloudspeicher synchronisiert, überträgt Dateiinhalte. Der Punkt ist
Bewusstheit — vielen ist nicht klar, dass die Suche im Startmenü zugleich eine
Websuche ist.

## Werbung und Empfehlung

Sperrbildschirminhalte, Startmenüvorschläge, Widget-Anzeigen. Übertragen
werden Geräteattribute und Interaktionssignale, um Werbe- und
Empfehlungsinhalte auszuspielen. Ein Nutzen für die anwendende Person ist
nicht erforderlich; die Werbe-ID verknüpft die Signale anwendungsübergreifend.

## Konto

Anmeldung und Tokenerneuerung beim Microsoft-Konto. Notwendig, sobald ein
Konto verwendet wird.

## Einordnung

Für die Stufe *Optional* existiert keine vollständige öffentliche Liste der
übertragenen Felder. MSObserver schließt diese Lücke lokal: Es zeigt, welche
Ereignistypen mit welcher Häufigkeit von welchen Prozessen erzeugt werden, und
auf Wunsch deren vollständigen Inhalt — jeweils vor der Übertragung, auf dem
eigenen Gerät.
