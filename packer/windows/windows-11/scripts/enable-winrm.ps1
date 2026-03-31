# =============================================================================
# enable-winrm.ps1 — WinRM fuer Packer-Kommunikation aktivieren
# =============================================================================
#
# Dieses Skript wird waehrend der Windows-Installation ueber die
# Autounattend.xml FirstLogonCommands ausgefuehrt. Es konfiguriert WinRM
# so, dass Packer sich per HTTP (Port 5985) verbinden kann.
#
# HINWEIS: Diese Konfiguration ist NUR fuer den Build-Prozess gedacht.
# WinRM wird vor dem Sysprep wieder deaktiviert und die Firewall-Regel entfernt.
# =============================================================================

Write-Host "=========================================="
Write-Host "  WinRM fuer Packer aktivieren..."
Write-Host "=========================================="

# Netzwerkprofil auf Privat setzen (WinRM funktioniert nicht im oeffentlichen Profil)
$networkProfile = Get-NetConnectionProfile
if ($networkProfile) {
    Set-NetConnectionProfile -InterfaceIndex $networkProfile.InterfaceIndex -NetworkCategory Private
    Write-Host "  Netzwerkprofil auf 'Privat' gesetzt."
}

# WinRM Service konfigurieren und starten
Write-Host "  WinRM Service konfigurieren..."
winrm quickconfig -quiet

# WinRM Service auf automatischen Start setzen
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

# HTTP Listener sicherstellen (Port 5985)
$listener = winrm enumerate winrm/config/listener 2>$null
if ($listener -notmatch "Transport = HTTP") {
    Write-Host "  HTTP Listener erstellen..."
    winrm create winrm/config/listener?Address=*+Transport=HTTP
}

# Basic Auth aktivieren (fuer Packer Username/Password)
winrm set winrm/config/service/auth '@{Basic="true"}'
Write-Host "  Basic Auth aktiviert."

# Unencrypted Traffic erlauben (nur fuer Build-Prozess, wird vor Sysprep deaktiviert)
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
Write-Host "  Unencrypted Traffic erlaubt."

# MaxMemoryPerShellMB erhoehen (fuer groessere PowerShell-Skripte)
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}'
Write-Host "  MaxMemoryPerShellMB auf 1024 gesetzt."

# MaxTimeoutms erhoehen
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
Write-Host "  MaxTimeout auf 30 Minuten gesetzt."

# Firewall-Regel fuer WinRM HTTP erstellen
$ruleName = "WinRM-HTTP-Packer"
$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if (-not $existingRule) {
    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Direction Inbound `
        -LocalPort 5985 `
        -Protocol TCP `
        -Action Allow `
        -Profile Any
    Write-Host "  Firewall-Regel '$ruleName' erstellt."
} else {
    Write-Host "  Firewall-Regel '$ruleName' existiert bereits."
}

# WinRM Service neu starten um alle Aenderungen zu uebernehmen
Restart-Service -Name WinRM
Write-Host "  WinRM Service neu gestartet."

Write-Host ""
Write-Host "=========================================="
Write-Host "  WinRM erfolgreich konfiguriert!"
Write-Host "  Port: 5985 (HTTP)"
Write-Host "  Auth: Basic"
Write-Host "=========================================="
