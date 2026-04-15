# Template: Ubuntu 24.04 LTS LUKS (verschluesselte OS-Disk)

Ubuntu 24.04 LTS Template mit LUKS2-verschluesselter OS-Disk. Gedacht fuer VMs mit erhoehtem
Schutzbedarf, z.B. VMs mit Credentials, interne Gateways oder Nodes mit sensitiven Daten.

Das Template liefert eine fertig verschluesselte VM mit automatischem Unlock waehrend des
Builds (via Keyfile im initramfs). Nach dem Deployment bindet die Ansible-Role `clevis-tang-bind`
den Tang-Server ein und entfernt alle Build-Artefakte (Keyfile, Keyslot, initramfs-Embedding).
Die produktive VM entsperrt sich dann automatisch via Tang-Server.

## Eigenschaften

| Eigenschaft | Wert |
|---|---|
| Basis-OS | Ubuntu 24.04 LTS (Noble Numbat) |
| Bios | UEFI (OVMF) |
| Cloud-Init | Ja |
| Default CPU (Build) | 6 Cores (wird nach Build auf 4 zurueckgesetzt) |
| Default CPU (Template) | 4 Cores |
| Default Disk | 50G (raw, virtio-scsi-single) |
| Default RAM (Build) | 8192 MB (wird nach Build auf 4096 zurueckgesetzt) |
| Default RAM (Template) | 4096 MB |
| Default VM-ID-Bereich | 9050–9099 |
| EFI Disk | 4M, pre-enrolled keys |
| LUKS-Verschluesselung | Ja (LUKS2 auf `/dev/sda3`) |
| Machine-Typ | q35 |
| Netzwerk-Bridge | vnet60 (CI), vmbr0 (HCL-Default) |
| QEMU Guest Agent | Ja |
| Scsi-Controller | virtio-scsi-single |
| Storage-Pool | nvme (CI), local-lvm (HCL-Default) |
| Template-Name | `tmpl-ubuntu-luks-2404-YYYYMMDD-bNN` |
| TPM | 2.0 |

## Image-Aufbau

### Partitionierung

Das LUKS-Template verwendet ein explizites Subiquity-Storage-Layout (kein `name: direct`):

| Partition | Groesse | Typ | Mountpoint |
|---|---|---|---|
| `/dev/sda1` | 512M | EFI (fat32) | `/boot/efi` |
| `/dev/sda2` | 1G | ext4 | `/boot` |
| `/dev/sda3` | Rest | LUKS2 (`dm_crypt`) | — |
| `crypt-root` | — | ext4 (auf LUKS) | `/` |

`/boot` liegt ausserhalb von LUKS — der Kernel und initramfs sind unverschluesselt,
GRUB kann ohne Passwort booten. Die gesamte Root-Partition ist verschluesselt.

### LUKS-Keyslot-Belegung im Template-Zustand

| Keyslot | Inhalt | Verwendung |
|---|---|---|
| 0 | `packer-build-only` | Build-Passphrase — **muss post-deploy entfernt werden** |
| 4 | `/etc/cryptsetup-keys.d/luks-keyfile.key` | Automatischer Unlock waehrend Build, im initramfs eingebettet |

Nach dem Deployment via `clevis-tang-bind`-Playbook:

| Keyslot | Inhalt | Verwendung |
|---|---|---|
| 0 | (entfernt, optional) | — |
| 3 | Tang-Server-Binding (Clevis) | Produktiver Auto-Unlock via Tang |
| 4 | (entfernt) | — |

### Wie der automatische Build-Unlock funktioniert

Das Problem: Subiquity installiert Ubuntu und startet danach neu. Packer muss sich nach dem
Neustart via SSH verbinden — aber das LUKS-Passwort wird nicht automatisch eingegeben.

