# HomeLab Proxmox VM-Templates

Automatisierte VM-Template-Erstellung und Provisionierung für Proxmox VE.

## Workflow

```
Packer baut Template  →  Terraform klont VM  →  Ansible konfiguriert
(einmalig/Updates)        (bei jedem Deploy)      (rollenspezifisch)
```

## Templates

| Template | Status | OS | Cloud-Init |
|---|---|---|---|
| Ubuntu 24.04 LTS | PoC | Linux | cloud-init |
| Debian 12 | Geplant | Linux | cloud-init |
| Windows 11 Pro | Geplant | Windows | Cloudbase-Init |
| Windows Server 2025 | Geplant | Windows | Cloudbase-Init |

## Voraussetzungen

- Proxmox VE 8.x mit API-Token
- Packer >= 1.9.0
- Terraform >= 1.8.0
- Ansible >= 2.16

## Schnellstart (Ubuntu 24.04 PoC)

### 1. Packer Template bauen

```bash
cd packer/linux/ubuntu-2404
cp ubuntu-2404.pkrvars.hcl.example ubuntu-2404.pkrvars.hcl
# Werte anpassen (Proxmox URL, Token, Node, Storage)
packer init .
packer validate -var-file=ubuntu-2404.pkrvars.hcl .
packer build -var-file=ubuntu-2404.pkrvars.hcl .
```

### 2. VM mit Terraform erstellen

```bash
cd terraform/environments/homelab
cp terraform.tfvars.example terraform.tfvars
# Werte anpassen
terraform init
terraform plan
terraform apply
```

### 3. VM mit Ansible konfigurieren

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/base-linux.yml
```

## Verzeichnisstruktur

```
.
├── packer/
│   ├── linux/
│   │   └── ubuntu-2404/          # PoC
│   └── windows/                  # Geplant
├── terraform/
│   ├── modules/
│   │   └── linux-vm/
│   └── environments/
│       └── homelab/
├── ansible/
│   ├── playbooks/
│   ├── roles/
│   └── inventory/
└── scripts/
    └── create-template-manual.sh  # Manuelle Alternative ohne Packer
```

## Referenzen

- [Konzept-Dokument](https://github.com/strausmann/homelab-pangolin-client/issues/176)
- [Pumba98/proxmox-packer-templates](https://github.com/Pumba98/proxmox-packer-templates)
- [bpg/terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox)
