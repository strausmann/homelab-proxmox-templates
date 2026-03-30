# Template-Profile

Jedes Profil definiert Pakete und APT-Sources die in ein VM-Template eingebaut werden.
Profile sind kombinierbar und werden in der Packer/Ansible Konfiguration referenziert.

## Verfuegbare Profile

| Profil | Beschreibung |
|---|---|
| `base.yml` | Grundausstattung fuer ALLE VMs (curl, vim, Python, SSH, UFW, fail2ban) |
| `docker.yml` | Docker CE + Daemon-Konfiguration |
| `tailscale.yml` | Tailscale Mesh-VPN Client |
| `gitlab-runner.yml` | GitLab Runner |
| `monitoring.yml` | PatchMon Agent + Node Exporter |

## Profil-Kombinationen

| Template | Profile |
|---|---|
| Standard Linux VM | `base` + `tailscale` + `monitoring` |
| Docker Node | `base` + `tailscale` + `monitoring` + `docker` |
| GitLab Runner | `base` + `tailscale` + `monitoring` + `docker` + `gitlab-runner` |

## Format

```yaml
packages:
  - paketname1
  - paketname2

apt_sources:
  - name: repo-name
    url: "https://repo.example.com/ubuntu"
    gpg_url: "https://repo.example.com/gpg"
    gpg_dest: "/etc/apt/keyrings/repo.asc"
    suite: "noble"       # Ubuntu Codename
    component: "stable"
    arch: "amd64"
```

## Neues Profil hinzufuegen

1. YAML-Datei unter `profiles/` erstellen
2. Pakete und APT-Sources definieren
3. In `ansible/playbooks/apply-profiles.yml` referenzieren
4. Testen mit `packer build`
