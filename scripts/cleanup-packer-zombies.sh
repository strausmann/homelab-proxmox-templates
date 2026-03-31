#!/bin/bash
# Watchdog: Verwaiste Packer Build-VMs aufraeumen
# VMs mit Tag "building" die aelter als 1 Stunde sind -> Zombie -> loeschen
#
# Wird als Cronjob alle 15 Minuten ausgefuehrt:
#   */15 * * * * /usr/local/bin/cleanup-packer-zombies.sh >> /var/log/packer-watchdog.log 2>&1

set -euo pipefail

PVE_HOST="https://100.68.79.57:8006"
PVE_TOKEN_ID="packer@pve!packer-token"
PVE_TOKEN_SECRET="$(cat /etc/packer-token 2>/dev/null || echo '')"
PVE_NODE="PVE1"
MAX_AGE_SECONDS=3600  # 1 Stunde

if [ -z "${PVE_TOKEN_SECRET}" ]; then
  echo "$(date): FEHLER: Token nicht gefunden in /etc/packer-token"
  exit 1
fi

PVE_AUTH="Authorization: PVEAPIToken=${PVE_TOKEN_ID}=${PVE_TOKEN_SECRET}"

echo "$(date): Packer Watchdog — Suche nach verwaisten Build-VMs..."

# Alle VMs mit "building" Tag finden
BUILDING_VMS=$(curl -sfk "${PVE_HOST}/api2/json/nodes/${PVE_NODE}/qemu" \
  -H "${PVE_AUTH}" | jq -r '.data[] | select(.tags != null) | select(.tags | contains("building")) | "\(.vmid) \(.name) \(.uptime // 0)"')

if [ -z "${BUILDING_VMS}" ]; then
  echo "$(date): Keine Build-VMs gefunden. Alles sauber."
  exit 0
fi

echo "${BUILDING_VMS}" | while read -r VMID NAME UPTIME; do
  # Gestoppte VMs (uptime 0) mit building Tag sind ebenfalls Zombies
  if [ "${UPTIME}" -gt "${MAX_AGE_SECONDS}" ] || [ "${UPTIME}" -eq 0 ]; then
    if [ "${UPTIME}" -eq 0 ]; then
      echo "$(date): ZOMBIE gefunden: VM ${VMID} (${NAME}) — gestoppt mit building Tag"
    else
      HOURS=$((UPTIME / 3600))
      MINUTES=$(((UPTIME % 3600) / 60))
      echo "$(date): ZOMBIE gefunden: VM ${VMID} (${NAME}) — Uptime ${HOURS}h ${MINUTES}m (> 1h)"
    fi

    # VM stoppen (falls noch laufend)
    curl -sfk -X POST "${PVE_HOST}/api2/json/nodes/${PVE_NODE}/qemu/${VMID}/status/stop" \
      -H "${PVE_AUTH}" 2>/dev/null || true
    sleep 5

    # VM loeschen
    curl -sfk -X DELETE "${PVE_HOST}/api2/json/nodes/${PVE_NODE}/qemu/${VMID}?purge=1&destroy-unreferenced-disks=1" \
      -H "${PVE_AUTH}" 2>/dev/null || true

    echo "$(date): VM ${VMID} (${NAME}) entfernt."
  else
    MINUTES=$((UPTIME / 60))
    echo "$(date): Build laeuft: VM ${VMID} (${NAME}) — Uptime ${MINUTES}m (OK, < 1h)"
  fi
done
