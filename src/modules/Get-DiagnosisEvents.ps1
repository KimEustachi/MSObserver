function Resolve-SqliteExecutable {
    <#
    .SYNOPSIS
        Locates sqlite3.exe, including the winget link directory.
    .NOTES
        winget updates the PATH only for new shells, so the link directory is
        checked as a fallback to avoid a required restart.
    #>
    [CmdletBinding()]
    param()

    $command = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $wingetLink = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\sqlite3.exe'
    if (Test-Path $wingetLink) { return $wingetLink }

    return $null
}

function Get-DiagnosisEvents {
    <#
    .SYNOPSIS
        Analyses the local diagnostic event history (EventTranscript.db).
    .DESCRIPTION
        Reports which event types were produced, how often, and by which
        processes. These are the contents uploaded to the telemetry endpoints,
        readable locally before encryption.
    .PARAMETER IncludePayloadSamples
        Number of most recent events to include verbatim. Off by default because
        payloads contain device identifiers.
    .NOTES
        Requires "Diagnosedaten anzeigen" to be enabled in Windows settings
        (creates the database) and sqlite3 to be available.
    #>
    [CmdletBinding()]
    param(
        [int]$TopEvents = 25,
        [int]$TopBinaries = 10,
        [int]$IncludePayloadSamples = 0
    )

    $database = Join-Path $env:ProgramData 'Microsoft\Diagnosis\EventTranscript\EventTranscript.db'
    if (-not (Test-Path $database)) {
        return @{ skipped = 'Ereignishistorie nicht vorhanden. In den Windows-Einstellungen unter Datenschutz > Diagnose die Anzeige der Diagnosedaten aktivieren und Sammelzeit abwarten.' }
    }

    $sqlite = Resolve-SqliteExecutable
    if (-not $sqlite) {
        return @{ skipped = 'sqlite3 nicht gefunden. Installation: winget install SQLite.SQLite' }
    }

    # Work on a copy: DiagTrack may hold a lock on the live database.
    $temp = Join-Path $env:TEMP 'msobserver-eventtranscript.db'
    try {
        Copy-Item $database $temp -Force -ErrorAction Stop
    } catch {
        return @{ skipped = "Datenbank nicht kopierbar: $($_.Exception.Message)" }
    }

    try {
        $total = [int](& $sqlite $temp 'SELECT COUNT(*) FROM events_persisted;' 2>$null)

        $eventsJson = & $sqlite -json $temp @"
SELECT full_event_name AS eventName, COUNT(*) AS count
FROM events_persisted GROUP BY full_event_name
ORDER BY count DESC LIMIT $TopEvents;
"@ 2>$null

        $binariesJson = & $sqlite -json $temp @"
SELECT logging_binary_name AS binary, COUNT(*) AS count
FROM events_persisted GROUP BY logging_binary_name
ORDER BY count DESC LIMIT $TopBinaries;
"@ 2>$null

        $rangeJson = & $sqlite -json $temp 'SELECT MIN(timestamp) AS minTs, MAX(timestamp) AS maxTs FROM events_persisted;' 2>$null

        $from = $null; $to = $null
        if ($rangeJson) {
            # sqlite3 returns an array of lines; join before parsing (PowerShell 5.1).
            $range = (($rangeJson -join '') | ConvertFrom-Json) | Select-Object -First 1
            try {
                # timestamp is FILETIME (100 ns intervals since 1601, UTC)
                $from = [DateTime]::FromFileTimeUtc([long]$range.minTs).ToString('o')
                $to   = [DateTime]::FromFileTimeUtc([long]$range.maxTs).ToString('o')
            } catch { }
        }

        $samples = @()
        if ($IncludePayloadSamples -gt 0) {
            $sampleJson = & $sqlite -json $temp @"
SELECT full_event_name AS eventName, timestamp AS ts,
       logging_binary_name AS binary, payload
FROM events_persisted ORDER BY timestamp DESC LIMIT $IncludePayloadSamples;
"@ 2>$null
            if ($sampleJson) {
                $samples = @((($sampleJson -join '') | ConvertFrom-Json) | ForEach-Object {
                    [pscustomobject]@{
                        eventName = $_.eventName
                        timeUtc   = $(try { [DateTime]::FromFileTimeUtc([long]$_.ts).ToString('o') } catch { $null })
                        binary    = $_.binary
                        payload   = $_.payload
                    }
                })
            }
        }

        [ordered]@{
            totalEvents    = $total
            timeRange      = [ordered]@{ from = $from; to = $to }
            topEvents      = if ($eventsJson) { @((($eventsJson -join '') | ConvertFrom-Json)) } else { @() }
            topBinaries    = if ($binariesJson) { @((($binariesJson -join '') | ConvertFrom-Json)) } else { @() }
            samplePayloads = $samples
        }
    } catch {
        @{ skipped = "Auswertung fehlgeschlagen: $($_.Exception.Message)" }
    } finally {
        Remove-Item $temp -Force -ErrorAction SilentlyContinue
    }
}
