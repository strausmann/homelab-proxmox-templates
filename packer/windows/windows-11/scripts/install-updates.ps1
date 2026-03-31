# =============================================================================
# install-updates.ps1 — Windows Updates einspielen
# =============================================================================
#
# Installiert alle verfuegbaren Windows Updates ueber das PSWindowsUpdate Modul.
# Wird zweimal ausgefuehrt (mit Neustart dazwischen), da manche Updates
# erst nach Installation anderer Updates sichtbar werden.
#
# HINWEIS: Windows Updates koennen 30-45 Minuten dauern.
# Packer handelt Neustarts ueber den windows-restart Provisioner.
# =============================================================================

Write-Host "=========================================="
Write-Host "  Windows Updates installieren..."
Write-Host "=========================================="

# NuGet Provider installieren (Voraussetzung fuer PSWindowsUpdate)
Write-Host "  NuGet Provider installieren..."
try {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop
    Write-Host "  NuGet Provider installiert."
} catch {
    Write-Host "  WARNUNG: NuGet Provider Installation: $_"
}

# PSWindowsUpdate Modul installieren
Write-Host "  PSWindowsUpdate Modul installieren..."
try {
    Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -ErrorAction Stop
    Import-Module PSWindowsUpdate
    Write-Host "  PSWindowsUpdate Modul installiert und importiert."
} catch {
    Write-Host "  FEHLER: PSWindowsUpdate Installation fehlgeschlagen: $_"
    exit 1
}

# Alle verfuegbaren Updates installieren
Write-Host "  Suche nach verfuegbaren Updates..."
try {
    $updates = Get-WindowsUpdate -AcceptAll -IgnoreReboot -ErrorAction Stop
    if ($updates) {
        Write-Host "  $($updates.Count) Update(s) gefunden. Installiere..."
        Install-WindowsUpdate -AcceptAll -IgnoreReboot -Confirm:$false -ErrorAction Stop
        Write-Host "  Updates installiert."
    } else {
        Write-Host "  Keine Updates verfuegbar."
    }
} catch {
    Write-Host "  WARNUNG: Update-Installation: $_"
    Write-Host "  Fahre fort..."
}

# Status ausgeben
$installedUpdates = Get-WUHistory -MaxDate (Get-Date) -ErrorAction SilentlyContinue |
    Where-Object { $_.Date -gt (Get-Date).AddHours(-2) }
if ($installedUpdates) {
    Write-Host ""
    Write-Host "  Installierte Updates in dieser Sitzung:"
    foreach ($update in $installedUpdates) {
        Write-Host "    - $($update.Title)"
    }
}

Write-Host ""
Write-Host "=========================================="
Write-Host "  Windows Update Durchlauf abgeschlossen."
Write-Host "=========================================="
