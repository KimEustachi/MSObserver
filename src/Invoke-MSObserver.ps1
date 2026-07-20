<#
.SYNOPSIS
    MSObserver - collects local evidence of telemetry data flows to Microsoft.

.DESCRIPTION
    Read-only tool. Changes nothing on the system, blocks nothing, transmits nothing.
    All results are written to local files only.

    Without administrator rights: Registry, Tracking, Tcp, Tasks.
    With administrator rights, additionally: Dns, Diagnosis, DiagnosisEvents.

.PARAMETER Modules
    Which modules to run. Default: All.
    Available: Registry, Tracking, Tcp, Tasks, Dns, Diagnosis, DiagnosisEvents

.PARAMETER DurationSeconds
    Observation window in seconds. During the window, TCP connections are sampled
    periodically instead of captured once; DNS queries are filtered to the window.
    0 = single snapshot.

.PARAMETER EnableDnsLog
    Enables the DNS client operational event log if disabled (requires admin).
    The log only records from the moment it is enabled.

.PARAMETER PayloadSamples
    Number of most recent event payloads included verbatim in evidence and report
    (default 0 = off). Payloads contain device identifiers - do not share such files.

.PARAMETER NoReport
    Suppresses automatic HTML report generation.

.PARAMETER OpenReport
    Opens the generated report in the default browser.

.PARAMETER OutputPath
    Target directory. Default: .\output

.EXAMPLE
    .\Invoke-MSObserver.ps1 -DurationSeconds 300 -OpenReport

.EXAMPLE
    .\Invoke-MSObserver.ps1 -Modules Dns,Tcp -DurationSeconds 600

.LINK
    https://github.com/
#>
[CmdletBinding()]
param(
    [ValidateSet('All','Registry','Tracking','Tcp','Tasks','Dns','Diagnosis','DiagnosisEvents')]
    [string[]]$Modules = @('All'),

    [ValidateRange(0, 86400)]
    [int]$DurationSeconds = 0,

    [switch]$EnableDnsLog,

    [ValidateRange(0, 20)]
    [int]$PayloadSamples = 0,

    [switch]$NoReport,
    [switch]$OpenReport,
    [string]$OutputPath
)

Set-StrictMode -Version 3
$ErrorActionPreference = 'Continue'

# $PSScriptRoot is empty while parameter defaults are evaluated in Windows
# PowerShell 5.1, so path resolution happens here in the script body.
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $OutputPath) { $OutputPath = Join-Path $scriptRoot 'output' }

$moduleNames = @(
    'Get-TcpEvidence', 'Get-TaskEvidence', 'Get-RegistryState', 'Get-DnsEvidence',
    'Get-DiagnosisState', 'Get-TrackingMechanisms', 'Get-DiagnosisEvents'
)
foreach ($m in $moduleNames) {
    . (Join-Path (Join-Path $scriptRoot 'modules') "$m.ps1")
}

if ($Modules -contains 'All') {
    $Modules = @('Registry','Tracking','Tcp','Tasks','Dns','Diagnosis','DiagnosisEvents')
}
function Test-ModuleSelected { param([string]$Name) $Modules -contains $Name }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host ''
Write-Host '  MSObserver' -ForegroundColor Cyan
Write-Host "  Module: $($Modules -join ', ')"
Write-Host "  Fenster: $DurationSeconds s | Administrator: $isAdmin"
Write-Host '  Lesender Betrieb - keine Systemaenderung, keine Uebertragung.'
Write-Host ''

if ($EnableDnsLog) {
    if (-not $isAdmin) {
        Write-Warning 'EnableDnsLog benoetigt Administratorrechte und wird uebersprungen.'
    } else {
        Enable-DnsClientLog
    }
}

$startTime = Get-Date

