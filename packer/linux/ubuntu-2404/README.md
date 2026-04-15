# Template: Ubuntu 24.04 LTS (Base)

Generisches Ubuntu 24.04 LTS Cloud-Init Template fuer Proxmox. Dient als Basis fuer alle allgemeinen
VMs im HomeLab: Ansible-VMs, Utility-Services, Gateways, alles was kein Docker und keine
Vollverschluesselung benoetigt.

## Eigenschaften

| Eigenschaft | Wert |
|---|---|
| Basis-OS | Ubuntu 24.04 LTS (Noble Numbat) |
| Bios | UEFI (OVMF) |
| Cloud-Init | Ja |
| Default CPU (Build) | 6 Cores (wird nach Build auf 4 zurueckgesetzt) |
| Default CPU (Template) | 4 Cores |
| Default Disk | 50G (raw, virtio-scsi-single, io_thread, discard) |
| Default RAM (Build) | 8192 MB (wird nach Build auf 4096 zurueckgesetzt) |
| Default RAM (Template) | 4096 MB |
| Default VM-ID-Bereich | 9000–9099 |
| EFI Disk | 4M, pre-enrolled keys |
| LUKS-Verschluesselung | Nein |
| Machine-Typ | q35 |
| Netzwerk-Bridge | vnet60 (CI), vmbr0 (Default in HCL) |
| QEMU Guest Agent | Ja |
| Scsi-Controller | virtio-scsi-single |
| Storage-Pool | nvme (CI), local-lvm (HCL-Default) |
| Template-Name | `tmpl-ubuntu-2404-YYYYMMDD-bNN` |
| TPM | 2.0 |

## Image-Aufbau

### Partitionierung

Ubuntu Subiquity Autoinstall mit `storage.layout.name: direct` — kein LVM. Subiquity legt
selbst an: EFI-Partition, Boot-Partition, Root-Partition (ext4). Diese Aufteilung ist
einfacher zu klonen und erfordert kein LVM-Resize nach dem Klonen.

### Installierte Pakete (via Autoinstall)

Folgende Pakete werden waehrend des Subiquity-Autoinstalls installiert:

- `cloud-init`
- `curl`
- `openssh-server`
- `python3`
- `qemu-guest-agent`

Anschliessend laufen `package_update: true` und `package_upgrade: true` — das System ist beim
Packer-Build vollstaendig aktuell.

### Installierte Pakete (via Ansible `packer-hardening.yml`)

- `apt-transport-https`
- `ca-certificates`
- `chrony`
- `cloud-init`
- `console-setup`
- `crowdsec`
- `curl`
- `fail2ban`
- `git`
- `gnupg`
- `htop`
- `jq`
- `keyboard-configuration`
- `lsb-release`
- `openssh-server`
- `prometheus-node-exporter`
- `python3`
- `python3-pip`
- `qemu-guest-agent`
- `tailscale`
- `unattended-upgrades`
- `unzip`
- `vim`
- `wget`

### Aktivierte Services

| Service | Zustand im Template |
|---|---|
| chrony | aktiviert, gestartet |
| crowdsec | aktiviert, gestoppt (kein LAPI-Key im Template) |
| fail2ban | aktiviert, gestartet |
| prometheus-node-exporter | aktiviert, gestartet |
| qemu-guest-agent | aktiviert, gestartet |
| tailscaled | aktiviert, gestoppt (kein Auth-Key im Template) |

### Hardening

Das Hardening-Playbook `ansible/playbooks/packer-hardening.yml` ist die gemeinsame Basis fuer
alle Templates. Es konfiguriert:

- SSH: `PasswordAuthentication no`, `PermitRootLogin prohibit-password`
- SSH Drop-In `/etc/ssh/sshd_config.d/99-homelab-sshd.conf`: `MaxAuthTries 30`, `MaxSessions 10`
  (Bitwarden-Agent exportiert viele Keys parallel — Standard von 6 wuerde fehlschlagen)
