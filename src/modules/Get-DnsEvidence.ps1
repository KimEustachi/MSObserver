function Enable-DnsClientLog {
    <#
    .SYNOPSIS
        Enables the DNS client operational event log (requires admin).
    .NOTES
        This is the only write operation in MSObserver. It changes event log
        configuration only - no telemetry setting is modified. The log records
        from the moment it is enabled; there is no retroactive data.
    #>
    [CmdletBinding()]
    param()

    & wevtutil.exe sl 'Microsoft-Windows-DNS-Client/Operational' /e:true 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host '  DNS-Protokoll aktiviert. Eintraege sammeln sich ab jetzt an.'
    } else {
        Write-Warning 'DNS-Protokoll konnte nicht aktiviert werden.'
    }
}

function Get-DnsEvidence {
    <#
    .SYNOPSIS
        Reads DNS queries (event 3006) from the DNS client operational log.
    .DESCRIPTION
        This is the most reliable network source: name resolution happens before
        the TLS handshake, so certificate pinning does not obscure it.
    .PARAMETER Since
        Only events from this point in time. Used for observation windows.
    #>
    [CmdletBinding()]
    param(
        [int]$MaxEvents = 2000,
        [datetime]$Since = [datetime]::MinValue
    )

    $log = 'Microsoft-Windows-DNS-Client/Operational'

    # wevtutil returns an array of lines; join before matching (PowerShell 5.1).
    $config = (& wevtutil.exe gl $log 2>$null) -join "`n"
    if ($config -notmatch 'enabled:\s*true') {
        return @{ skipped = 'DNS-Protokoll ist nicht aktiviert. Einmalig mit -EnableDnsLog starten und Zeit vergehen lassen.' }
    }

    $filter = @{ LogName = $log; Id = 3006 }
    if ($Since -gt [datetime]::MinValue) { $filter.StartTime = $Since }

    try {
        Get-WinEvent -FilterHashtable $filter -MaxEvents $MaxEvents -ErrorAction Stop |
            ForEach-Object {
                [pscustomobject]@{
                    time  = $_.TimeCreated.ToString('o')
                    query = $_.Properties[0].Value
                }
            } |
            Group-Object query |
            ForEach-Object {
                $sorted = $_.Group | Sort-Object time
                [pscustomobject]@{
                    domain    = $_.Name
                    count     = $_.Count
                    firstSeen = ($sorted | Select-Object -First 1).time
                    lastSeen  = ($sorted | Select-Object -Last 1).time
                }
            }
    } catch {
        if ($_.Exception.Message -match 'No events were found|Es wurden keine Ereignisse') {
            return @{ skipped = 'Protokoll aktiv, aber keine Eintraege im Zeitfenster. Sammelzeit abwarten oder Fenster vergroessern.' }
        }
        @{ skipped = "Ereignisse nicht lesbar: $($_.Exception.Message)" }
    }
}
