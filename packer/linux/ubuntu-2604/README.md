# Template: Ubuntu 26.04 LTS (Base)

Generisches Ubuntu 26.04 LTS (Resolute Raccoon) Cloud-Init Template fuer Proxmox.
Inhaltlich identisch zum `ubuntu-2404`-Template — gleiche Hardening-Basis, gleiche
Service-Vorinstallation. Das Template wird parallel zu 24.04 gepflegt und dient fuer
VMs die Ubuntu 26.04 als Basis benoetigen.

**Hinweis:** Ubuntu 26.04 hat den Final-Release-Termin 23. April 2026. Bis dahin wird
dieses Template gegen die Beta-ISO gebaut (`ubuntu-26.04-beta-live-server-amd64.iso`).

## Eigenschaften

| Eigenschaft | Wert |
|---|---|
| Basis-OS | Ubuntu 26.04 LTS (Resolute Raccoon) |
| Bios | UEFI (OVMF) |
| Cloud-Init | Ja |
| Default CPU (Build) | 6 Cores (wird nach Build auf 4 zurueckgesetzt) |
| Default CPU (Template) | 4 Cores |
| Default Disk | 50G (raw, virtio-scsi-single, io_thread, discard) |
| Default RAM (Build) | 8192 MB (wird nach Build auf 4096 zurueckgesetzt) |
| Default RAM (Template) | 4096 MB |
| Default VM-ID-Bereich | 9600–9699 |
| EFI Disk | 4M, pre-enrolled keys |
| LUKS-Verschluesselung | Nein |
| Machine-Typ | q35 |
| Netzwerk-Bridge | vnet60 (CI), vmbr0 (HCL-Default) |
| QEMU Guest Agent | Ja |
| Scsi-Controller | virtio-scsi-single |
| Storage-Pool | nvme (CI), local-lvm (HCL-Default) |
| Template-Name | `tmpl-ubuntu-2604-YYYYMMDD-bNN` |
| TPM | 2.0 |

## Image-Aufbau

### Partitionierung

Identisch zum `ubuntu-2404`-Template: Subiquity Autoinstall mit `storage.layout.name: direct`.
Kein LVM — direktes Partitionslayout (EFI / boot / root ext4).

### Installierte Pakete

Identisch zum `ubuntu-2404`-Template. Das Hardening-Playbook `packer-hardening.yml`
ist dieselbe Datei fuer beide Versionen.

**Besonderheit Ubuntu 26.04:** Tailscale und Docker benoetigen einen APT-Suite-Fallback:

```yaml
tailscale_apt_suite: "{{ 'noble' if ansible_distribution_release in ['resolute'] else ansible_distribution_release }}"
docker_apt_suite: "{{ 'noble' if ansible_distribution_release in ['resolute'] else ansible_distribution_release }}"
```

Solange kein Tailscale/Docker-APT-Repo fuer `resolute` existiert, wird das `noble`-Repo
verwendet. Dieser Fallback ist in `packer-hardening.yml` und `packer-hardening-docker.yml`
implementiert. Commit `9af9a0a` hat `ansible_distribution_release` auf die korrekte
`ansible_facts['distribution_release']`-Syntax umgestellt.

### Aktivierte Services

Identisch zum `ubuntu-2404`-Template. Vollstaendige Liste: `packer/linux/ubuntu-2404/README.md`

### Hardening

Identisch zum `ubuntu-2404`-Template via `packer-hardening.yml`.
Details: `packer/linux/ubuntu-2404/README.md`

---

## Konfiguration — Was bewirkt welche Option?

### `ubuntu-2604.pkr.hcl` — Packer-Konfig

Identisch zum `ubuntu-2404.pkr.hcl` ausser:

| Variable | Default | Unterschied zu 2404 |
|---|---|---|
| `iso_file` | (Pflicht) | Zeigt auf `ubuntu-26.04-beta-live-server-amd64.iso` |
| `template_name` | `tmpl-ubuntu-2604` | Version 2604 |
| `vm_id` | `9600` | Bereich 9600–9699 |
| `vm_name` | `ubuntu-2604-packer` | Version 2604 |

