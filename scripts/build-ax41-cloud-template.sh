#!/usr/bin/env bash
# AX41 Cloud-Image-Template-Build (reproduzierbar, idempotent)
#
# Ersetzt die ad-hoc auf defks-proxmox-01 angelegte Vorlage (VMID 9000,
# "ubuntu-2404-cloud") durch einen deterministischen, CI-faehigen Build.
#
# WARUM Cloud-Image statt Packer-ISO-Autoinstall (siehe docs/build-methoden.md):
# Packer-ISO-Autoinstall braucht einen HTTP-Callback + SSH-Zugriff auf die
# TRANSIENTE Installer-Build-VM. Auf AX41 (Hetzner Einzel-IP+vMAC-Modell,
# siehe host_vars/defks-proxmox-01.yml im homelab-management-Repo) hat eine
# frisch gestartete VM auf vmbr0 OHNE eigene registrierte vMAC/IP ueberhaupt
# KEIN nutzbares Netzwerk (Hetzners Switch-Port verwirft Pakete mit
# unbekannter MAC/IP-Kombination) — der Autoinstall-Callback UND jede
# netzwerkbasierte Provisionierung laufen dort komplett ins Leere.
#
# WARUM NICHT ueber den QEMU-Guest-Agent (urspruenglicher Ansatz dieses
# Skripts, live verworfen 2026-08-02): Das offizielle
# noble-server-cloudimg-amd64.img bringt qemu-guest-agent NICHT vorinstalliert
# mit (verifiziert per read-only qemu-nbd-Mount des importierten Images —
# weder /usr/bin/qemu-ga noch die systemd-Unit noch ein dpkg-Eintrag
# vorhanden). Ein Boot mit Wartezeit auf den Guest-Agent haengt deshalb
# unbegrenzt — exakt das gleiche Henne-Ei-Problem wie beim
# Debian-genericcloud-Image in Task 8 (siehe
# .claude/skills/proxmox/references/troubleshooting.md), nur dass hier gar
# kein Netzwerk als Fallback zur Verfuegung steht.
#
# LOESUNG: Das Image wird OFFLINE bearbeitet, BEVOR die VM je gestartet wird.
# Die frisch importierte Disk wird per `qemu-nbd` auf dem Proxmox-HOST
# eingehaengt (chroot teilt sich den Netzwerk-Namespace des Hosts — der Host
# selbst hat volles Internet — daher funktioniert `apt-get install` im
# chroot ohne dass die Gast-VM je gebootet werden muss). So werden
# qemu-guest-agent nachinstalliert und die SSH-Haertung direkt auf die
# Root-Partition geschrieben. Die VM wird zu keinem Zeitpunkt gestartet.
#
# AUSFUEHRUNG: Dieses Script laeuft LOKAL auf dem Ziel-Proxmox-Node — es wird
# von der GitLab-CI (oder manuell) per SSH-Stdin-Pipe ausgefuehrt, OHNE vorher
# auf den Node kopiert zu werden:
#
#   ssh -i <keyfile> root@<host> \
#     bash -s -- <vmid> <name> <bridge> <storage> <cores> <memory_mb> <disk_gb> \
#     < scripts/build-ax41-cloud-template.sh
#
# Idempotenz: Existiert die VMID bereits (Template oder VM), wird sie VOR dem
# Neubau sauber entfernt (kein Duplikat, kein "VMID belegt"-Fehler). Der
# Image-Download wird per SHA256-Checksum (offizielle Ubuntu SHA256SUMS)
# gecacht — nur bei Aenderung/fehlendem Cache wird neu heruntergeladen.
#
# Parametrisiert fuer kuenftige Tailnet-Nodes: nur die ersten beiden Positions-
# Parameter (VMID, Name) sind praktisch Pflicht, der Rest hat sinnvolle
# Defaults fuer AX41 (defks-proxmox-01).

set -euo pipefail

VMID="${1:?Usage: $0 <vmid> [name] [bridge] [storage] [cores] [memory_mb] [disk_gb]}"
VM_NAME="${2:-ubuntu-2404-cloud}"
BRIDGE="${3:-vmbr0}"
STORAGE="${4:-local}"
CORES="${5:-2}"
MEMORY_MB="${6:-2048}"
DISK_GB="${7:-8}"

IMAGE_BASE_URL="https://cloud-images.ubuntu.com/noble/current"
IMAGE_FILENAME="noble-server-cloudimg-amd64.img"
IMAGE_URL="${IMAGE_BASE_URL}/${IMAGE_FILENAME}"
SHA_URL="${IMAGE_BASE_URL}/SHA256SUMS"
CACHE_DIR="/var/cache/homelab-cloud-images"
IMAGE_PATH="${CACHE_DIR}/${IMAGE_FILENAME}"