- Authorized Keys fuer `root` und `ubuntu` User (beide HomeLab SSH-Keys)
- GRUB: `net.ifnames=0 biosdevname=0` (konsistentes Interface-Naming, wichtig fuer Clevis-LUKS)
- Netplan: Interface `enp6s18` → `eth0` umbenannt
- Cloud-Init Datasource auf `NoCloud, ConfigDrive, None` (kein cloud-seed-DHCP-Overhead)
- Locale: `de_DE.UTF-8`, Keyboard: `de`, Timezone: `Europe/Berlin`
- Automatische Security-Updates via `unattended-upgrades`
- Terminal-Fix: Mouse Tracking und Bracketed Paste systemweit deaktiviert
  (`/etc/inputrc`, `/etc/bash.bashrc`) — verhindert ANSI-Zeichensalat in Windows Terminal

Vollstaendiger Playbook-Pfad: `ansible/playbooks/packer-hardening.yml`

### Cleanup vor Template-Erstellung

- `cloud-init clean --logs` (saubere Cloud-Init-Initialisierung bei Clone-Start)
- `machine-id` geleert und als Symlink wiederhergestellt (eindeutige ID pro Clone)
- SSH Host-Keys geloescht (werden bei erstem Boot neu generiert)
- Bash-History geleert
- packer-User geloescht (`userdel -r packer`)
- APT Cache und `/tmp` bereinigt
- `fstrim --all` fuer duennere Disk-Images

---

## Konfiguration — Was bewirkt welche Option?

### `ubuntu-2404.pkr.hcl` — Packer-Konfig

| Variable | Default | Beschreibung |
|---|---|---|
| `ci_commit_ref` | `main` | Git Branch/Tag — wird in Template-Beschreibung eingetragen |
| `ci_commit_sha` | `unknown` | Git Commit SHA — wird in Template-Beschreibung eingetragen |
| `ci_pipeline_id` | `manual` | GitLab CI Pipeline-ID — wird in Template-Beschreibung eingetragen |
| `ci_pipeline_source` | `manual` | Trigger-Quelle (push, schedule, web) |
| `git_release_tag` | `unreleased` | Semantic-Release-Tag — erscheint in Template-Beschreibung |
| `iso_file` | (Pflicht) | Proxmox-Pfad zur ISO, z.B. `datacenter:iso/ubuntu-24.04.4-live-server-amd64.iso` |
| `proxmox_node` | (Pflicht) | Name des Proxmox-Nodes, z.B. `PVE1` |
| `proxmox_skip_tls` | `false` | TLS-Verifikation deaktivieren (fuer Self-Signed Zertifikate: `true`) |
| `proxmox_token` | (Pflicht, sensitiv) | Proxmox API-Token |
| `proxmox_url` | (Pflicht) | Proxmox API URL, z.B. `https://PVE1:8006/api2/json` |
| `proxmox_username` | (Pflicht) | Proxmox API-User mit Token, z.B. `terraform@pve!terraform-token` |
| `ssh_password` | `packer-build-only` | Temporaeres Passwort fuer SSH-Login waehrend Build — wird danach geloescht |
| `ssh_username` | `packer` | Temporaerer User waehrend Build |
| `template_name` | `tmpl-ubuntu-2404` | Proxmox Template-Name. CI ueberschreibt mit `tmpl-ubuntu-2404-YYYYMMDD-bNN` |
| `vm_bridge` | `vmbr0` | Netzwerk-Bridge. CI setzt `vnet60` (Build-VLAN) |
| `vm_cpu_cores` | `4` | CPU-Cores. CI baut mit 6 und setzt danach auf 4 zurueck |
| `vm_disk_size` | `50G` | OS-Disk-Groesse |
| `vm_id` | `9000` | VM-ID fuer den Build. CI findet naechste freie ID im Bereich 9000–9099 |
| `vm_memory` | `4096` | RAM in MB. CI baut mit 8192 und setzt danach auf 4096 zurueck |
| `vm_name` | `ubuntu-2404-packer` | VM-Name waehrend Build. CI setzt Pipeline-ID als Suffix |
| `vm_storage_pool` | `local-lvm` | Proxmox Storage-Pool. CI setzt `nvme` |

