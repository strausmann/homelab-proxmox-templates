# Changelog — Template: Ubuntu 26.04 LTS Docker-Node

Alle nennenswerten Aenderungen an diesem Template. Format nach
[Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

Aenderungen am gemeinsamen Hardening-Playbook sind in `packer/linux/ubuntu-2404/CHANGELOG.md`
dokumentiert und werden hier nicht wiederholt.

---

## [Unreleased]

---

## [2026-04] — 2026-04-13

### Changed

- Partitionierung: LVM durch Direct-Layout ersetzt (Commit `2c17618`)
- Cleanup: packer-User-Loeschung im Cleanup-Provisioner (Commit `2c17618`)

---

## [2026-04-a] — 2026-04-02

### Added

- Ubuntu 26.04 LTS Docker-Node Template — erste Version (Commit `5ea653a`)
- Zweite Disk 300G fuer `/docker` (XFS via Ansible) (Commit `5ea653a`)
- Docker CE Installation via `packer-hardening-docker.yml` (Commit `5ea653a`)
- CI-Jobs: `validate_ubuntu_2604_docker`, `build_ubuntu_2604_docker`,
  `rotate_latest_ubuntu_2604_docker` mit VM-ID-Bereich 9700–9799 (Commit `5ea653a`)
- Docker APT Suite Fallback: `resolute` → `noble` (Commit `5ea653a`)
- `boot_wait = "15s"` fuer zwei-Disk-Template (Commit `1a9d76e`)

### Fixed

- meta-data: korrektes leeres JSON-Objekt `{}` (Commit `76ba8aa`)
- CI: Review-Fixes nach PR #2 (Commit `47edb27`)
