# =============================================================================
# install-tailscale.ps1 — Tailscale Client installieren
# =============================================================================
#
# Installiert den Tailscale Client als MSI-Paket.
# Der Service wird auf automatischen Start gesetzt, aber NICHT verbunden.
# Die Tailscale-Verbindung erfolgt erst bei der VM-Erstellung.
# =============================================================================

Write-Host "=========================================="
Write-Host "  Tailscale installieren..."
Write-Host "=========================================="

# Download-URL fuer Tailscale MSI (stabile Version)
$tailscaleUrl = "https://pkgs.tailscale.com/stable/tailscale-setup-latest-amd64.msi"
$downloadPath = "$env:TEMP\tailscale-setup.msi"

# Herunterladen
Write-Host "  Lade Tailscale herunter..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try {
    Invoke-WebRequest -Uri $tailscaleUrl -OutFile $downloadPath -UseBasicParsing
    Write-Host "  Download abgeschlossen: $downloadPath"
} catch {
    Write-Host "  FEHLER: Download fehlgeschlagen: $_"
    exit 1
}

# Silent Install
Write-Host "  Installiere Tailscale (silent)..."
$installArgs = @(
    "/i", "`"$downloadPath`"",
    "/qn",
    "/norestart",
    "/l*v", "$env:TEMP\tailscale-install.log",
    "TS_ADMINCONSOLE=hide"
)
$process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru
if ($process.ExitCode -eq 0) {
    Write-Host "  Tailscale erfolgreich installiert."
} else {
    Write-Host "  WARNUNG: Installation beendet mit Exit-Code: $($process.ExitCode)"
    Write-Host "  Log: $env:TEMP\tailscale-install.log"
}

# Service auf automatischen Start setzen
$service = Get-Service -Name "Tailscale" -ErrorAction SilentlyContinue
if ($service) {
    Set-Service -Name "Tailscale" -StartupType Automatic
    Write-Host "  Tailscale Service auf Autostart gesetzt."
    Write-Host "  HINWEIS: Tailscale ist NICHT verbunden — Verbindung bei VM-Erstellung."
} else {
    Write-Host "  WARNUNG: Tailscale Service nicht gefunden."
}

# Aufraumen
Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=========================================="
Write-Host "  Tailscale Installation abgeschlossen."
Write-Host "  Status: Installiert, nicht verbunden."
Write-Host "=========================================="
