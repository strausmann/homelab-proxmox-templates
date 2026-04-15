# Changelog — Template: Ubuntu 24.04 LTS Docker-Node

Alle nennenswerten Aenderungen an diesem Template. Format nach
[Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

Aenderungen am gemeinsamen Hardening-Playbook (`ansible/playbooks/packer-hardening.yml`)
sind in `packer/linux/ubuntu-2404/CHANGELOG.md` dokumentiert und werden hier nicht wiederholt.
Aenderungen an `packer-hardening-docker.yml` sind hier aufgefuehrt.

---

## [Unreleased]

---

## [2026-04] — 2026-04-13

### Changed

- Partitionierung: LVM durch Direct-Layout ersetzt (`storage.layout.name: direct`) —
  einfacheres Klonen, kein LVM-Resize nach Clone noetig (Commit `2c17618`)
- Cleanup: packer-User-Loeschung in Packer-Cleanup-Provisioner — verhindert Race Condition
  mit Cloud-Init runcmd (Commit `2c17618`)

---

## [2026-04-a] — 2026-04-02

### Fixed

- `boot_wait` auf 15s erhoehen — Docker-Template hat zwei Disks, UEFI-Init dauert laenger
  (Commit `1a9d76e`)
- CI: Review-Fixes nach PR #2 (Commit `47edb27`)

---

## [2026-03] — 2026-03-31

### Added

- Ubuntu 24.04 Docker-Node Template — erste Version (Commit `54f40cb`)
- Zweite Disk 300G fuer `/docker` (XFS-formatiert via Ansible) (Commit `54f40cb`)
- Docker CE mit `packer-hardening-docker.yml`: docker-ce, docker-ce-cli, containerd.io,
  docker-buildx-plugin, docker-compose-plugin (Commit `54f40cb`)
- Docker Daemon-Konfiguration: `data-root: /docker`, `overlay2`, `live-restore: true`,
  BuildKit, Log-Rotation (10m/3), Prometheus-Metriken auf Port 9323 (Commit `54f40cb`)
- Docker-Adresspool `172.20.0.0/14` (/24) — kein Konflikt mit HomeLab-VLANs (Commit `54f40cb`)
- CI-Job `build_ubuntu_2404_docker` mit Resource-Group `packer_build_ubuntu-docker_2404`
  und VM-ID-Bereich 9100–9199 (Commit `8719a44`)

### Fixed

- apt-Lock-Warte-Loop eingefuehrt (Commit `2000a66`)
- qemu-guest-agent zurueck in user-data packages (Commit `8436757`)
- Build-Specs: 6 CPU / 8 GB RAM waehrend Build, Defaults danach (Commit `6137d2c`)
- Building-Tag-Watchdog und Docker-Node Template Cleanup (Commit `c5cd000`)

### Changed

- DHCP statt statische IP in user-data (VLAN 60 DHCP funktioniert waehrend Autoinstall)
  (Commit `cdf5f59`)
