function Get-TrackingMechanisms {
    <#
    .SYNOPSIS
        Inventories built-in Windows tracking mechanisms and device identifiers.
    .NOTES
        The 'state' value is deliberately conservative: 'aktiv' only when the
        registry value unambiguously permits collection. Missing keys are
        reported as OS default rather than interpreted.
    #>
    [CmdletBinding()]
    param()

    function Read-RegistryValue {
        param([string]$Path, [string]$Name)
        try { (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name } catch { $null }
    }

    $items = New-Object System.Collections.Generic.List[object]

    # --- Identifiers ---
    $adId      = Read-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Id'
    $adEnabled = Read-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled'
    $items.Add([pscustomobject]@{
        area  = 'Kennung'
        name  = 'Werbe-ID'
        state = if ($adEnabled -eq 1) { 'aktiv' } elseif ($adEnabled -eq 0) { 'deaktiviert' } else { 'Standard (aktiv)' }
        value = if ($adId) { $adId } else { 'nicht gesetzt' }
        note  = 'App-uebergreifende Kennung fuer Werbeprofile. Wird bei Deaktivierung genullt.'
    })

    $machineId = Read-RegistryValue 'HKLM:\SOFTWARE\Microsoft\SQMClient' 'MachineId'
    $items.Add([pscustomobject]@{
        area  = 'Kennung'
        name  = 'Telemetrie-Geraete-ID'
        state = if ($machineId) { 'vorhanden' } else { 'nicht vorhanden' }
        value = if ($machineId) { $machineId } else { '' }
        note  = 'Erscheint in jedem Diagnoseereignis als ext.device.localId. Nicht abschaltbar.'
    })

    # --- Content ---
    $clipHistory = Read-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Clipboard' 'EnableClipboardHistory'
    $clipSync    = Read-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Clipboard' 'CloudClipboardAutomaticUpload'
    $items.Add([pscustomobject]@{
        area  = 'Inhalte'
        name  = 'Zwischenablage'
        state = if ($clipSync -eq 1) { 'Cloud-Synchronisierung aktiv' }
                elseif ($clipHistory -eq 1) { 'nur lokaler Verlauf' }
                else { 'aus / Standard' }
        value = "Verlauf=$clipHistory; CloudUpload=$clipSync"
        note  = 'Bei Cloud-Synchronisierung werden kopierte Inhalte zum Microsoft-Konto uebertragen.'
    })

    # --- Input ---
    $restrictText = Read-RegistryValue 'HKCU:\SOFTWARE\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection'
    $restrictInk  = Read-RegistryValue 'HKCU:\SOFTWARE\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection'
    $items.Add([pscustomobject]@{
        area  = 'Eingabe'
        name  = 'Eingabepersonalisierung'
        state = if ($restrictText -eq 1 -and $restrictInk -eq 1) { 'eingeschraenkt' } else { 'Sammlung erlaubt' }
        value = "RestrictText=$restrictText; RestrictInk=$restrictInk"
        note  = 'Lernt aus Tastatur- und Stifteingaben fuer Woerterbuch und Erkennung.'
    })

    $speech = Read-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' 'HasAccepted'
    $items.Add([pscustomobject]@{
        area  = 'Eingabe'
        name  = 'Online-Spracherkennung'
        state = if ($speech -eq 1) { 'aktiv' } elseif ($speech -eq 0) { 'deaktiviert' } else { 'nicht konfiguriert' }
        value = "HasAccepted=$speech"
        note  = 'Sprachaufnahmen werden zur Erkennung an Microsoft-Clouddienste gesendet.'
    })

    # --- Location ---
    $locSystem = Read-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value'
    $locUser   = Read-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value'
    $items.Add([pscustomobject]@{
        area  = 'Standort'
        name  = 'Standortdienst'
        state = if ($locSystem -eq 'Allow' -or $locUser -eq 'Allow') { 'erlaubt' }
                elseif ($locSystem -eq 'Deny' -and (-not $locUser -or $locUser -eq 'Deny')) { 'verweigert' }
                else { 'gemischt' }
        value = "System=$locSystem; Benutzer=$locUser"
        note  = 'Positionsermittlung unter anderem ueber WLAN-Umgebung.'
    })

    $findMyDevice = Read-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Settings\FindMyDevice' 'LocationSyncEnabled'
    $items.Add([pscustomobject]@{
        area  = 'Standort'
        name  = 'Mein Geraet suchen'
        state = if ($findMyDevice -eq 1) { 'aktiv' } elseif ($findMyDevice -eq 0) { 'deaktiviert' } else { 'nicht konfiguriert' }
        value = "LocationSyncEnabled=$findMyDevice"
        note  = 'Uebertraegt periodisch den Geraetestandort zum Microsoft-Konto.'
    })

    # --- System ---
    $appDiagnostics = Read-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appDiagnostics' 'Value'
    $items.Add([pscustomobject]@{
        area  = 'System'
        name  = 'App-Diagnosezugriff'
        state = if ($appDiagnostics -eq 'Allow') { 'erlaubt' } elseif ($appDiagnostics -eq 'Deny') { 'verweigert' } else { 'nicht konfiguriert' }
        value = "Value=$appDiagnostics"
        note  = 'Erlaubt Apps das Auslesen von Diagnoseinformationen anderer Apps.'
    })

    $feedback = Read-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod'
    $items.Add([pscustomobject]@{
        area  = 'System'
        name  = 'Feedback-Aufforderungen'
        state = if ($feedback -eq 0) { 'deaktiviert' } elseif ($null -ne $feedback) { 'aktiv' } else { 'Standard (automatisch)' }
        value = "NumberOfSIUFInPeriod=$feedback"
        note  = 'System-initiierte Feedbackabfragen.'
    })

    # --- AI ---
    $recall = Read-RegistryValue 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis'
    $items.Add([pscustomobject]@{
        area  = 'KI'
        name  = 'Recall'
        state = if ($recall -eq 1) { 'per Richtlinie deaktiviert' }
                elseif ($null -eq $recall) { 'keine Richtlinie (geraeteabhaengig)' }
                else { 'erlaubt' }
        value = "DisableAIDataAnalysis=$recall"
        note  = 'Erstellt auf Copilot+-Hardware periodische Bildschirmaufnahmen zur lokalen Analyse.'
    })

    $items
}