# TCP: single snapshot, or sampled across the observation window so that
# short-lived upload connections are not missed.
$tcpResult = $null
if (Test-ModuleSelected 'Tcp') {
    if ($DurationSeconds -gt 0) {
        $interval = [Math]::Max(10, [int]($DurationSeconds / 30))
        $seen = @{}
        $elapsed = 0
        while ($true) {
            foreach ($c in @(Get-TcpEvidence)) {
                $key = '{0}:{1}|{2}' -f $c.remoteAddress, $c.remotePort, $c.pid
                if ($seen.ContainsKey($key)) {
                    $seen[$key].samples++
                    $seen[$key].lastSeen = (Get-Date).ToString('o')
                } else {
                    $seen[$key] = [pscustomobject]@{
                        remoteAddress = $c.remoteAddress
                        remotePort    = $c.remotePort
                        pid           = $c.pid
                        processName   = $c.processName
                        processPath   = $c.processPath
                        samples       = 1
                        firstSeen     = (Get-Date).ToString('o')
                        lastSeen      = (Get-Date).ToString('o')
                    }
                }
            }
            Write-Progress -Activity 'Beobachtungsfenster' `
                -Status "$elapsed / $DurationSeconds s - $($seen.Count) eindeutige Verbindungen" `
                -PercentComplete ([Math]::Min(100, 100 * $elapsed / [Math]::Max(1, $DurationSeconds)))
            if ($elapsed -ge $DurationSeconds) { break }
            $sleep = [Math]::Min($interval, $DurationSeconds - $elapsed)
            Start-Sleep -Seconds $sleep
            $elapsed += $sleep
        }
        Write-Progress -Activity 'Beobachtungsfenster' -Completed
        $tcpResult = @($seen.Values | Sort-Object -Property samples -Descending)
    } else {
        $tcpResult = @(Get-TcpEvidence)
    }
} elseif ($DurationSeconds -gt 0) {
    Write-Host "  Beobachtungsfenster laeuft ($DurationSeconds s) ..."
    Start-Sleep -Seconds $DurationSeconds
}

$dnsSince = if ($DurationSeconds -gt 0) { $startTime } else { [datetime]::MinValue }
$adminSkip = @{ skipped = 'Administratorrechte erforderlich.' }

$evidence = [ordered]@{
    tool            = 'MSObserver'
    schema          = '1.0'
    collectedAt     = (Get-Date).ToString('o')
    windowStart     = $startTime.ToString('o')
    windowSeconds   = $DurationSeconds
    modulesSelected = $Modules
    hostname        = $env:COMPUTERNAME
    osVersion       = [Environment]::OSVersion.Version.ToString()
    edition         = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).EditionID
    isAdmin         = $isAdmin
}

if (Test-ModuleSelected 'Registry') { $evidence.registryState      = Get-RegistryState }
if (Test-ModuleSelected 'Tracking') { $evidence.trackingMechanisms = @(Get-TrackingMechanisms) }
if (Test-ModuleSelected 'Tcp')      { $evidence.tcpConnections     = $tcpResult }
if (Test-ModuleSelected 'Tasks')    { $evidence.scheduledTasks     = @(Get-TaskEvidence) }

if (Test-ModuleSelected 'Dns') {
    $evidence.dnsQueries = if ($isAdmin) { @(Get-DnsEvidence -Since $dnsSince) } else { $adminSkip }
}
if (Test-ModuleSelected 'Diagnosis') {
    $evidence.diagnosisState = if ($isAdmin) { Get-DiagnosisState } else { $adminSkip }
}
if (Test-ModuleSelected 'DiagnosisEvents') {
    $evidence.diagnosisEvents = if ($isAdmin) { Get-DiagnosisEvents -IncludePayloadSamples $PayloadSamples } else { $adminSkip }
    if ($PayloadSamples -gt 0 -and $isAdmin) {
        Write-Warning "Die Ergebnisdatei enthaelt $PayloadSamples vollstaendige Payloads mit Geraetekennungen. Nicht weitergeben."
    }
}

if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath | Out-Null }
$file = Join-Path $OutputPath ('msobserver-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$evidence | ConvertTo-Json -Depth 8 | Set-Content -Path $file -Encoding UTF8

Write-Host ''
Write-Host "  Ergebnisdatei: $file" -ForegroundColor Green

if (-not $NoReport) {
    $reportScript = Join-Path $scriptRoot 'New-MSObserverReport.ps1'
    if (Test-Path $reportScript) {
        & $reportScript -EvidencePath $file
        $htmlPath = [IO.Path]::ChangeExtension($file, 'html')
        if ($OpenReport -and (Test-Path $htmlPath)) { Start-Process $htmlPath }
    } else {
        Write-Warning "Reportgenerator nicht gefunden: $reportScript"
    }
}
Write-Host ''
