function Get-TcpEvidence {
    <#
    .SYNOPSIS
        Captures established TCP connections with process attribution.
    .NOTES
        No administrator rights required. Process names of other users'
        processes may be unavailable.
    #>
    [CmdletBinding()]
    param()

    $processes = @{}
    Get-Process | ForEach-Object { $processes[$_.Id] = $_ }

    Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
        Where-Object { $_.RemoteAddress -notin '127.0.0.1', '::1', '0.0.0.0' } |
        ForEach-Object {
            $proc = $processes[[int]$_.OwningProcess]
            [pscustomobject]@{
                remoteAddress = $_.RemoteAddress
                remotePort    = $_.RemotePort
                pid           = $_.OwningProcess
                processName   = if ($proc) { $proc.ProcessName } else { $null }
                processPath   = if ($proc) { $proc.Path } else { $null }
            }
        }
}