Die Loesung (Pfad B, Issue #214): Ein Keyfile wird als regulaere Datei in
`/etc/cryptsetup-keys.d/luks-keyfile.key` abgelegt und als LUKS-Keyslot 4 registriert.
`cryptsetup-initramfs` bettet das Keyfile via `KEYFILE_PATTERN` ins initramfs ein.
Beim Reboot entsperrt das initramfs LUKS automatisch ohne Benutzerinteraktion.

Nach dem Packer-Build ist das Keyfile noch vorhanden — es wird durch die Ansible-Role
`clevis-tang-bind` post-deployment entfernt.

### Installierte Pakete

Identisch zum Base-Template — das Playbook `packer-hardening.yml` wird verwendet.
Vollstaendige Liste: `packer/linux/ubuntu-2404/README.md`

LUKS-spezifische Pakete (vorinstalliert durch Ubuntu):

- `cryptsetup`
- `cryptsetup-initramfs`
- `clevis` (wird post-deploy via Ansible installiert)
- `clevis-luks`
- `clevis-tpm2`
- `tang` (laeuft auf gesondertem Tang-Server, nicht auf dieser VM)

### Aktivierte Services

Identisch zum Base-Template. Kein LUKS-spezifischer Service wird im Template gestartet —
das Tang-Binding ist nicht Teil des Templates.

### Hardening

Identisch zum Base-Template (`packer-hardening.yml`). Siehe `packer/linux/ubuntu-2404/README.md`.

---

## Konfiguration — Was bewirkt welche Option?

### `ubuntu-2404-luks.pkr.hcl` — Packer-Konfig

Alle Standard-Variablen gelten analog zum Base-Template. Zusaetzliche Variablen:

| Variable | Default | Beschreibung |
|---|---|---|
| `luks_passphrase` | `packer-build-only` (sensitiv) | LUKS-Build-Passphrase fuer Keyslot 0. Wird in CI aus Vault gesetzt. Muss post-deploy via Ansible rotiert oder entfernt werden |
| `tang_url` | (Pflicht) | Tang-Server URL, z.B. `http://172.16.60.20:7500`. Wird in der Template-Beschreibung eingetragen. Das eigentliche Tang-Binding erfolgt aber post-deploy, nicht im Template |
| `vm_id` | `9050` | Standardmaessig im LUKS-Bereich (9050–9099) |

Wichtiger Unterschied zum Base-Template: Das Ansible-Playbook ist `packer-hardening.yml`
(nicht `packer-hardening-docker.yml`), aber mit explizitem `ansible_remote_tmp=/tmp/.ansible-packer` —
notwendig weil der GitLab-Runner-Host einen anderen Home-Pfad als die Target-VM hat.

### `http/user-data` — Autoinstall-Konfig

Der groesste Unterschied zum Base-Template liegt im `storage`-Abschnitt und den `late-commands`.

**Storage-Abschnitt:**

Explizites partitionslayout statt `direct`:
- `disk0` → GPT-Tabelle
- `esp` (512M, fat32, `/boot/efi`)
- `boot-part` (1G, ext4, `/boot`)
- `luks-part` (Rest, LUKS2 dm_crypt mit Passphrase `packer-build-only`)
- `root-format` (ext4 auf LUKS, `/`)

**late-commands (LUKS-spezifisch):**

1. Keyfile anlegen: `dd if=/dev/urandom of=/etc/cryptsetup-keys.d/luks-keyfile.key bs=4096 count=1`
2. Keyfile als Keyslot 4 registrieren: `cryptsetup luksAddKey --key-slot 4 /dev/disk/by-uuid/...`
3. `/etc/crypttab` umschreiben: `crypt-root UUID=... /etc/cryptsetup-keys.d/luks-keyfile.key luks,keyfile-size=4096,discard`
4. `KEYFILE_PATTERN=/etc/cryptsetup-keys.d/*.key` in `/etc/cryptsetup-initramfs/conf-hook`
5. `UMASK=0077` in `/etc/initramfs-tools/initramfs.conf`
6. `update-initramfs -u -k all` — Keyfile ins initramfs einbetten
7. GRUB-Cmdline bereinigen: `autoinstall` und `ds=nocloud-net` entfernen (Defekte #5 + #6)

**Wichtig:** Der packer-User-Cleanup erfolgt **nicht** in `late-commands` und auch **nicht**
via Cloud-Init `runcmd`. Er wird durch die Ansible-Role `clevis-tang-bind` post-deployment
erledigt. Frueherer Cleanup-Versuch fuehrte zu Race Condition (SSH-Session zur Zombie-Session,
Exit 254, Commit `1901f6b`).

---

## Build-Pipeline (GitLab CI)

| Eigenschaft | Wert |
|---|---|
| Build-Job | `build_ubuntu_2404_luks` |
| Deploy-Job | `rotate_latest_ubuntu_2404_luks` |
| Pfad | `.gitlab-ci.yml` |
| Resource-Group | `packer_build_ubuntu-luks_2404` |
| Timeout | 90 Minuten |
| Trigger (automatisch) | Push auf `main` mit Aenderungen unter `packer/linux/ubuntu-2404-luks/`, `packer/linux/ubuntu-2404/`, `profiles/base.yml` oder `ansible/playbooks/packer-hardening.yml` |
| Trigger (manuell) | Pipeline-Start via GitLab UI (`web`) oder Schedule |
| Validate-Job | `validate_ubuntu_2404_luks` |
| VM-ID-Bereich | 9050–9099 |

---

## Deployment

### Option A: Mit OpenTofu (empfohlen)

```hcl
module "luks-vm" {
  source = "../../modules/linux-vm"

  vm_name        = "luks-vm"
  vm_id          = 150
  proxmox_node   = "PVE1"
  template_id    = 9051  # aktuelle LUKS-Template-ID (Tag: latest + os-ubuntu-luks + v-2404)
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
tofu apply -target=module.luks-vm
```

### Option B: Direkte Proxmox-CLI

```bash
# Template-ID ermitteln (Tag: latest + os-ubuntu-luks + v-2404)
pvesh get /nodes/PVE1/qemu --output-format json | \
  jq '[.[] | select(.tags != null) | select(.tags | contains("latest")) | select(.tags | contains("v-2404")) | select(.tags | contains("os-ubuntu-luks"))]'

# Template klonen
qm clone <template-id> <target-vmid> --name luks-vm --full true

# Cloud-Init konfigurieren
qm set <target-vmid> --ipconfig0 ip=dhcp
qm set <target-vmid> --sshkey ~/.ssh/id_ed25519_homelab_nodes.pub
qm set <target-vmid> --ciuser ubuntu

# Starten — VM entsperrt sich automatisch via Keyfile im initramfs
qm start <target-vmid>
```

---

## Onboarding (nach Deployment) — LUKS-Haertung

### Option 1: Mit Ansible (empfohlen)

```bash
cd /opt/homelab-management/infra/ansible

# LUKS-Binding + Keyfile-Cleanup (clevis-tang-bind Role)
ansible-playbook playbooks/encrypt-vm-tang.yml -l luks-vm
```

Das Playbook erledigt in einem Durchgang:

1. `cryptsetup reencrypt /dev/sda3` — neuer Master Key (VM-unique, verhindert Template-Klon-Angriff)
2. `clevis luks bind -d /dev/sda3 tang '{"url":"http://172.16.60.20:7500"}'` — Tang-Keyslot 3
3. `cryptsetup luksKillSlot /dev/sda3 4` — Keyfile-Slot entfernen
4. `rm /etc/cryptsetup-keys.d/luks-keyfile.key` — Keyfile loeschen
5. `update-initramfs -u -k all` — Keyfile aus initramfs entfernen
6. Build-Passphrase aus Keyslot 0 entfernen oder rotieren
7. packer-User loeschen

### Option 2: Manuell (Schritt fuer Schritt)

```bash
ssh -i ~/.ssh/id_ed25519_homelab_nodes root@<ip>

# 1. Sicherstellen dass LUKS auf /dev/sda3 liegt
cryptsetup isLuks /dev/sda3 && echo "OK"
cryptsetup luksDump /dev/sda3 | grep -E "^  [0-9]+: luks2"
# Erwartete Ausgabe: Keyslot 0 (passphrase) und Keyslot 4 (keyfile)

# 2. Master Key re-encrypten (VM-unique machen)
cryptsetup reencrypt /dev/sda3

# 3. Tang-Binding hinzufuegen
clevis luks bind -d /dev/sda3 tang '{"url":"http://172.16.60.20:7500"}'
# Keyslot 3 wird belegt

# 4. Keyfile-Slot entfernen
cryptsetup luksKillSlot /dev/sda3 4

# 5. Keyfile loeschen
rm /etc/cryptsetup-keys.d/luks-keyfile.key

# 6. initramfs ohne Keyfile neu bauen
# Zuerst KEYFILE_PATTERN aus conf-hook entfernen:
sed -i '/KEYFILE_PATTERN/d' /etc/cryptsetup-initramfs/conf-hook
update-initramfs -u -k all

# 7. Pruefung: Keyslot 4 weg, Keyslot 3 (Tang) vorhanden
cryptsetup luksDump /dev/sda3 | grep -E "^  [0-9]+: luks2"

# 8. Build-Passphrase aus Keyslot 0 entfernen
# (vorher sicherstellen dass Tang-Auto-Unlock funktioniert — Testboot!)
cryptsetup luksKillSlot /dev/sda3 0

# 9. packer-User loeschen
userdel -r packer 2>/dev/null || true

# 10. Reboot — VM muss sich automatisch via Tang entsperren
reboot
```

**Wichtig:** Vor dem Loeschen von Keyslot 0 unbedingt pruefen ob Tang-Auto-Unlock
funktioniert (Testboot). Sonst ist die VM nicht mehr entsperrbar.

---

## Bekannte Einschraenkungen und Pflicht-Pruefungen vor Produktion

- [ ] **LUKS-Master-Key nicht rotiert**: Im Template-Zustand haben alle Klone denselben Master Key.
      `cryptsetup reencrypt` ist Pflicht post-deploy — sonst kann ein anderer Klon den LUKS-Header
      imitieren.
- [ ] **Keyfile noch vorhanden**: `/etc/cryptsetup-keys.d/luks-keyfile.key` MUSS geloescht werden.
      Solange es existiert, ist die Verschluesselung nicht wirksam (Keyfile im initramfs = kein Schutz).
- [ ] **Tang-Binding fehlt**: Ohne Tang-Binding entsperrt sich die VM nach dem Entfernen des Keyfiles
      nicht mehr automatisch. Reihenfolge: erst Tang binden, dann Keyfile entfernen.
- [ ] **Build-Passphrase in Keyslot 0**: Solange Keyslot 0 mit `packer-build-only` belegt ist,
      ist die VM mit diesem bekannten Passwort entsperrbar. Post-deploy entfernen.
- [ ] **Tang-Server erreichbar**: Tang-Server `http://172.16.60.20:7500` muss erreichbar sein.
      Bei Tang-Server-Ausfall kann die VM nicht gestartet werden (ausser Passphrase ist gesetzt).
- [ ] **packer-User geloescht**: `getent passwd packer` muss leer sein.
- [ ] **Testboot nach Tang-Binding**: Vor dem Loeschen von Keyslot 0 Neustart durchfuehren
      und pruefen ob Tang-Auto-Unlock funktioniert.

---

## Voraussetzungen

- Proxmox-Node PVE1 erreichbar
- Packer Build-Runner (`hhbuild01`) mit Proxmox API-Token
- Tang-Server unter `http://172.16.60.20:7500` erreichbar (aus Build-VLAN 60)
- CI-Variablen: alle aus Base-Template, zusaetzlich `tang_url` (oder CI-Default)
- Ubuntu ISO auf Proxmox vorhanden

---

## Verwandte Dokumentation

| Dokument | Pfad |
|---|---|
| Base-Hardening-Playbook | `ansible/playbooks/packer-hardening.yml` |
| Base-Template (2404) | `packer/linux/ubuntu-2404/README.md` |
| CI-Konfiguration | `.gitlab-ci.yml` (Jobs: `validate_ubuntu_2404_luks`, `build_ubuntu_2404_luks`, `rotate_latest_ubuntu_2404_luks`) |
| Clevis/Tang Skill | `.claude/skills/clevis-tang/` (im homelab-management Repo) |
| LUKS Skill | `.claude/skills/luks-encryption/` (im homelab-management Repo) |
| Recherche Keyfile-Workflow | `docs/research/2026-04-14-packer-luks-keyfile-reencrypt-workflow.md` |
