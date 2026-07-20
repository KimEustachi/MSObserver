function Get-RegistryState {
    <#
    .SYNOPSIS
        Reads the configuration state of all privacy-relevant collection switches.
    .NOTES
        Read-only. Missing keys mean the OS default applies and are reported
        as null rather than guessed.
    #>
    [CmdletBinding()]
    param()

    function Read-RegistryValue {
        param([string]$Path, [string]$Name)
        try { (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name } catch { $null }
    }

    $levels = @{
        0 = 'Security (nur Enterprise wirksam)'
        1 = 'Required (Basic)'
        2 = 'Enhanced (veraltet)'
        3 = 'Optional (Full)'
    }

    $policyLevel  = Read-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'
    $defaultLevel = Read-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry'
    $maxAllowed   = Read-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'MaxTelemetryAllowed'
    $effective    = if ($null -ne $policyLevel) { $policyLevel } else { $defaultLevel }

    [ordered]@{
        telemetry = [ordered]@{
            policyValue    = $policyLevel
            defaultValue   = $defaultLevel
            maxAllowed     = $maxAllowed
            effectiveLevel = $effective
            effectiveName  = if ($null -ne $effective -and $levels.ContainsKey([int]$effective)) {
                                 $levels[[int]$effective]
                             } else { 'unbekannt / OS-Standard' }
        }
        advertisingId = [ordered]@{
            enabled = Read-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled'
        }
        activityHistory = [ordered]@{
            publishUserActivities = Read-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities'
            uploadUserActivities  = Read-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities'
        }
        tailoredExperiences = [ordered]@{
            enabled = Read-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled'
        }
        inputPersonalization = [ordered]@{
            restrictImplicitTextCollection = Read-RegistryValue 'HKCU:\SOFTWARE\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection'
            restrictImplicitInkCollection  = Read-RegistryValue 'HKCU:\SOFTWARE\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection'
        }
        search = [ordered]@{
            bingSearchEnabled = Read-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled'
            cortanaConsent    = Read-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent'
        }
        errorReporting = [ordered]@{
            disabled = Read-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' 'Disabled'
        }
        defenderMaps = [ordered]@{
            spynetReporting      = Read-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Spynet' 'SpynetReporting'
            submitSamplesConsent = Read-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Spynet' 'SubmitSamplesConsent'
        }
    }
}
