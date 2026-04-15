# Changelog — Template: Ubuntu 24.04 LTS LUKS

Alle nennenswerten Aenderungen an diesem Template. Format nach
[Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

Dieses Template hat die intensivste Entwicklungsphase aller Templates durchlaufen —
14 Fix-Commits alleine am 2026-04-14 zur Loesung von 6 definierten Defekten
(Issues #213 und #214).

---

## [Unreleased]

---

## [2026-04-c] — 2026-04-15

### Fixed

- `packer-hardening.yml`: Netplan-Interface-Suche via `find`-Modul statt `fileglob`
  — behebt Pipeline-Fehler 25732 (Commit `7aa5e3d`)
- user-data: Keyfile-Block reaktiviert nach versehentlichem Entfernen in Refactor-Commit
  (Commit `2c8588c`)

---

## [2026-04-b] — 2026-04-14

### Added

- CI: Validate, Build und Rotate-Jobs fuer LUKS-Template (Commit `5fa6bfb`)
- Tang-Variable `tang_url` in HCL (Pflichtfeld) — URL wird in Template-Beschreibung eingetragen
  (Commit `70f0629`)
- LUKS2-Verschluesselung auf `/dev/sda3` via Subiquity `dm_crypt` (Commit `70f0629`)
- Keyfile-Provisioning (Issue #214 Defekt #1): Keyfile als File in
  `/etc/cryptsetup-keys.d/luks-keyfile.key`, KEYFILE_PATTERN fuer initramfs-Embedding
  (Commit `63cd499`)
- Template-Status-Provisioner: zeigt Keyslot-Belegung nach Build
  (Commit `8231317`)
- LUKS-Verifikation im Packer-Build: `cryptsetup isLuks /dev/sda3` (Commit `284f3..`)

### Changed

- Tang-Binding aus Template entfernt (Pfad B) — Tang-Binding jetzt post-deployment via
  Ansible-Role `clevis-tang-bind` (Commit `70f0629`)
- user-data: Zurueck auf Minimum-Konfiguration (Commit `3efaf79`)
- Partitionierung: LVM durch explizites Storage-Layout ersetzt (Defekt #2)
  (Commit `fe8aa6e`)
- GRUB-Cmdline bereinigen: `autoinstall` und `ds=nocloud-net` nach Installation entfernen
  (Defekte #5 + #6) (Commit `c2b1988`)
- packer-User-Cleanup via Cloud-Init runcmd → verschoben zu Ansible-Role post-deployment
  (Race Condition Fix, Defekt #3) (Commit `1901f6b`)
- SSH-Hardening Drop-In (`99-homelab-sshd.conf`) via `curtin in-target` statt Ansible
  — verhindert Passwort-Auth-Deaktivierung im Live-Installer (Commit `0ca5217`)
- `ansible_remote_tmp=/tmp/.ansible-packer` explizit gesetzt — behebt Gathering-Facts-Fehler
  wenn Runner Home-Pfad nicht auf Target-VM existiert (Commit `66fe2ff`)
- timeout-Wraps um cloud-init/apt-Waits (max 60s/120s) — verhindert Deadlock mit
  unattended-upgrades (Commit `66d8806`)

### Fixed

- `lock_passwd: false` zurueck — Packer benoetigt Passwort-Login waehrend Build (Commit `20747d9`)
- echo-Strings in late-commands gequotet — dash-Syntax-Error bei `(` (Commit `8c7d1a0`)
- `luksAddKey --new-keyfile-size` statt `--keyfile-size` — korrekter Parameter (Commit `d307962`)
- Stabile Disk-Pfade via `by-uuid` statt `/dev/sdb` — Pfad aendert sich je nach Reihenfolge
  (Commit `974903e`)
- heredoc durch einzelne echo-Befehle ersetzt — dash-Kompatibilitaet (Commit `db2fa7b`)
- net.ifnames=0 in GRUB — konsistentes Interface-Naming in initramfs (Clevis/DHCP-Fix)
  (Commit `707874c`)

---

## [2026-04-a] — 2026-04-13

### Changed

- LVM durch Direct-Layout ersetzt (Base-Template) — wirkt sich auch auf LUKS-userdata aus
  (Commit `2c17618`)

---

## [2026-04-d] — 2026-04-02

### Fixed

- CI: Review-Fixes nach PR #2 (Commit `47edb27`)
- meta-data: korrektes leeres JSON-Objekt `{}` (Commit `76ba8aa`)

---

## Bekannte Defekte (alle geloest)

| Defekt | Beschreibung | Fix |
|---|---|---|
| #1 | Kein autonomer Build ohne manuellen LUKS-Prompt | KEYFILE_PATTERN via cryptsetup-initramfs |
| #2 | LVM verursachte Probleme beim Klonen | Direct-Layout ohne LVM |
| #3 | packer-User-Race-Condition mit Cloud-Init | Cleanup via Ansible post-deployment |
| #4 | PasswordAuthentication im Live-Installer deaktiviert | Drop-In via curtin in-target |
| #5 | `autoinstall` in GRUB-Cmdline nach Install | curtin in-target sed auf /etc/default/grub |
| #6 | `ds=nocloud-net` in GRUB-Cmdline nach Install | curtin in-target sed auf /etc/default/grub |
