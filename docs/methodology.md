# Methodik und Grenzen

## Messprinzip

MSObserver belegt Datenabflüsse über sechs voneinander unabhängige lokale
Quellen. Keine davon erfordert einen Netzwerkmitschnitt oder eine
Man-in-the-Middle-Konstruktion.

**1. DNS-Ereignisprotokoll** (`Microsoft-Windows-DNS-Client/Operational`,
Ereignis 3006). Zeigt, welche Domains wann aufgelöst wurden. Die zuverlässigste
Netzwerkquelle, weil die Namensauflösung vor dem TLS-Aufbau stattfindet und
damit von Certificate Pinning unberührt bleibt. Bei gesetztem
Beobachtungsfenster auf dieses Fenster begrenzt.

**2. TCP-Verbindungstabelle.** Ordnet Verbindungen dem verantwortlichen Prozess
zu. Ohne Beobachtungsfenster eine Momentaufnahme; mit Fenster wird alle zehn
Sekunden abgetastet und dedupliziert, sodass auch kurzlebige
Upload-Verbindungen erfasst werden.

**3. Geplante Systemaufgaben.** Letzte Ausführung von Compatibility Appraiser,
ProgramDataUpdater, CEIP Consolidator und UpdateOrchestrator. Belegt die
Auslöser der Erhebung.

**4. Registry — Erhebungsschalter.** Welche Erhebung laut Konfiguration aktiv
ist: Diagnosestufe, Werbe-ID, Aktivitätsverlauf, Cloudschutz,
Fehlerberichterstattung.

**5. Registry — Erhebungsmechanismen.** Inventar der eingebauten Mechanismen
und Kennungen: Telemetrie-Geräte-ID, Zwischenablage-Synchronisierung,
Eingabe- und Spracherkennung, Standortdienst, Recall.

**6. Ereignishistorie** (`EventTranscript.db`). Ereignistypen, Häufigkeiten,
erzeugende Prozesse und auf Wunsch die vollständigen Inhalte — gelesen, bevor
sie verschlüsselt übertragen werden.

Ergänzend liest MSObserver die Betriebszähler des Telemetriedienstes aus. Sie
belegen Anzahl und Zeitpunkt tatsächlich erfolgter Übertragungen, unabhängig
von allen anderen Quellen.

Die Zuordnung Domain → Dienst → Datenkategorie erfolgt über
`data/endpoints.json`.

## Eigene Mitschnitte

Wer über die Werkzeugdaten hinaus verifizieren möchte:

```
netsh trace start capture=yes tracefile=C:\temp\net.etl maxsize=512 overwrite=yes
netsh trace stop
```

Die Ablaufverfolgung lässt sich mit [etl2pcapng](https://github.com/microsoft/etl2pcapng)
konvertieren und in Wireshark auswerten. Brauchbare Filter:

```
tls.handshake.extensions_server_name contains "events.data.microsoft.com"
dns.qry.name contains "microsoft.com" || dns.qry.name contains "msedge.net"
```

Für Prozesszuordnung in Echtzeit eignen sich TCPView und Process Monitor aus
den Sysinternals-Werkzeugen.

## Grenzen

**Kein Klartext auf dem Netzwerkweg.** Die Diagnosepipeline verwendet TLS mit
Certificate Pinning. Ein eigener Abfangproxy wird clientseitig abgelehnt.
Sichtbar bleiben Ziel, Zeitpunkt, Volumen und Prozess.

**Inhaltsebene lokal statt im Transit.** Die Ereignisinhalte stammen aus der
lokalen Historie. Zwei Einschränkungen: Sie existiert erst ab ihrer
Aktivierung, und für die Stufe *Optional* hat Microsoft keine abschließende
Feldliste veröffentlicht — für *Required* dagegen schon.

**Momentaufnahmen ohne Beobachtungsfenster.** Verbindungsdaten sind ohne
`-DurationSeconds` Schnappschüsse. Das DNS-Protokoll gleicht Lücken über die
Zeit aus.

**Lastverteiler-Rauschen.** Auslieferungsnetze und Lastverteiler erscheinen in
Mitschnitten, ohne selbst inhaltliches Ziel zu sein.

**Zertifikatsprüfungen sind kein Telemetriehinweis.** Sperrlisten- und
OCSP-Abfragen entstehen bei jeder TLS-Nutzung und richten sich an
verschiedene Zertifizierungsstellen.

## Reproduzierbarkeit

Jeder als `derived` oder `observed` markierte Eintrag benötigt einen Nachweis:
Windows-Version und Edition, Diagnosestufe, Erfassungszeitraum, verwendetes
Werkzeug und den relevanten Auszug. Siehe [CONTRIBUTING.md](../CONTRIBUTING.md).
