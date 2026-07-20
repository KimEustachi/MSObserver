function Get-TaskEvidence {
    <#
    .SYNOPSIS
        Reads state and last run time of telemetry-related scheduled tasks.
    .NOTES
        These tasks are the trigger evidence: they show when inventory,
        error reporting and update orchestration last executed.
    #>
    [CmdletBinding()]
    param()

    $taskPaths = @(
        '\Microsoft\Windows\Application Experience\',
        '\Microsoft\Windows\Customer Experience Improvement Program\',
        '\Microsoft\Windows\Autochk\',
        '\Microsoft\Windows\Windows Error Reporting\',
        '\Microsoft\Windows\UpdateOrchestrator\',
        '\Microsoft\Windows\Feedback\Siuf\'
    )

    foreach ($path in $taskPaths) {
        Get-ScheduledTask -TaskPath $path -ErrorAction SilentlyContinue | ForEach-Object {
            $info = $_ | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue
            $lastRun = if ($info -and $info.LastRunTime -gt (Get-Date '1999-12-31')) {
                $info.LastRunTime.ToString('o')
            } else { $null }

            [pscustomobject]@{
                taskPath    = $_.TaskPath
                taskName    = $_.TaskName
                state       = [string]$_.State
                lastRunTime = $lastRun
                lastResult  = if ($info) { $info.LastTaskResult } else { $null }
            }
        }
    }
}
