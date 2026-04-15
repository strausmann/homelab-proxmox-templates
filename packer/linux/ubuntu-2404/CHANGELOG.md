# Changelog — Template: Ubuntu 24.04 LTS (Base)

Alle nennenswerten Aenderungen an diesem Template. Format nach
[Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

Aenderungen am gemeinsamen Hardening-Playbook (`ansible/playbooks/packer-hardening.yml`)
sind ebenfalls aufgefuehrt, da sie dieses Template direkt betreffen.

---

## [Unreleased]

---

## [2026-04] — 2026-04-15

### Changed

- Ansible: `ansible_facts` statt veraltete `ansible_distribution_release` Variable
  (Commit `9af9a0a`)
- Hardening: Netplan-Interface-Suche via `find`-Modul statt `fileglob`
  — behebt Fehler in Pipeline 25732 (Commit `7aa5e3d`)
- Hardening: GRUB-Option `net.ifnames=0 biosdevname=0` hinzugefuegt
  — konsistentes Interface-Naming, Voraussetzung fuer Clevis/Tang Auto-Unlock (Commit `707874c`)

---

## [2026-04-a] — 2026-04-14

### Added

- Hardening: SSH Drop-In `/etc/ssh/sshd_config.d/99-homelab-sshd.conf` via `curtin in-target`
  — `PasswordAuthentication no` greift erst im installierten System, nicht im Live-Installer
  (Commit `0ca5217`)
- Hardening: `MaxAuthTries 30` in SSH Drop-In — Bitwarden SSH-Agent exportiert viele Keys parallel,
  OpenSSH-Default von 6 wuerde vor dem richtigen Key abbrechen (Commit `f872a5a`)
- Hardening: `PasswordAuthentication no` dauerhaft gesetzt (Commit `b2a8891`)

---

## [2026-04-b] — 2026-04-13

### Changed

- Partitionierung: LVM durch Direct-Layout ersetzt (`storage.layout.name: direct`) — einfacheres
  Klonen ohne LVM-Resize (Commit `2c17618`)
- Terminal-Fix: Mouse Tracking und Bracketed Paste werden jetzt via Ansible-Tasks gesetzt statt
  Shell-Provisioner (Commit `2c17618`)
- Cleanup: packer-User-Loeschung (`userdel -r packer`) in Packer-Cleanup-Provisioner verlagert
  (Commit `2c17618`)

---

## [2026-04-c] — 2026-04-04

### Fixed

- Terminal: SGR Mouse Tracking und Bracketed Paste systemweit deaktiviert via `/etc/inputrc`
  und `/etc/bash.bashrc` — behebt ANSI-Zeichensalat in Windows Terminal (Commit `2c63a94`)

---

## [2026-04-d] — 2026-04-02

### Fixed

- CI: Weitere Review-Fixes nach PR #2 (Commit `47edb27`)

---

## [2026-03-b] — 2026-03-31

### Fixed

- Netzwerk: DHCP statt statischer IP in user-data (VLAN 60 DHCP funktioniert waehrend Autoinstall)
  (Commit `cdf5f59`)
- CI: Release-Job Fixes (Commit `cdf5f59`)
- apt-Lock: Warte-Loop vor Ansible-Provisioner eingefuehrt (Commit `2000a66`)
- user-data: qemu-guest-agent zurueck in packages-Liste (Packer benoetigt ihn fuer IP-Erkennung)
  (Commit `8436757`)
- Build-Specs: 6 CPU / 8 GB RAM waehrend Build, Template-Defaults 4 CPU / 4 GB RAM danach
  (Commit `6137d2c`)

### Added

- CI: `building`-Tag auf Template waehrend Build, wird nach Abschluss durch `latest` ersetzt
  (Commit `c5cd000`)
- CI: Cloud-Init-Wait korrigiert zu `sudo cloud-init status --wait` (Commit `447458f`)
- CI: Tag-Lifecycle — individuelle Jobs pro Template, max. 2 Templates pro Version behalten
  (Commit `8719a44`)

---

## [2026-03-a] — 2026-03-30

### Added

- Erste funktionierende Version des Ubuntu 24.04 LTS Templates (Commit `8804413`)
- Template-Description mit Build-Metadaten und GitLab Release-Links (Commit `778afad`)
- Proxmox Tags: `os-ubuntu`, `v-2404`, `packer`, `build-YYYYMMDD` (Commit `fe67e20`)
- Build-Metadaten-Variablen: `ci_pipeline_id`, `ci_pipeline_source`, `ci_commit_sha`,
  `ci_commit_ref`, `git_release_tag` (Commit `0ed77ad`)
- Beide HomeLab SSH-Keys in user-data und Ansible (Commit `0ed77ad`)
- TPM 2.0, UEFI (OVMF), Q35 Machine-Typ, NUMA aktiviert (Commit `95e4fd5`)
- RAM-Ballooning deaktiviert (`ballooning_minimum=0`) (Commit `2625b1a`)
- Base-Profil mit Tailscale, CrowdSec, fail2ban, chrony, Prometheus Node Exporter
  (Commit `fe11044`)

### Fixed

- Proxmox Tags: Sonderzeichen entfernt (Proxmox erlaubt nur `a-zA-Z0-9_-;`) (Commit `d09da65`)
- DNS-Server explizit in user-data gesetzt (Commit `2963ead`)
- Interface `enp6s18` statt `ens18` (q35 Machine nutzt PCI-Pfad-basiertes Naming) (Commit `734390b`)
- MTU 1500 explizit gesetzt (vnet60 hat Jumbo Frames 9000 — wuerde Autoinstall-DHCP stoeren)
  (Commit `a3eac89`, `e01ce2a`)
- `ballooning_minimum` und `tpm_version` korrekte Feldnamen im HCL (Commit `5db9fd9`)
