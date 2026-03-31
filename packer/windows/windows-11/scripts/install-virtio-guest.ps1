# =============================================================================
# install-virtio-guest.ps1 — VirtIO Guest Tools und QEMU Guest Agent
# =============================================================================
#
# Installiert den QEMU Guest Agent von der VirtIO-Treiber ISO.
# Der Guest Agent ermoeglicht Proxmox die Kommunikation mit der VM
# (IP-Adressen auslesen, Shutdown-Befehle senden, etc.)
# =============================================================================

Write-Host "=========================================="
Write-Host "  VirtIO Guest Tools installieren..."
Write-Host "=========================================="

# VirtIO-ISO Laufwerk finden (normalerweise D: oder E:)
$virtioPath = $null
foreach ($drive in @("D:", "E:", "F:")) {
    $guestAgentPath = "$drive\guest-agent\qemu-ga-x86_64.msi"
    if (Test-Path $guestAgentPath) {
        $virtioPath = $drive
        Write-Host "  VirtIO-ISO gefunden auf Laufwerk: $virtioPath"
        break
    }
}

if (-not $virtioPath) {
    Write-Host "  WARNUNG: VirtIO-ISO nicht gefunden! QEMU Guest Agent wird nicht installiert."
    Write-Host "  Geprueft: D:\, E:\, F:\"
    exit 0
}

# QEMU Guest Agent installieren
$guestAgentMsi = "$virtioPath\guest-agent\qemu-ga-x86_64.msi"
Write-Host "  Installiere QEMU Guest Agent von: $guestAgentMsi"
$process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$guestAgentMsi`" /qn /norestart" -Wait -PassThru
if ($process.ExitCode -eq 0) {
    Write-Host "  QEMU Guest Agent erfolgreich installiert."
} else {
    Write-Host "  WARNUNG: QEMU Guest Agent Installation beendet mit Exit-Code: $($process.ExitCode)"
}

# QEMU Guest Agent Service konfigurieren
$service = Get-Service -Name "QEMU-GA" -ErrorAction SilentlyContinue
if ($service) {
    Set-Service -Name "QEMU-GA" -StartupType Automatic
    Start-Service -Name "QEMU-GA" -ErrorAction SilentlyContinue
    Write-Host "  QEMU Guest Agent Service auf Autostart gesetzt und gestartet."
} else {
    Write-Host "  WARNUNG: QEMU-GA Service nicht gefunden."
}

# VirtIO Balloon Service pruefen (wird ueber Treiber installiert)
$balloonService = Get-Service -Name "BalloonService" -ErrorAction SilentlyContinue
if ($balloonService) {
    Set-Service -Name "BalloonService" -StartupType Automatic
    Start-Service -Name "BalloonService" -ErrorAction SilentlyContinue
    Write-Host "  Balloon Service auf Autostart gesetzt."
} else {
    Write-Host "  INFO: Balloon Service noch nicht vorhanden (wird ggf. spaeter erkannt)."
}

Write-Host ""
Write-Host "=========================================="
Write-Host "  VirtIO Guest Tools Installation abgeschlossen."
Write-Host "=========================================="
