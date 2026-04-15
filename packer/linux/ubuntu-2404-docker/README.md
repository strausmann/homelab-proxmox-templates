# Template: Ubuntu 24.04 LTS Docker-Node

Ubuntu 24.04 LTS Template fuer Docker-Nodes im HomeLab. Erweiterung des Base-Templates um eine
dedizierte zweite Disk fuer `/docker` (XFS, 300G) und eine vollstaendige Docker CE Installation
mit vorkonfiguriertem Daemon. Dieses Template wird fuer alle hhdockerXX-Nodes verwendet.

## Eigenschaften

| Eigenschaft | Wert |
|---|---|
| Basis-OS | Ubuntu 24.04 LTS (Noble Numbat) |
| Bios | UEFI (OVMF) |
| Cloud-Init | Ja |
| Default CPU (Build) | 6 Cores (wird nach Build auf 4 zurueckgesetzt) |
| Default CPU (Template) | 4 Cores |
| Default Docker-Disk | 300G (raw, virtio-scsi-single, XFS, mount: /docker) |
| Default OS-Disk | 50G (raw, virtio-scsi-single, io_thread, discard) |
| Default RAM (Build) | 8192 MB (wird nach Build auf 4096 zurueckgesetzt) |
| Default RAM (Template) | 4096 MB |
| Default VM-ID-Bereich | 9100–9199 |
| Docker CE | vorinstalliert, data-root: /docker |
| EFI Disk | 4M, pre-enrolled keys |
| LUKS-Verschluesselung | Nein |
| Machine-Typ | q35 |
| Netzwerk-Bridge | vnet60 (CI), vmbr0 (HCL-Default) |
| QEMU Guest Agent | Ja |
| Scsi-Controller | virtio-scsi-single |
| Storage-Pool | nvme (CI), local-lvm (HCL-Default) |
| Template-Name | `tmpl-ubuntu-docker-2404-YYYYMMDD-bNN` |
| TPM | 2.0 |

## Image-Aufbau

### Partitionierung

Identisch zum Base-Template: Ubuntu Subiquity mit `storage.layout.name: direct` (kein LVM).
Die zweite Disk (`/dev/sdb`, 300G) wird **nicht** durch Subiquity partitioniert — das erledigt
der Ansible-Provisioner (`packer-hardening-docker.yml`) waehrend des Packer-Builds.

Disk-Layout nach Build:

| Disk | Geosse | Dateisystem | Mountpoint |
|---|---|---|---|
| `/dev/sda` | 50G | ext4 (via direct layout) | `/` |
| `/dev/sdb` | 300G | XFS | `/docker` |

### Docker-Disk (Phase 2 im Ansible-Playbook)

- `/dev/sdb` wird mit XFS formatiert (`discard,noatime`)
- Mountpoint `/docker` wird angelegt
- fstab-Eintrag via UUID (nicht Geraetenamen)
- `/docker/stacks/` als Standard-Stack-Verzeichnis

### Docker CE Installation (Phase 3+4)

Docker CE wird via offizieller Docker APT-Repository installiert. Komponenten:

- `docker-ce`
- `docker-buildx-plugin`
- `docker-ce-cli`
- `docker-compose-plugin`
- `containerd.io`

### Docker Daemon-Konfiguration (`/etc/docker/daemon.json`)

| Einstellung | Wert | Beschreibung |
|---|---|---|
| `data-root` | `/docker` | Alle Container-Daten auf zweiter Disk |
| `default-address-pools` | `172.20.0.0/14`, /24 | Kein Konflikt mit HomeLab-VLANs |
| `features.buildkit` | `true` | BuildKit aktiv |
| `live-restore` | `true` | Container ueberleben Docker-Daemon-Neustart |
| `log-driver` | `json-file` | Standardformat |
| `log-opts.max-file` | `3` | Max 3 Log-Rotations |
| `log-opts.max-size` | `10m` | Max 10 MB pro Log-Datei |
| `metrics-addr` | `0.0.0.0:9323` | Prometheus-Metriken fuer Docker |
| `storage-driver` | `overlay2` | Standard fuer Ubuntu |

