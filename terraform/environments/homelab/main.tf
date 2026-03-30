# --- HomeLab VM Deployments ---
# Erstellt VMs aus Packer-Templates via Cloud-Init
#
# SSH Keys: Node Key + Persoenlicher Key
# Referenzen:
#   - Issue #175: https://github.com/strausmann/homelab-pangolin-client/issues/175
#   - Issue #176: https://github.com/strausmann/homelab-pangolin-client/issues/176

locals {
  ssh_public_keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK6gqu8YPR+KppBxvK+rsQHKeWq5jY/zC5HJO3sPmx1K ansible-vm-homelab-nodes",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIARsgv7N7lCpWsn2jy8w8Se2sqKulcaAM8ACIda4B7gm strausmann",
  ]
}

# --- GitLab Runner: Build (Multi-Arch Docker Builds) ---
module "runner_build" {
  source = "../../modules/linux-vm"

  vm_name        = "runner-build"
  vm_description = "GitLab Runner fuer Multi-Arch Docker Builds"
  vm_tags        = ["terraform", "linux", "gitlab-runner", "docker"]

  proxmox_node = "hhpve01"
  template_id  = 9000  # tmpl-ubuntu-2404

  cpu_cores    = 4
  memory       = 8192
  disk_size    = 200
  storage_pool = "local-lvm"

  ip_address    = "dhcp"
  dns_servers   = ["10.1.0.1"]
  search_domain = "home.lab"

  ci_user  = "ubuntu"
  ssh_keys = local.ssh_public_keys
}

# --- GitLab Runner: CI (ionCube, MegaLinter) ---
module "runner_ci" {
  source = "../../modules/linux-vm"

  vm_name        = "runner-ci"
  vm_description = "GitLab Runner fuer CI Jobs (ionCube, MegaLinter)"
  vm_tags        = ["terraform", "linux", "gitlab-runner", "docker"]

  proxmox_node = "hhpve01"
  template_id  = 9000

  cpu_cores    = 4
  memory       = 4096
  disk_size    = 50
  storage_pool = "local-lvm"

  ip_address    = "dhcp"
  dns_servers   = ["10.1.0.1"]
  search_domain = "home.lab"

  ci_user  = "ubuntu"
  ssh_keys = local.ssh_public_keys
}

output "runner_build_ip" {
  value = module.runner_build.ipv4_address
}

output "runner_ci_ip" {
  value = module.runner_ci.ipv4_address
}
