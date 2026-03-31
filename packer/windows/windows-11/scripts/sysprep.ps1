# =============================================================================
# sysprep.ps1 — Windows Sysprep Generalisierung
# =============================================================================
#
# Letzter Schritt vor der Template-Erstellung:
# 1. WinRM-Sicherheitskonfiguration zuruecksetzen
# 2. Build-spezifische Firewall-Regeln entfernen
# 3. Sysprep /generalize /oobe /shutdown ausfuehren
#
# WICHTIG: Nach Sysprep faehrt die VM automatisch herunter.
# Packer erkennt dies und konvertiert die VM zum Template.
# =============================================================================

Write-Host "=========================================="
Write-Host "  Sysprep vorbereiten..."
Write-Host "=========================================="

# 1. WinRM-Firewall-Regel entfernen (Build-spezifisch)
Write-Host "  [1/3] WinRM-Firewall-Regel entfernen..."
Remove-NetFirewallRule -DisplayName "WinRM-HTTP-Packer" -ErrorAction SilentlyContinue
Write-Host "    WinRM-HTTP-Packer Regel entfernt."

# 2. WinRM-Sicherheit zuruecksetzen
Write-Host "  [2/3] WinRM-Konfiguration zuruecksetzen..."
winrm set winrm/config/service '@{AllowUnencrypted="false"}' 2>$null
winrm set winrm/config/service/auth '@{Basic="false"}' 2>$null
Write-Host "    WinRM Basic Auth und Unencrypted deaktiviert."

# Auto-Logon entfernen
Write-Host "  Auto-Logon entfernen..."
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Remove-ItemProperty -Path $regPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $regPath -Name "DefaultUserName" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $regPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
Write-Host "    Auto-Logon entfernt."

# 3. Sysprep ausfuehren
Write-Host "  [3/3] Sysprep ausfuehren..."
Write-Host "    /generalize — SID und Hardware-Bindungen entfernen"
Write-Host "    /oobe — OOBE-Zustand wiederherstellen"
Write-Host "    /shutdown — VM nach Sysprep herunterfahren"
Write-Host ""

$sysprepExe = "$env:SystemRoot\System32\Sysprep\sysprep.exe"
$unattendFile = "$env:SystemRoot\Temp\sysprep-unattend.xml"

if (-not (Test-Path $unattendFile)) {
    Write-Host "  WARNUNG: Sysprep-Antwortdatei nicht gefunden: $unattendFile"
    Write-Host "  Sysprep wird ohne Antwortdatei ausgefuehrt."
    & $sysprepExe /generalize /oobe /shutdown /quiet
} else {
    Write-Host "  Sysprep-Antwortdatei: $unattendFile"
    & $sysprepExe /generalize /oobe /shutdown /quiet /unattend:$unattendFile
}

# Hinweis: Dieser Punkt wird nicht mehr erreicht, da Sysprep die VM herunterfaehrt
Write-Host "  Sysprep gestartet — VM wird heruntergefahren..."
