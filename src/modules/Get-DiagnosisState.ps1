function Get-DiagnosisState {
    <#
    .SYNOPSIS
        Reads DiagTrack service state, local buffer size and upload counters.
    .DESCRIPTION
        The DiagTrack operational counters in the registry prove that uploads
        actually happened - independently of DNS logs or network captures.
    #>
    [CmdletBinding()]
    param()

    $diagPath = Join-Path $env:ProgramData 'Microsoft\Diagnosis'
    $service  = Get-Service -Name 'DiagTrack' -ErrorAction SilentlyContinue

    function Convert-FileTimeValue {
        param($Value)
        try {
            if ($Value -and [long]$Value -gt 0) {
                [DateTime]::FromFileTimeUtc([long]$Value).ToString('o')
            } else { $null }
        } catch { $null }
    }

    $counters = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack' -ErrorAction SilentlyContinue
    $uploadStats = if ($counters) {
        [ordered]@{
            httpRequestCount              = $counters.HttpRequestCount
            launchCount                   = $counters.LaunchCount
            lastSuccessfulUploadUtc       = Convert-FileTimeValue $counters.LastSuccessfulUploadTime
            lastSuccessfulRealtimeUtc     = Convert-FileTimeValue $counters.LastSuccessfulRealtimeUploadTime
            lastSuccessfulNormalUtc       = Convert-FileTimeValue $counters.LastSuccessfulNormalUploadTime
            lastSuccessfulCostDeferredUtc = Convert-FileTimeValue $counters.LastSuccessfulCostDeferredUploadTime
        }
    } else { $null }

    $bufferInfo = if (Test-Path $diagPath) {
        try {
            $files = Get-ChildItem -Path $diagPath -Recurse -File -ErrorAction SilentlyContinue
            [ordered]@{
                exists     = $true
                fileCount  = ($files | Measure-Object).Count
                totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
            }
        } catch {
            [ordered]@{ exists = $true; error = $_.Exception.Message }
        }
    } else {
        [ordered]@{ exists = $false }
    }

    [ordered]@{
        diagTrackService = [ordered]@{
            status    = if ($service) { [string]$service.Status } else { 'nicht vorhanden' }
            startType = if ($service) { [string]$service.StartType } else { $null }
        }
        uploadStats        = $uploadStats
        diagnosisDirectory = $bufferInfo
    }
}