Tags: `os-ubuntu;v-2604;packer;building;build-YYYYMMDD`

### `http/user-data` — Autoinstall-Konfig

Identisch zum `ubuntu-2404`-Template — gleiche Struktur, gleiche Pakete, gleiche late-commands.

Ein Unterschied im Kommentar zu `lock_passwd: false` (Commit `2c17618`): In der 26.04-Version
ist ein Kommentar zur packer-User-Cleanup-Strategie enthalten der erklaert warum der User
nicht via `runcmd` geloescht wird.

### `http/meta-data`

Leeres JSON-Objekt `{}` — identisch zu anderen Templates.

---

## Build-Pipeline (GitLab CI)

| Eigenschaft | Wert |
|---|---|
| Build-Job | `build_ubuntu_2604` |
| Deploy-Job | `rotate_latest_ubuntu_2604` |
| Pfad | `.gitlab-ci.yml` |
| Resource-Group | `packer_build_ubuntu_2604` |
| Timeout | 90 Minuten |
| Trigger (automatisch) | Push auf `main` mit Aenderungen unter `packer/linux/ubuntu-2604/`, `profiles/base.yml` oder `ansible/playbooks/packer-hardening.yml` |
| Trigger (manuell) | Pipeline-Start via GitLab UI (`web`) oder Schedule |
| Validate-Job | `validate_ubuntu_2604` |
| VM-ID-Bereich | 9600–9699 |

---

## Deployment

### Option A: Mit OpenTofu (empfohlen)

```hcl
module "my-vm-2604" {
  source = "../../modules/linux-vm"

  vm_name        = "my-vm-2604"
  vm_id          = 201
  proxmox_node   = "PVE1"
  template_id    = 9601  # aktuelle Template-ID (Tag: latest + os-ubuntu + v-2604)
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
tofu apply -target=module.my-vm-2604
```

### Option B: Direkte Proxmox-CLI

```bash
# Template-ID ermitteln (Tag: latest + os-ubuntu + v-2604)
pvesh get /nodes/PVE1/qemu --output-format json | \
  jq '[.[] | select(.tags != null) | select(.tags | contains("latest")) | select(.tags | contains("v-2604")) | select(.tags | contains("os-ubuntu"))]'

# Template klonen
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

Identisch zum `ubuntu-2404`-Template. Details: `packer/linux/ubuntu-2404/README.md`

```bash
cd /opt/homelab-management/infra/ansible
ansible-playbook playbooks/base-linux.yml -l <vm-name>
```

---

## Bekannte Einschraenkungen und Pflicht-Pruefungen vor Produktion

- [ ] **Beta-ISO**: Bis zum Final-Release (23. April 2026) wird gegen die Beta gebaut.
      Nach dem Release `iso_file` auf die finale ISO aktualisieren.
- [ ] **Tailscale APT**: Fallback auf `noble`-Repo solange kein `resolute`-Repo verfuegbar.
      Nach Verfuegbarkeit Playbook und CI-Variable aktualisieren.
- [ ] **Docker APT**: Identische Fallback-Situation — Fallback auf `noble`.
- [ ] Alle Punkte aus dem `ubuntu-2404`-Template gelten analog.

---

## Voraussetzungen

Identisch zum `ubuntu-2404`-Template. ISO-Pfad: `datacenter:iso/ubuntu-26.04-beta-live-server-amd64.iso`

---

## Verwandte Dokumentation

| Dokument | Pfad |
|---|---|
| Base-Hardening-Playbook | `ansible/playbooks/packer-hardening.yml` |
| Base-Template (2404) | `packer/linux/ubuntu-2404/README.md` |
| CI-Konfiguration | `.gitlab-ci.yml` (Jobs: `validate_ubuntu_2604`, `build_ubuntu_2604`, `rotate_latest_ubuntu_2604`) |
| Docker-Template (2604) | `packer/linux/ubuntu-2604-docker/README.md` |
