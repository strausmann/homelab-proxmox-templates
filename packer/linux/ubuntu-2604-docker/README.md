# Template: Ubuntu 26.04 LTS Docker-Node

Ubuntu 26.04 LTS (Resolute Raccoon) Template fuer Docker-Nodes. Identisch zum
`ubuntu-2404-docker`-Template in Struktur und Funktion — gleiche zweite Docker-Disk,
gleiche Docker CE Installation, gleiche Daemon-Konfiguration. Unterschied: Ubuntu 26.04
als Basis und entsprechender APT-Suite-Fallback fuer noch nicht portierte Repositories.

**Hinweis:** Ubuntu 26.04 hat den Final-Release-Termin 23. April 2026. Bis dahin wird
dieses Template gegen die Beta-ISO gebaut.

## Eigenschaften

| Eigenschaft | Wert |
|---|---|
| Basis-OS | Ubuntu 26.04 LTS (Resolute Raccoon) |
| Bios | UEFI (OVMF) |
| Cloud-Init | Ja |
| Default CPU (Build) | 6 Cores (wird nach Build auf 4 zurueckgesetzt) |
| Default CPU (Template) | 4 Cores |
| Default Docker-Disk | 300G (raw, virtio-scsi-single, XFS, mount: /docker) |
| Default OS-Disk | 50G (raw, virtio-scsi-single, io_thread, discard) |
| Default RAM (Build) | 8192 MB (wird nach Build auf 4096 zurueckgesetzt) |
| Default RAM (Template) | 4096 MB |
| Default VM-ID-Bereich | 9700–9799 |
| Docker CE | vorinstalliert, data-root: /docker |
| EFI Disk | 4M, pre-enrolled keys |
| LUKS-Verschluesselung | Nein |
| Machine-Typ | q35 |
| Netzwerk-Bridge | vnet60 (CI), vmbr0 (HCL-Default) |
| QEMU Guest Agent | Ja |
| Scsi-Controller | virtio-scsi-single |
| Storage-Pool | nvme (CI), local-lvm (HCL-Default) |
| Template-Name | `tmpl-ubuntu-docker-2604-YYYYMMDD-bNN` |
| TPM | 2.0 |

## Image-Aufbau

### Partitionierung

Identisch zum `ubuntu-2404-docker`-Template. Subiquity Direct-Layout fuer OS-Disk,
zweite Disk (`/dev/sdb`, 300G) via Ansible mit XFS formatiert und als `/docker` gemountet.

Disk-Layout nach Build:

| Disk | Groesse | Dateisystem | Mountpoint |
|---|---|---|---|
| `/dev/sda` | 50G | ext4 (via direct layout) | `/` |
| `/dev/sdb` | 300G | XFS | `/docker` |

### Docker-Spezifika

Identisch zum `ubuntu-2404-docker`-Template. Docker CE via offiziellem APT-Repo,
Daemon-Konfiguration identisch, `/docker/stacks/` als Standard-Stack-Verzeichnis.

**APT-Suite-Fallback:** Wenn kein `resolute`-Docker-APT-Repo verfuegbar ist, wird
automatisch `noble` verwendet:

```yaml
docker_apt_suite: "{{ 'noble' if ansible_distribution_release in ['resolute'] else ansible_distribution_release }}"
```

Vollstaendige Docker-Konfiguration: `packer/linux/ubuntu-2404-docker/README.md`

### Installierte Pakete

Identisch zum `ubuntu-2404-docker`-Template.
Details: `packer/linux/ubuntu-2404-docker/README.md`

### Aktivierte Services

Identisch zum `ubuntu-2404-docker`-Template. Docker ist aktiviert und gestartet.

### Hardening

Identisch zum `ubuntu-2404`-Template via `packer-hardening.yml` (Phase 1 von `packer-hardening-docker.yml`).

---

## Konfiguration — Was bewirkt welche Option?

### `ubuntu-2604-docker.pkr.hcl` — Packer-Konfig

Identisch zum `ubuntu-2404-docker.pkr.hcl` ausser:

| Variable | Default | Unterschied zu 2404-docker |
|---|---|---|
| `iso_file` | (Pflicht) | Zeigt auf `ubuntu-26.04-beta-live-server-amd64.iso` |
| `template_name` | `tmpl-ubuntu-2604-docker` | Version 2604 |
| `vm_id` | `9700` | Bereich 9700–9799 |
| `vm_name` | `ubuntu-2604-docker-packer` | Version 2604 |

