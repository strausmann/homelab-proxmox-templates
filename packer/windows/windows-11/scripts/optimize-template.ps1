# =============================================================================
# optimize-template.ps1 — Template Cleanup und Optimierung
# =============================================================================
#
# Raeumt das System auf und minimiert die Template-Groesse:
# - Temporaere Dateien loeschen
# - Windows Defender Definitionen entfernen (werden bei Boot aktualisiert)
# - Event Logs leeren
# - Disk Cleanup ausfuehren
# - Disk trimmen (TRIM/Discard fuer thin provisioning)
# =============================================================================

Write-Host "=========================================="
Write-Host "  Template optimieren und aufraeumen..."
Write-Host "=========================================="

# 1. Temporaere Dateien loeschen
Write-Host "  [1/6] Temporaere Dateien loeschen..."
$tempPaths = @(
    "$env:TEMP\*",
    "$env:SystemRoot\Temp\*",
    "$env:LOCALAPPDATA\Temp\*",
    "$env:SystemRoot\Logs\CBS\*",
    "$env:SystemRoot\Logs\DISM\*"
)
foreach ($path in $tempPaths) {
    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "    Temporaere Dateien geloescht."

# 2. Windows Defender Definitionen entfernen (werden beim naechsten Boot aktualisiert)
Write-Host "  [2/6] Windows Defender Definitionen entfernen..."
try {
    & "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -RemoveDefinitions -All -ErrorAction SilentlyContinue
    Write-Host "    Defender Definitionen entfernt."
} catch {
    Write-Host "    WARNUNG: Defender Definitionen konnten nicht entfernt werden."
}

# 3. Event Logs leeren
Write-Host "  [3/6] Event Logs leeren..."
$logs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 0 }
foreach ($log in $logs) {
    try {
        [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($log.LogName)
    } catch {
        # Einige System-Logs koennen nicht geloescht werden — ignorieren
    }
}
Write-Host "    Event Logs geleert."

# 4. Windows Update Cleanup
Write-Host "  [4/6] Windows Update Cleanup..."
# SoftwareDistribution Download-Ordner leeren
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:SystemRoot\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
Start-Service -Name wuauserv -ErrorAction SilentlyContinue
Write-Host "    Windows Update Cache geleert."

# 5. Disk Cleanup (automatisiert)
Write-Host "  [5/6] Disk Cleanup ausfuehren..."
# Registry-Keys fuer automatischen Disk Cleanup setzen
$cleanupKeys = @(
    "Active Setup Temp Folders",
    "BranchCache",
    "Downloaded Program Files",
    "Internet Cache Files",
    "Old ChkDsk Files",
    "Previous Installations",
    "Recycle Bin",
    "Setup Log Files",
    "System error memory dump files",
    "System error minidump files",
    "Temporary Files",
    "Temporary Setup Files",
    "Thumbnail Cache",
    "Update Cleanup",
    "Upgrade Discarded Files",
    "Windows Error Reporting Files",
    "Windows Reset Log Files"
)
foreach ($key in $cleanupKeys) {
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$key"
    if (Test-Path $regPath) {
        Set-ItemProperty -Path $regPath -Name "StateFlags0100" -Value 2 -Type DWord -ErrorAction SilentlyContinue
    }
}
# Disk Cleanup ausfuehren
Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:100" -Wait -ErrorAction SilentlyContinue
Write-Host "    Disk Cleanup ausgefuehrt."

# 6. Disk optimieren (TRIM/Defrag)
Write-Host "  [6/6] Disk optimieren..."
try {
    Optimize-Volume -DriveLetter C -ReTrim -ErrorAction Stop
    Write-Host "    TRIM auf Laufwerk C: ausgefuehrt."
} catch {
    Write-Host "    WARNUNG: TRIM fehlgeschlagen: $_"
}

# Zusammenfassung
$diskUsage = Get-PSDrive C | Select-Object @{N='Used_GB';E={[math]::Round($_.Used/1GB,2)}}, @{N='Free_GB';E={[math]::Round($_.Free/1GB,2)}}
Write-Host ""
Write-Host "=========================================="
Write-Host "  Template-Optimierung abgeschlossen."
Write-Host "  Disk C: Belegt: $($diskUsage.Used_GB) GB, Frei: $($diskUsage.Free_GB) GB"
Write-Host "=========================================="
