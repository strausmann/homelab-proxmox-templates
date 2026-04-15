# Changelog — Template: Ubuntu 26.04 LTS (Base)

Alle nennenswerten Aenderungen an diesem Template. Format nach
[Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

Dieses Template wurde mit Ubuntu 24.04 parallel eingefuehrt und hat dieselbe Hardening-Basis.
Aenderungen am gemeinsamen Playbook `ansible/playbooks/packer-hardening.yml` sind in
`packer/linux/ubuntu-2404/CHANGELOG.md` vollstaendig dokumentiert und gelten hier analog.

---

## [Unreleased]

---

## [2026-04] — 2026-04-13

### Changed

- Partitionierung: LVM durch Direct-Layout ersetzt (`storage.layout.name: direct`) —
  einfacheres Klonen (Commit `2c17618`)
- Cleanup: packer-User-Loeschung im Cleanup-Provisioner (Commit `2c17618`)

---

## [2026-04-a] — 2026-04-02

### Added

- Ubuntu 26.04 LTS (Resolute Raccoon) Base-Template — erste Version (Commit `5ea653a`)
- Separate CI-Jobs: `validate_ubuntu_2604`, `build_ubuntu_2604`, `rotate_latest_ubuntu_2604`
  (Commit `5ea653a`)
- VM-ID-Bereich 9600–9699 (Commit `5ea653a`)
- Tailscale APT Fallback: `resolute` → `noble`-Repo (Commit `5ea653a`)

### Fixed

- meta-data: korrektes leeres JSON-Objekt `{}` statt leerem String (Commit `76ba8aa`)
- CI: Review-Fixes nach PR #2 (Commit `47edb27`)

### Security

- SSH Hardening, MaxAuthTries 30, PasswordAuthentication no — geerbt von Base-Playbook
  (Commits `b2a8891`, `f872a5a`, `0ca5217`)