### Installierte Pakete (Basis — via Autoinstall + Hardening)

Identisch zum Base-Template. Zusaetzlich via `packer-hardening-docker.yml`:

- `containerd.io`
- `docker-buildx-plugin`
- `docker-ce`
- `docker-ce-cli`
- `docker-compose-plugin`

Vollstaendige Basis-Paketliste: siehe `packer/linux/ubuntu-2404/README.md`

### Aktivierte Services

| Service | Zustand im Template |
|---|---|
| chrony | aktiviert, gestartet |
| crowdsec | aktiviert, gestoppt |
| docker | aktiviert, gestartet |
| fail2ban | aktiviert, gestartet |
| prometheus-node-exporter | aktiviert, gestartet |
| qemu-guest-agent | aktiviert, gestartet |
| tailscaled | aktiviert, gestoppt |

### Hardening

Identisch zum Base-Template via `packer-hardening.yml` (importiert als Phase 1 in
`packer-hardening-docker.yml`). Siehe `packer/linux/ubuntu-2404/README.md` fuer Details.

---

## Konfiguration — Was bewirkt welche Option?

### `ubuntu-2404-docker.pkr.hcl` — Packer-Konfig

Alle Variablen aus dem Base-Template gelten analog (siehe `packer/linux/ubuntu-2404/README.md`).
Zusaetzliche Variable:

| Variable | Default | Beschreibung |
|---|---|---|
| `docker_disk_size` | `300G` | Groesse der zweiten Disk fuer `/docker`. Aendern wenn mehr Storage noetig (z.B. `500G` fuer grosse Media-Nodes) |
| `vm_id` | `9100` | Standardmaessig im Docker-Bereich (9100–9199). CI findet naechste freie ID |

Wichtiger Unterschied zum Base-Template: `boot_wait = "15s"` statt `10s` — die zweite Disk
benoetigt laenger beim UEFI-Init.

Das Ansible-Playbook ist `packer-hardening-docker.yml` statt `packer-hardening.yml`.

### `http/user-data` — Autoinstall-Konfig

Identisch zum Base-Template (`ubuntu-2404/http/user-data`). Die zweite Disk wird bewusst
**nicht** in der Subiquity-Storage-Config erwaehnt — Subiquity wuerde sie sonst initialisieren
und das wuerde mit dem Ansible-Provisioner kollidieren.

### `http/meta-data`

Leeres JSON-Objekt `{}` — identisch zum Base-Template.

---

## Build-Pipeline (GitLab CI)

| Eigenschaft | Wert |
|---|---|
| Build-Job | `build_ubuntu_2404_docker` |
| Deploy-Job | `rotate_latest_ubuntu_2404_docker` |
| Pfad | `.gitlab-ci.yml` |
| Resource-Group | `packer_build_ubuntu-docker_2404` |
| Timeout | 90 Minuten |
| Trigger (automatisch) | Push auf `main` mit Aenderungen unter `packer/linux/ubuntu-2404-docker/`, `packer/linux/ubuntu-2404/`, `profiles/base.yml`, `ansible/playbooks/packer-hardening.yml` oder `ansible/playbooks/packer-hardening-docker.yml` |
| Trigger (manuell) | Pipeline-Start via GitLab UI (`web`) oder Schedule |
| Validate-Job | `validate_ubuntu_2404_docker` |
| VM-ID-Bereich | 9100–9199 |

Der Docker-Template-Build wird auch ausgeloest wenn das Base-Template (`ubuntu-2404`) oder
das Hardening-Playbook geaendert wird — da beides direkt in dieses Template einfliesst.

---

## Deployment

### Option A: Mit OpenTofu (empfohlen)

```hcl
module "hhdocker04" {
  source = "../../modules/linux-vm"

  vm_name        = "hhdocker04"
  vm_id          = 104
  proxmox_node   = "PVE1"
  template_id    = 9142  # aktuelle Docker-Template-ID (Tag: latest + os-ubuntu-docker + v-2404)
  cpu_cores      = 4
  memory         = 8192
  storage_pool   = "nvme"
  network_bridge = "vnet10"
  ip_address     = "dhcp"
  ci_user        = "ubuntu"
  ssh_keys       = ["ssh-ed25519 AAAA..."]
}
```