NBD_DEV=""  # wird dynamisch als freies /dev/nbdX ermittelt (siehe unten) —
            # NICHT fest auf /dev/nbd0 verdrahten, sonst Kollisionsrisiko mit
            # anderen qemu-nbd-Nutzern auf demselben Host.
MOUNT_DIR="/mnt/homelab-template-build-${VMID}"

# Root-authorized_keys: Automations-Key (Ansible/Node-Fleet) + persoenlicher
# Key des Users — PFLICHT fuer jede neu provisionierte Maschine, siehe
# .claude/rules/vm-root-ssh-key.md im homelab-management-Repo.
ROOT_AUTHORIZED_KEYS=$'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK6gqu8YPR+KppBxvK+rsQHKeWq5jY/zC5HJO3sPmx1K ansible-vm-homelab-nodes\nssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIARsgv7N7lCpWsn2jy8w8Se2sqKulcaAM8ACIda4B7gm bjoern-personal'

log() { printf '\n=== %s ===\n' "$1"; }

# Aufraeumen bei Fehler ODER Erfolg: Bind-Mounts/Mount/NBD immer loesen,
# damit kein haengender NBD-Handle oder Mount-Rest eine Folgeausfuehrung
# blockiert.
cleanup_mount() {
  if mountpoint -q "${MOUNT_DIR}/dev" 2>/dev/null; then umount "${MOUNT_DIR}/dev" || true; fi
  if mountpoint -q "${MOUNT_DIR}/proc" 2>/dev/null; then umount "${MOUNT_DIR}/proc" || true; fi
  if mountpoint -q "${MOUNT_DIR}/sys" 2>/dev/null; then umount "${MOUNT_DIR}/sys" || true; fi
  if mountpoint -q "${MOUNT_DIR}" 2>/dev/null; then umount "${MOUNT_DIR}" || true; fi
  qemu-nbd -d "${NBD_DEV}" &>/dev/null || true
}
trap cleanup_mount EXIT

log "AX41 Cloud-Image-Template-Build: VMID ${VMID} (${VM_NAME})"

mkdir -p "${CACHE_DIR}"

log "Checksum ermitteln (offizielle Ubuntu SHA256SUMS, TLS-verifiziert)"
EXPECTED_SHA=$(curl -fsSL "${SHA_URL}" | awk -v f="${IMAGE_FILENAME}" '$2 == "*"f || $2 == f {print $1; exit}')
if [ -z "${EXPECTED_SHA}" ]; then
  echo "FEHLER: Konnte Checksum fuer ${IMAGE_FILENAME} nicht aus ${SHA_URL} ermitteln." >&2
  exit 1
fi
echo "Erwartete Checksum: ${EXPECTED_SHA}"

NEED_DOWNLOAD=1
if [ -f "${IMAGE_PATH}" ]; then
  CURRENT_SHA=$(sha256sum "${IMAGE_PATH}" | awk '{print $1}')
  if [ "${CURRENT_SHA}" = "${EXPECTED_SHA}" ]; then
    echo "Image-Cache ${IMAGE_PATH} ist aktuell — kein erneuter Download."
    NEED_DOWNLOAD=0
  else
    echo "Image-Cache veraltet (Checksum weicht ab) — wird neu heruntergeladen."
  fi
fi

if [ "${NEED_DOWNLOAD}" -eq 1 ]; then
  log "Cloud-Image herunterladen: ${IMAGE_URL}"
  curl -fsSL -o "${IMAGE_PATH}.tmp" "${IMAGE_URL}"
  ACTUAL_SHA=$(sha256sum "${IMAGE_PATH}.tmp" | awk '{print $1}')
  if [ "${ACTUAL_SHA}" != "${EXPECTED_SHA}" ]; then
    echo "FEHLER: Checksum-Mismatch nach Download!" >&2
    echo "  erwartet: ${EXPECTED_SHA}" >&2
    echo "  erhalten: ${ACTUAL_SHA}" >&2
    rm -f "${IMAGE_PATH}.tmp"
    exit 1
  fi
  mv "${IMAGE_PATH}.tmp" "${IMAGE_PATH}"
  echo "Download verifiziert (${ACTUAL_SHA})."
fi

log "Idempotenz-Gate: vorhandene VMID ${VMID} entfernen (kein Duplikat)"
if qm status "${VMID}" &>/dev/null; then
  echo "VMID ${VMID} existiert bereits — wird fuer sauberen Neubau entfernt."
  qm stop "${VMID}" --skiplock 1 &>/dev/null || true
  sleep 2
  qm destroy "${VMID}" --purge 1 --destroy-unreferenced-disks 1
