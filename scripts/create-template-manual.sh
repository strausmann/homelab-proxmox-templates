#!/bin/bash
# Manuelle Ubuntu 24.04 Cloud-Init Template-Erstellung fuer Proxmox
# Alternative zu Packer fuer schnellen Start
#
# Ausfuehrung direkt auf dem Proxmox Host:
#   scp create-template-manual.sh root@hhpve01:/tmp/
#   ssh root@hhpve01 'bash /tmp/create-template-manual.sh'

set -euo pipefail

# --- Konfiguration ---
VMID=${1:-9000}
STORAGE="local-lvm"
BRIDGE="vmbr0"
TEMPLATE_NAME="tmpl-ubuntu-2404"
IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMAGE_FILE="/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img"

echo "=== Ubuntu 24.04 Cloud-Init Template erstellen (VMID: ${VMID}) ==="

# Pruefen ob VMID bereits existiert
if qm status ${VMID} &>/dev/null; then
  echo "FEHLER: VM ${VMID} existiert bereits."
  echo "Zum Loeschen: qm destroy ${VMID} --purge"
  exit 1
fi

# Cloud Image herunterladen
if [[ ! -f "${IMAGE_FILE}" ]]; then
  echo "Cloud Image herunterladen..."
  wget -O "${IMAGE_FILE}" "${IMAGE_URL}"
else
  echo "Cloud Image bereits vorhanden: ${IMAGE_FILE}"
fi

# VM erstellen
echo "VM erstellen..."
qm create ${VMID} \
  --name "${TEMPLATE_NAME}" \
  --memory 2048 \
  --cores 2 \
  --cpu cputype=host \
  --net0 virtio,bridge=${BRIDGE} \
  --ostype l26 \
  --agent enabled=1

# Disk importieren
echo "Disk importieren..."
qm importdisk ${VMID} "${IMAGE_FILE}" ${STORAGE}

# VM konfigurieren
echo "VM konfigurieren..."
qm set ${VMID} \
  --scsihw virtio-scsi-single \
  --scsi0 ${STORAGE}:vm-${VMID}-disk-0,iothread=1,discard=on \
  --ide2 ${STORAGE}:cloudinit \
  --boot order=scsi0 \
  --serial0 socket \
  --vga serial0

# Cloud-Init Defaults
qm set ${VMID} \
  --ipconfig0 ip=dhcp \
  --ciuser ubuntu

# In Template umwandeln
echo "In Template umwandeln..."
qm template ${VMID}

echo ""
echo "=== Template ${VMID} (${TEMPLATE_NAME}) erstellt ==="
echo ""
echo "Nutzung mit Terraform:"
echo "  template_id = ${VMID}"
echo ""
echo "Manuelle VM erstellen:"
echo "  qm clone ${VMID} 200 --name test-vm --full"
echo "  qm set 200 --ipconfig0 ip=dhcp --sshkeys ~/.ssh/id_ed25519.pub"
echo "  qm start 200"
