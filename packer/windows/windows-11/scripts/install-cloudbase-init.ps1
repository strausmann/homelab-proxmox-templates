# =============================================================================
# install-cloudbase-init.ps1 — Cloudbase-Init fuer Proxmox Cloud-Init
# =============================================================================
#
# Cloudbase-Init ist die Windows-Implementierung von Cloud-Init.
# Es ermoeglicht Proxmox beim Erstellen einer VM aus dem Template:
# - Hostname setzen
# - Netzwerk konfigurieren (IP, Gateway, DNS)
# - Administrator-Passwort setzen
# - SSH-Keys hinterlegen (wenn OpenSSH installiert)
# =============================================================================

Write-Host "=========================================="
Write-Host "  Cloudbase-Init installieren..."
Write-Host "=========================================="

# Download-URL fuer Cloudbase-Init (stabile Version)
$cloudbaseUrl = "https://github.com/cloudbase/cloudbase-init/releases/latest/download/CloudbaseInitSetup_x64.msi"
$downloadPath = "$env:TEMP\CloudbaseInitSetup_x64.msi"

# Herunterladen
Write-Host "  Lade Cloudbase-Init herunter..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try {
    Invoke-WebRequest -Uri $cloudbaseUrl -OutFile $downloadPath -UseBasicParsing
    Write-Host "  Download abgeschlossen: $downloadPath"
} catch {
    Write-Host "  FEHLER: Download fehlgeschlagen: $_"
    exit 1
}

# Silent Install (ohne Sysprep am Ende, das machen wir selbst)
Write-Host "  Installiere Cloudbase-Init (silent)..."
$installArgs = @(
    "/i", "`"$downloadPath`"",
    "/qn",
    "/norestart",
    "/l*v", "$env:TEMP\cloudbase-init-install.log",
    "LOGGINGSERIALPORTNAME=COM1"
)
$process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru
if ($process.ExitCode -eq 0) {
    Write-Host "  Cloudbase-Init erfolgreich installiert."
} else {
    Write-Host "  WARNUNG: Installation beendet mit Exit-Code: $($process.ExitCode)"
    Write-Host "  Log: $env:TEMP\cloudbase-init-install.log"
}

# Cloudbase-Init Konfiguration anpassen
$configPath = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf"
if (Test-Path $configPath) {
    Write-Host "  Konfiguriere cloudbase-init.conf..."

    $config = @"
[DEFAULT]
username=Administrator
groups=Administrators
inject_user_password=true
config_drive_raw_hhd=true
config_drive_cdrom=true
config_drive_vfat=true
bsdtar_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\bsdtar.exe
mtu_use_dhcp_config=true
ntp_use_dhcp_config=true
local_scripts_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\
metadata_services=cloudbaseinit.metadata.services.configdrive.ConfigDriveService
plugins=cloudbaseinit.plugins.common.mtu.MTUPlugin,
        cloudbaseinit.plugins.common.sethostname.SetHostNamePlugin,
        cloudbaseinit.plugins.windows.createuser.CreateUserPlugin,
        cloudbaseinit.plugins.windows.extendvolumes.ExtendVolumesPlugin,
        cloudbaseinit.plugins.common.setuserpassword.SetUserPasswordPlugin,
        cloudbaseinit.plugins.common.localscripts.LocalScriptsPlugin,
        cloudbaseinit.plugins.common.userdata.UserdataPlugin,
        cloudbaseinit.plugins.windows.winrmlistener.ConfigWinRMListenerPlugin,
        cloudbaseinit.plugins.windows.winrmcertificateauth.ConfigWinRMCertificateAuthPlugin
logging_serial_port_settings=COM1,115200,N,8
first_logon_behaviour=no
"@

    Set-Content -Path $configPath -Value $config -Encoding UTF8
    Write-Host "  cloudbase-init.conf geschrieben."
} else {
    Write-Host "  WARNUNG: cloudbase-init.conf nicht gefunden unter: $configPath"
}

# Cloudbase-Init Unattend-Konfiguration (fuer Sysprep-Integration)
$unattendConfigPath = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init-unattend.conf"
if (Test-Path $unattendConfigPath) {
    Write-Host "  Konfiguriere cloudbase-init-unattend.conf..."

    $unattendConfig = @"
[DEFAULT]
username=Administrator
groups=Administrators
inject_user_password=true
config_drive_raw_hhd=true
config_drive_cdrom=true
config_drive_vfat=true
bsdtar_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\bsdtar.exe
mtu_use_dhcp_config=true
ntp_use_dhcp_config=true
local_scripts_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\
metadata_services=cloudbaseinit.metadata.services.configdrive.ConfigDriveService
plugins=cloudbaseinit.plugins.common.mtu.MTUPlugin,
        cloudbaseinit.plugins.common.sethostname.SetHostNamePlugin,
        cloudbaseinit.plugins.windows.createuser.CreateUserPlugin,
        cloudbaseinit.plugins.windows.extendvolumes.ExtendVolumesPlugin,
        cloudbaseinit.plugins.common.setuserpassword.SetUserPasswordPlugin,
        cloudbaseinit.plugins.common.localscripts.LocalScriptsPlugin,
        cloudbaseinit.plugins.common.userdata.UserdataPlugin
logging_serial_port_settings=COM1,115200,N,8
"@

    Set-Content -Path $unattendConfigPath -Value $unattendConfig -Encoding UTF8
    Write-Host "  cloudbase-init-unattend.conf geschrieben."
}

# Service auf Autostart setzen
$service = Get-Service -Name "cloudbase-init" -ErrorAction SilentlyContinue
if ($service) {
    Set-Service -Name "cloudbase-init" -StartupType Automatic
    Write-Host "  Cloudbase-Init Service auf Autostart gesetzt."
} else {
    Write-Host "  INFO: cloudbase-init Service noch nicht registriert (wird bei Sysprep konfiguriert)."
}

# Aufraumen
Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=========================================="
Write-Host "  Cloudbase-Init Installation abgeschlossen."
Write-Host "=========================================="