```bash
tofu apply -target=module.hhdocker04
```

### Option B: Direkte Proxmox-CLI

```bash
# Template-ID ermitteln (Tag: latest + os-ubuntu-docker + v-2404)
pvesh get /nodes/PVE1/qemu --output-format json | \
  jq '[.[] | select(.tags != null) | select(.tags | contains("latest")) | select(.tags | contains("v-2404")) | select(.tags | contains("os-ubuntu-docker"))]'

# Template klonen
qm clone <template-id> <target-vmid> --name hhdocker04 --full true

# Cloud-Init konfigurieren
qm set <target-vmid> --ipconfig0 ip=dhcp
qm set <target-vmid> --sshkey ~/.ssh/id_ed25519_homelab_nodes.pub
qm set <target-vmid> --ciuser ubuntu

# Starten
qm start <target-vmid>
```

---

## Onboarding (nach Deployment)

### Option 1: Mit Ansible (empfohlen)

```bash
cd /opt/homelab-management/infra/ansible

# Docker-Node-Setup (Tailscale, CrowdSec, Services-Stack deployen)
ansible-playbook playbooks/setup-docker-node.yml -l hhdocker04
```

Das Playbook konfiguriert Tailscale, CrowdSec-Enrollment und deployt den Services-Stack
(Watchtower, Autoheal, Socket Proxy, etc.).

### Option 2: Manuell

```bash
ssh -i ~/.ssh/id_ed25519_homelab_nodes root@<ip>

# Docker-Pfad pruefen
df -h /docker          # Muss als /dev/sdb gemounted sein (XFS, 300G)
docker info | grep -E "Data Root|Storage Driver"

# Tailscale einrichten
tailscale up --auth-key=<tskey-auth-...> --hostname=hhdocker04

# CrowdSec enrollen
cscli lapi register --url http://<crowdsec-lapi>:8080 --key <enrollment-key>
systemctl start crowdsec

# Services-Stack deployen
cd /docker/stacks/services
docker compose up -d
```

---

## Bekannte Einschraenkungen und Pflicht-Pruefungen vor Produktion

- [ ] **Docker-Disk vorhanden**: `df -h /docker` muss als `/dev/sdb` (XFS) erscheinen.
      Wenn der Mount fehlt, ist die zweite Disk nicht erkannt worden — Proxmox-Konfiguration pruefen.
- [ ] **packer-User geloescht**: `getent passwd packer` muss leer sein.
- [ ] **Docker Daemon laeuft**: `docker info` und `systemctl status docker`.
- [ ] **Tailscale nicht verbunden**: `tailscale up --auth-key=...` noetig.
- [ ] **CrowdSec nicht enrollt**: `cscli lapi register` noetig.
- [ ] **Services-Stack nicht deployt**: Der Services-Stack (Watchtower, Autoheal etc.) ist
      nicht im Template enthalten — muss via Ansible oder Dockhand deployt werden.

---

## Voraussetzungen

Identisch zum Base-Template, zusaetzlich:

- Zweite Disk muss im Proxmox-Template vorhanden sein (wird automatisch im Build angelegt)
- `/docker` Partition muss nach dem Klonen als separater Mount erscheinen

---

## Verwandte Dokumentation

| Dokument | Pfad |
|---|---|
| Base-Hardening-Playbook | `ansible/playbooks/packer-hardening.yml` |
| Base-Template (2404) | `packer/linux/ubuntu-2404/README.md` |
| CI-Konfiguration | `.gitlab-ci.yml` (Jobs: `validate_ubuntu_2404_docker`, `build_ubuntu_2404_docker`, `rotate_latest_ubuntu_2404_docker`) |
| Docker-Hardening-Playbook | `ansible/playbooks/packer-hardening-docker.yml` |
| Docker-Template (2604) | `packer/linux/ubuntu-2604-docker/README.md` |