### `http/user-data` — Autoinstall-Konfig

| Abschnitt | Beschreibung |
|---|---|
| `identity` | Hostname `ubuntu-packer-build`, User `packer` mit SHA-512 Passwort `packer-build-only` |
| `keyboard` / `locale` / `timezone` | `de`, `de_DE.UTF-8`, `Europe/Berlin` |
| `network` | DHCP auf `enp6s18`, MTU 1500, DNS 172.16.60.1 + 1.1.1.1 |
| `packages` | Minimal-Set: openssh-server, qemu-guest-agent, python3, cloud-init, curl |
| `ssh` | SSH-Server aktiviert, Passwort-Login erlaubt (noetig fuer Packer), beide HomeLab-Keys |
| `storage.layout.name: direct` | Kein LVM — direktes Partitionslayout (EFI / boot / root) |
| `user-data.users` | packer-User mit `NOPASSWD sudo`, beide HomeLab SSH-Keys fuer packer und root |
| `late-commands` | qemu-guest-agent aktivieren, sudoers-Datei anlegen, Root-SSH-Keys setzen |

### `http/meta-data`

Leeres JSON-Objekt `{}`. Subiquity erwartet die Datei im HTTP-Verzeichnis, akzeptiert aber
auch einen leeren Body — die eigentlichen Metadaten kommen aus dem `user-data`-Abschnitt.

---

## Build-Pipeline (GitLab CI)

| Eigenschaft | Wert |
|---|---|
| Build-Job | `build_ubuntu_2404` |
| Deploy-Job | `rotate_latest_ubuntu_2404` |
| Pfad | `.gitlab-ci.yml` |
| Resource-Group | `packer_build_ubuntu_2404` (serialisiert Builds, verhindert Race Condition bei VM-IDs) |
| Timeout | 90 Minuten |
| Trigger (automatisch) | Push auf `main` mit Aenderungen unter `packer/linux/ubuntu-2404/`, `profiles/base.yml` oder `ansible/playbooks/packer-hardening.yml` |
| Trigger (manuell) | Pipeline-Start via GitLab UI (`web`) oder Schedule |
| Validate-Job | `validate_ubuntu_2404` |
| VM-ID-Bereich | 9000–9099 |

**Ablauf:**

1. `validate_ubuntu_2404` — `packer validate` mit Pflicht-Variablen
2. `build_ubuntu_2404` — findet naechste freie VM-ID im Bereich, baut mit 6 CPU/8 GB, setzt danach auf 4/4096 zurueck
3. `rotate_latest_ubuntu_2404` — setzt `latest`-Tag auf neue VM, entfernt `latest` von alten, behaelt max. 2 Templates

Der Deploy-Job benoetigt das Artefakt `build-artifacts/vm-id.txt` aus dem Build-Job.

---

## Deployment

### Option A: Mit OpenTofu (empfohlen)

```hcl
module "my-vm" {
  source = "../../modules/linux-vm"

  vm_name        = "my-vm"
  vm_id          = 200
  proxmox_node   = "PVE1"
  template_id    = 9042  # aktuelle Template-VM-ID aus Proxmox (Tag: latest + os-ubuntu + v-2404)
  cpu_cores      = 2
  memory         = 2048
  storage_pool   = "nvme"
  network_bridge = "vnet10"
  ip_address     = "dhcp"
  ci_user        = "ubuntu"
  ssh_keys       = ["ssh-ed25519 AAAA..."]
}
```

```bash
tofu apply -target=module.my-vm
```

### Option B: Direkte Proxmox-CLI