Tags: `os-ubuntu;v-2604;docker;packer;building;build-YYYYMMDD`

`boot_wait = "15s"` — identisch zu 2404-docker (zwei Disks benoetigen laengere UEFI-Init).

### `http/user-data` — Autoinstall-Konfig

Identisch zum `ubuntu-2404-docker`-Template.

### `http/meta-data`

Leeres JSON-Objekt `{}`.

---

## Build-Pipeline (GitLab CI)

| Eigenschaft | Wert |
|---|---|
| Build-Job | `build_ubuntu_2604_docker` |
| Deploy-Job | `rotate_latest_ubuntu_2604_docker` |
| Pfad | `.gitlab-ci.yml` |
| Resource-Group | `packer_build_ubuntu-docker_2604` |
| Timeout | 90 Minuten |
| Trigger (automatisch) | Push auf `main` mit Aenderungen unter `packer/linux/ubuntu-2604-docker/`, `packer/linux/ubuntu-2604/`, `profiles/base.yml`, `ansible/playbooks/packer-hardening.yml` oder `ansible/playbooks/packer-hardening-docker.yml` |
| Trigger (manuell) | Pipeline-Start via GitLab UI (`web`) oder Schedule |
| Validate-Job | `validate_ubuntu_2604_docker` |
| VM-ID-Bereich | 9700–9799 |

---

## Deployment

### Option A: Mit OpenTofu (empfohlen)

```hcl
module "hhdocker05-2604" {
  source = "../../modules/linux-vm"

  vm_name        = "hhdocker05"
  vm_id          = 105
  proxmox_node   = "PVE1"
  template_id    = 9701  # aktuelle ID (Tag: latest + os-ubuntu-docker + v-2604)
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
tofu apply -target=module.hhdocker05-2604
```

### Option B: Direkte Proxmox-CLI

```bash
# Template-ID ermitteln (Tag: latest + os-ubuntu-docker + v-2604)
pvesh get /nodes/PVE1/qemu --output-format json | \
  jq '[.[] | select(.tags != null) | select(.tags | contains("latest")) | select(.tags | contains("v-2604")) | select(.tags | contains("os-ubuntu-docker"))]'

# Template klonen
qm clone <template-id> <target-vmid> --name hhdocker05 --full true

# Cloud-Init konfigurieren
qm set <target-vmid> --ipconfig0 ip=dhcp
qm set <target-vmid> --sshkey ~/.ssh/id_ed25519_homelab_nodes.pub
qm set <target-vmid> --ciuser ubuntu

# Starten
qm start <target-vmid>
```

---

## Onboarding (nach Deployment)

Identisch zum `ubuntu-2404-docker`-Template.
Details: `packer/linux/ubuntu-2404-docker/README.md`

```bash
cd /opt/homelab-management/infra/ansible
ansible-playbook playbooks/setup-docker-node.yml -l hhdocker05
```

---

## Bekannte Einschraenkungen und Pflicht-Pruefungen vor Produktion

- [ ] **Beta-ISO**: Bis zum Final-Release (23. April 2026) wird gegen Beta gebaut.
      Nach dem Release `iso_file` auf finale ISO aktualisieren.
- [ ] **Tailscale APT**: Fallback auf `noble`-Repo aktiv.
- [ ] **Docker APT**: Fallback auf `noble`-Repo aktiv.
- [ ] **Docker-Disk**: `df -h /docker` muss als `/dev/sdb` (XFS, 300G) gemountet sein.
- [ ] Alle weiteren Punkte aus dem `ubuntu-2404-docker`-Template gelten analog.

---

## Voraussetzungen

Identisch zum `ubuntu-2404-docker`-Template. ISO-Pfad:
`datacenter:iso/ubuntu-26.04-beta-live-server-amd64.iso`

---

## Verwandte Dokumentation

| Dokument | Pfad |
|---|---|
| Base-Hardening-Playbook | `ansible/playbooks/packer-hardening.yml` |
| Base-Template (2604) | `packer/linux/ubuntu-2604/README.md` |
| CI-Konfiguration | `.gitlab-ci.yml` (Jobs: `validate_ubuntu_2604_docker`, `build_ubuntu_2604_docker`, `rotate_latest_ubuntu_2604_docker`) |
| Docker-Hardening-Playbook | `ansible/playbooks/packer-hardening-docker.yml` |
| Docker-Template (2404) | `packer/linux/ubuntu-2404-docker/README.md` |
