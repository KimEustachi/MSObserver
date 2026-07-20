<#
.SYNOPSIS
    Displays complete payloads of individual diagnostic events.

.DESCRIPTION
    Local inspection tool. Reads the Windows diagnostic event history and
    prints full event payloads as formatted JSON - field by field.

    The output contains device identifiers and file paths. Nothing is written
    to disk unless -OutFile is used, and nothing is transmitted.

.PARAMETER EventName
    Filter on event type (substring match, e.g. 'AppInteractivity').

.PARAMETER Last
    Number of most recent events to show. Default: 3.

.PARAMETER ListTypes
    List available event types with counts instead of showing payloads.

.PARAMETER OutFile
    Optionally write the output to a file. The file will contain identifiers.

.EXAMPLE
    .\Show-EventPayload.ps1 -Last 5

.EXAMPLE
    .\Show-EventPayload.ps1 -EventName AppInteractivitySummary -Last 2

.EXAMPLE
    .\Show-EventPayload.ps1 -ListTypes
#>
[CmdletBinding()]
param(
    [string]$EventName,
    [int]$Last = 3,
    [switch]$ListTypes,
    [string]$OutFile
)

Set-StrictMode -Version 3

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path (Join-Path $scriptRoot 'modules') 'Get-DiagnosisEvents.ps1')

$database = Join-Path $env:ProgramData 'Microsoft\Diagnosis\EventTranscript\EventTranscript.db'
if (-not (Test-Path $database)) {
    Write-Warning 'Ereignishistorie nicht vorhanden. In den Windows-Einstellungen unter Datenschutz > Diagnose die Anzeige der Diagnosedaten aktivieren.'
    return
}

$sqlite = Resolve-SqliteExecutable
if (-not $sqlite) {
    Write-Warning 'sqlite3 nicht gefunden. Installation: winget install SQLite.SQLite'
    return
}

$temp = Join-Path $env:TEMP 'msobserver-payload-view.db'
Copy-Item $database $temp -Force

try {
    if ($ListTypes) {
        Write-Host ''
        Write-Host '  Vorhandene Ereignistypen' -ForegroundColor Cyan
        Write-Host ''
        & $sqlite -header -column $temp @"
SELECT full_event_name AS Ereignis, COUNT(*) AS Anzahl
FROM events_persisted GROUP BY full_event_name ORDER BY Anzahl DESC;
"@
        return
    }

    $where = if ($EventName) {
        $safe = $EventName -replace "'", "''"
        "WHERE full_event_name LIKE '%$safe%'"
    } else { '' }

    $raw = & $sqlite -json $temp @"
SELECT full_event_name AS eventName, timestamp AS ts,
       logging_binary_name AS binary, payload
FROM events_persisted $where
ORDER BY timestamp DESC LIMIT $Last;
"@ 2>$null

    if (-not $raw) {
        $suffix = if ($EventName) { " fuer Filter '$EventName'" } else { '' }
        Write-Warning "Keine Ereignisse gefunden$suffix."
        return
    }

    # sqlite3 returns an array of lines; join before parsing (PowerShell 5.1).
    $rows = @((($raw -join '') | ConvertFrom-Json))

    $buffer = New-Object System.Text.StringBuilder
    foreach ($row in $rows) {
        $when = try {
            [DateTime]::FromFileTimeUtc([long]$row.ts).ToString('yyyy-MM-dd HH:mm:ss') + ' UTC'
        } catch { $row.ts }

        $header = "`n  $($row.eventName)`n  $when | $($row.binary)`n"
        Write-Host $header -ForegroundColor Cyan
        [void]$buffer.AppendLine($header)

        $pretty = try {
            $row.payload | ConvertFrom-Json | ConvertTo-Json -Depth 12
        } catch { $row.payload }

        Write-Host $pretty
        [void]$buffer.AppendLine($pretty)
    }

    if ($OutFile) {
        $buffer.ToString() | Set-Content -Path $OutFile -Encoding UTF8
        Write-Host ''
        Write-Host "  Gespeichert: $OutFile" -ForegroundColor Green
        Write-Host '  Die Datei enthaelt Geraetekennungen. Nicht weitergeben.' -ForegroundColor Yellow
    }
} finally {
    Remove-Item $temp -Force -ErrorAction SilentlyContinue
}