fi

log "VM-Huelle anlegen (VMID ${VMID})"
qm create "${VMID}" \
  --name "${VM_NAME}" \
  --memory "${MEMORY_MB}" \
  --cores "${CORES}" \
  --cpu host \
  --ostype l26 \
  --net0 "virtio,bridge=${BRIDGE},firewall=0" \
  --scsihw virtio-scsi-single \
  --serial0 socket \
  --vga serial0 \
  --agent enabled=1

log "Disk importieren"
qm importdisk "${VMID}" "${IMAGE_PATH}" "${STORAGE}" --format qcow2

UNUSED0=$(qm config "${VMID}" | awk -F': ' '/^unused0:/ {print $2}')
if [ -z "${UNUSED0}" ]; then
  echo "FEHLER: unused0-Disk-Referenz nach importdisk nicht gefunden." >&2
  qm config "${VMID}" >&2
  exit 1
fi

qm set "${VMID}" --scsi0 "${UNUSED0},discard=on,iothread=1"
qm set "${VMID}" --boot order=scsi0
qm set "${VMID}" --ide2 "${STORAGE}:cloudinit" --citype nocloud

log "Disk auf ${DISK_GB}G bringen (no-op falls Basis-Image bereits groesser)"
qm resize "${VMID}" scsi0 "${DISK_GB}G" || echo "Resize uebersprungen (Ziel <= aktuelle Groesse)."

# --- Offline-Bearbeitung der Disk: KEIN Boot der VM noetig -----------------
# Der importierte Datentraeger-Pfad steht jetzt in scsi0 (vorher unused0).
DISK_PATH_RAW=$(qm config "${VMID}" | awk -F': ' '/^scsi0:/ {print $2}' | cut -d',' -f1)
# "storage:vmid/dateiname" -> tatsaechlicher Dateipfad via pvesm-Path-Aufloesung
DISK_ABS_PATH=$(pvesm path "${DISK_PATH_RAW}")
echo "Disk-Datei fuer Offline-Bearbeitung: ${DISK_ABS_PATH}"

log "Freies NBD-Device ermitteln (kollisionssicher statt fest /dev/nbd0)"
modprobe nbd max_part=16
for _i in $(seq 0 15); do
  _candidate="/dev/nbd${_i}"
  [ -e "${_candidate}" ] || continue
  _size_file="/sys/class/block/nbd${_i}/size"
  # size == 0 heisst: Device ist aktuell NICHT per qemu-nbd verbunden.
  if [ -f "${_size_file}" ] && [ "$(cat "${_size_file}")" = "0" ]; then
    NBD_DEV="${_candidate}"
    break
  fi
done
if [ -z "${NBD_DEV}" ]; then
  echo "FEHLER: Kein freies /dev/nbdX-Device (0-15) gefunden — alle belegt." >&2
  exit 1
fi
echo "Verwende freies NBD-Device: ${NBD_DEV}"

log "Root-Partition per qemu-nbd einhaengen (Host-Netzwerk-Namespace, kein Gast-Boot)"
qemu-nbd -c "${NBD_DEV}" "${DISK_ABS_PATH}"
udevadm settle || sleep 2

# Ubuntu-Cloud-Images labeln die Root-Partition konsistent "cloudimg-rootfs"
# (verifiziert 2026-08-02 gegen noble-server-cloudimg-amd64.img).
ROOTPART=""
for _ in $(seq 1 10); do
  ROOTPART=$(lsblk -nrpo NAME,LABEL "${NBD_DEV}" 2>/dev/null | awk '$2=="cloudimg-rootfs"{print $1; exit}')
  [ -n "${ROOTPART}" ] && break
  sleep 1
done
if [ -z "${ROOTPART}" ]; then
  echo "FEHLER: Root-Partition (LABEL=cloudimg-rootfs) auf ${NBD_DEV} nicht gefunden." >&2
  lsblk "${NBD_DEV}" >&2
  exit 1
fi
echo "Root-Partition: ${ROOTPART}"

mkdir -p "${MOUNT_DIR}"
mount "${ROOTPART}" "${MOUNT_DIR}"

log "Root-SSH-Keys injizieren (Automations-Key + persoenlicher Key)"
install -d -m 700 "${MOUNT_DIR}/root/.ssh"
printf '%s\n' "${ROOT_AUTHORIZED_KEYS}" > "${MOUNT_DIR}/root/.ssh/authorized_keys"
chmod 600 "${MOUNT_DIR}/root/.ssh/authorized_keys"