```bash
# Template-ID der aktuellen Version ermitteln (Tag: latest + os-ubuntu + v-2404)
pvesh get /nodes/PVE1/qemu --output-format json | \
  jq '[.[] | select(.tags != null) | select(.tags | contains("latest")) | select(.tags | contains("v-2404")) | select(.tags | contains("os-ubuntu"))]'

# Template klonen (full clone)
qm clone <template-id> <target-vmid> --name <vm-name> --full true

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

# Inventar pruefen / ergaenzen
vim inventory/hosts.yml

# Basis-Onboarding
ansible-playbook playbooks/base-linux.yml -l <vm-name>

# Docker-Node Onboarding (nur fuer Docker-VMs)
ansible-playbook playbooks/setup-docker-node.yml -l <vm-name>
```

Das `base-linux.yml`-Playbook konfiguriert Tailscale-Key, CrowdSec-Enrollment, Hostname und
weitere Node-spezifische Einstellungen die im Template bewusst leer bleiben.

### Option 2: Manuell (Schritt fuer Schritt)

```bash
# 1. SSH-Verbindung
ssh -i ~/.ssh/id_ed25519_homelab_nodes root@<ip>

# 2. Tailscale einrichten
tailscale up --auth-key=<tskey-auth-...> --hostname=<hostname>

# 3. CrowdSec-Agent enrollen
cscli lapi register --url http://<crowdsec-lapi>:8080 --key <enrollment-key>
systemctl start crowdsec

# 4. Prometheus Node Exporter — laeuft bereits, Scrape-Config in prometheus.yml ergaenzen

# 5. packer-User sollte durch Cleanup bereits geloescht sein
# Pruefung: getent passwd packer
```

---

## Bekannte Einschraenkungen und Pflicht-Pruefungen vor Produktion

- [ ] **packer-User**: Der Cleanup-Schritt (`userdel -r packer`) laeuft im Build und sollte
      den User entfernen. Pruefung nach dem Klonen: `getent passwd packer` — sollte leer sein.
- [ ] **Tailscale nicht verbunden**: `tailscaled` ist aktiv aber ohne Auth-Key. Node ist erst
      nach `tailscale up --auth-key=...` im Tailscale-Netzwerk sichtbar.
- [ ] **CrowdSec nicht enrollt**: Service laeuft gestoppt. Enrollment via Ansible-Playbook oder
      manuell noetig bevor CrowdSec scharfgeschaltet werden kann.
- [ ] **SSH Host-Keys neu**: Werden beim ersten Boot generiert. `known_hosts` beim ersten
      Verbinden aktualisieren.
- [ ] **ISO-Pfad pruefen**: Bei neuem Ubuntu-Minor-Release (z.B. 24.04.5) muss `iso_file`
      in der pkrvars-Datei oder CI-Variable aktualisiert werden.

---

## Voraussetzungen

- Proxmox-Node PVE1 erreichbar
- Packer Build-Runner (`hhbuild01`) mit Proxmox API-Token (`terraform@pve!terraform-token`)
- GitLab CI-Variablen gesetzt: `PKR_VAR_proxmox_url`, `PKR_VAR_proxmox_username`, `PKR_VAR_proxmox_token`, `PKR_VAR_proxmox_node`
- Ubuntu ISO unter `datacenter:iso/ubuntu-24.04.4-live-server-amd64.iso` auf Proxmox hochgeladen
- Build-VLAN (vnet60) hat DHCP und Internet-Zugang (APT, Tailscale-APT, Docker-APT, CrowdSec-APT)

---

## Verwandte Dokumentation

| Dokument | Pfad |
|---|---|
| Base-Hardening-Playbook | `ansible/playbooks/packer-hardening.yml` |
| CI-Konfiguration | `.gitlab-ci.yml` (Jobs: `validate_ubuntu_2404`, `build_ubuntu_2404`, `rotate_latest_ubuntu_2404`) |
| Docker-Template (2404) | `packer/linux/ubuntu-2404-docker/README.md` |
| LUKS-Template (2404) | `packer/linux/ubuntu-2404-luks/README.md` |
| Ubuntu 26.04 Variante | `packer/linux/ubuntu-2604/README.md` |
