# --- PoC: GitLab Runner Build VM ---
# Erstellt eine Ubuntu 24.04 VM aus dem Packer-Template
# Referenz: https://github.com/strausmann/homelab-pangolin-client/issues/175

module "runner_build" {
  source = "../../modules/linux-vm"

  vm_name        = "runner-build"
  vm_description = "GitLab Runner fuer Multi-Arch Docker Builds"
  vm_tags        = ["terraform", "linux", "gitlab-runner"]

  proxmox_node = "hhpve01"
  template_id  = 9000  # tmpl-ubuntu-2404

  cpu_cores    = 4
  memory       = 8192
  disk_size    = 200
  storage_pool = "local-lvm"

  ip_address   = "dhcp"
  dns_servers  = ["10.1.0.1"]
  search_domain = "home.lab"

  ci_user  = "ubuntu"
  ssh_keys = [var.ssh_public_key]
}

output "runner_build_ip" {
  value = module.runner_build.ipv4_address
}