log "SSH-Hardening-Baseline schreiben (siehe ssh-hardening-baseline.md)"
install -d -m 755 "${MOUNT_DIR}/etc/ssh/sshd_config.d"
cat > "${MOUNT_DIR}/etc/ssh/sshd_config.d/99-homelab-sshd.conf" <<'EOF'
MaxAuthTries 30
MaxSessions 10
PasswordAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
KbdInteractiveAuthentication no
EOF

log "qemu-guest-agent per chroot nachinstallieren (Host-Netzwerk-Namespace)"
# Bind-Mounts: chroot teilt sich damit den Kernel-/Netzwerk-Namespace des
# Hosts — apt/dpkg-Postinst-Skripte funktionieren wie in einer echten VM,
# OHNE dass diese je gebootet wurde.
mount --bind /dev "${MOUNT_DIR}/dev"
mount -t proc proc "${MOUNT_DIR}/proc"
mount -t sysfs sysfs "${MOUNT_DIR}/sys"

# DNS im chroot sicherstellen (Host-resolv.conf temporaer hineinkopieren,
# Original-Symlink/-Datei danach wiederherstellen — das gebaute Image soll
# NICHT die AX41-spezifische resolv.conf behalten, cloud-init/systemd-
# resolved regeneriert sie beim ersten echten Boot ohnehin).
RESOLV_BACKUP="$(mktemp)"
RESOLV_WAS_SYMLINK=0
if [ -L "${MOUNT_DIR}/etc/resolv.conf" ]; then
  RESOLV_WAS_SYMLINK=1
  readlink "${MOUNT_DIR}/etc/resolv.conf" > "${RESOLV_BACKUP}"
elif [ -f "${MOUNT_DIR}/etc/resolv.conf" ]; then
  cp "${MOUNT_DIR}/etc/resolv.conf" "${RESOLV_BACKUP}"
fi
# Bestehende Datei/(ggf. haengenden) Symlink IMMER erst entfernen — sonst
# verweigert `cp` das Schreiben ("not writing through dangling symlink"),
# falls /etc/resolv.conf im Image ein Symlink auf eine (im Offline-Zustand
# nicht existierende) systemd-resolved-Stub-Datei ist.
rm -f "${MOUNT_DIR}/etc/resolv.conf"
cp -L /etc/resolv.conf "${MOUNT_DIR}/etc/resolv.conf"

chroot "${MOUNT_DIR}" bash -c "export DEBIAN_FRONTEND=noninteractive; apt-get update && apt-get install -y qemu-guest-agent cloud-init openssh-server ca-certificates curl vim htop && apt-get clean && rm -rf /var/lib/apt/lists/*"

# resolv.conf zuruecksetzen
rm -f "${MOUNT_DIR}/etc/resolv.conf"
if [ "${RESOLV_WAS_SYMLINK}" -eq 1 ]; then
  ln -s "$(cat "${RESOLV_BACKUP}")" "${MOUNT_DIR}/etc/resolv.conf"
elif [ -s "${RESOLV_BACKUP}" ]; then
  cp "${RESOLV_BACKUP}" "${MOUNT_DIR}/etc/resolv.conf"
fi
rm -f "${RESOLV_BACKUP}"

umount "${MOUNT_DIR}/dev"
umount "${MOUNT_DIR}/proc"
umount "${MOUNT_DIR}/sys"

log "Verify — qemu-guest-agent ist jetzt im Image vorhanden"
# Ubuntu/Debian-Paket installiert den Guest-Agent nach /usr/sbin/qemu-ga
# (NICHT /usr/bin/ — verifiziert 2026-08-02 per dpkg -L qemu-guest-agent).
if [ ! -e "${MOUNT_DIR}/usr/sbin/qemu-ga" ]; then
  echo "FEHLER: /usr/sbin/qemu-ga fehlt nach der Installation weiterhin." >&2
  exit 1
fi
echo "qemu-ga vorhanden: $(ls -la "${MOUNT_DIR}/usr/sbin/qemu-ga")"

umount "${MOUNT_DIR}"
qemu-nbd -d "${NBD_DEV}"
rmdir "${MOUNT_DIR}" 2>/dev/null || true

log "In Template umwandeln (VM wurde zu keinem Zeitpunkt gestartet)"
qm template "${VMID}"

qm set "${VMID}" --tags "os-ubuntu;v-2404;cloud-image;ci-managed;latest" || true

log "Fertig — Template ${VMID} (${VM_NAME})"
qm config "${VMID}" | grep -E '^(name|template|scsi0|net0|ide2|tags):'
