# Build-Methoden für VM-Templates

Dieses Repo baut Proxmox-VM-Templates auf **zwei grundsätzlich verschiedenen
Wegen**. Beide erzeugen am Ende ein fertiges, klonbares Proxmox-Template —
aber mit unterschiedlichen Voraussetzungen, Stärken und Einsatzgebieten.
Dieses Dokument ist die Entscheidungsgrundlage dafür, welcher Weg für ein
neues Standard-Image gewählt werden sollte.

## Die zwei Wege im Überblick

| | Packer-Autoinstall (ISO) | Cloud-Image (`genericcloud` + cloud-init) |
|---|---|---|
| **Quelle** | Installer-ISO (z. B. `ubuntu-24.04.4-live-server-amd64.iso`) | Fertiges, von der Distribution gepflegtes Cloud-Image (`.img`/`.qcow2`) |
| **Werkzeug** | Packer (`packer/linux/*`, `packer/windows/*`) | Reines `qm` auf dem Proxmox-Node (`scripts/build-ax41-cloud-template.sh`) |
| **Netzwerk während des Builds** | HTTP-Autoinstall-Callback + SSH zur transienten Build-VM — braucht ein **gemeinsames LAN/Tailnet zur Build-VM selbst** | Keins nötig — Härtung läuft ausschließlich über den **QEMU-Guest-Agent** (virtio-serial), auch ohne Gast-Netzwerk |
| **Build-Dauer** | ~15–25 Minuten (volle OS-Installation) | ~3–8 Minuten (Image-Import + Guest-Agent-Härtung) |
| **Custom-Partitionierung/RAID/LUKS** | Ja, voll steuerbar (Autoinstall `late-commands`, siehe `ubuntu-2404-luks`) | Nein — Partitionslayout kommt fix aus dem Cloud-Image |
| **Vendor-Vertrauen** | Kein Vertrauen ins Image nötig — alles wird aus einer verifizierten ISO frisch installiert | Vertrauen in das von der Distribution signierte/gehashte Cloud-Image nötig |
| **Referenz-Implementierung** | `packer/linux/ubuntu-2404/`, `.gitlab-ci.yml` Jobs `validate_ubuntu_2404`/`build_ubuntu_2404` | `scripts/build-ax41-cloud-template.sh`, `.gitlab-ci.yml` Job `build_ax41_ubuntu_2404_cloud` |

## Warum der Unterschied überhaupt existiert (technischer Hintergrund)

Der QEMU-Guest-Agent und cloud-init existieren immer erst **nach** einer
fertigen OS-Installation — sie sind Teil des installierten Systems, nicht
Teil des Installers.

- **Packer-Autoinstall installiert von Null** über eine ISO. Während dieser
  Installation läuft auf der transienten Build-VM noch **kein** Agent und
  **kein** cloud-init — Packer muss deshalb über einen **HTTP-Callback**
  (Autoinstall meldet sich beim Packer-HTTP-Server zurück) UND anschließend
  über **SSH direkt zur Build-VM** kommunizieren, um den Ansible-Provisioner
  laufen zu lassen. Beides setzt voraus, dass die transiente Build-VM
  während der Installation im selben LAN/Tailnet wie der Build-Host
  erreichbar ist.
- **Cloud-Images bringen OS + Agent + cloud-init bereits fertig mit.** Der
  Build besteht nur noch aus Disk-Import + Konfiguration — kein
  Autoinstall-Callback, kein SSH-Tanz während der Installation. Die
  Härtung/Konfiguration läuft stattdessen über den **QEMU-Guest-Agent**
  (`qm guest exec`), der über den virtio-serial-Kanal des Hypervisors läuft
  und **unabhängig vom Gast-Netzwerk** funktioniert.

Das ist der exakte Grund, warum der AX41-Node (`defks-proxmox-01`) zwingend
den Cloud-Image-Weg braucht: Das Einzel-IP+vMAC-Netzwerkmodell dort (siehe
`infra/ansible/inventory/host_vars/defks-proxmox-01.yml` im
homelab-management-Repo) stellt der transienten Packer-Build-VM während der
Installation **keine** erreichbare Adresse zur Verfügung — der
Autoinstall-Callback und die SSH-Verbindung liefen ins Leere. Der
QEMU-Guest-Agent braucht dagegen gar keine Netzwerkadresse.

## Entscheidungs-Guidance: Welcher Weg für ein neues Standard-Image?

```
Neues Standard-Image gewünscht
    |
    v
Braucht es LUKS-Full-Disk-Encryption, custom Partitionierung/RAID,
oder muss Hardening/Software bereits ZUR BUILD-ZEIT ins Image gebacken
werden (kein Vertrauen in ein Vendor-Cloud-Image gewünscht)?
    |
    +-- Ja  -> Packer-Autoinstall (ISO)
    |          Beispiel: packer/linux/ubuntu-2404-luks/
    |
    +-- Nein
        |
        v
    Läuft der Ziel-Node OHNE gemeinsames LAN/Tailnet zur transienten
    Build-VM (z. B. Hetzner-Einzel-IP+vMAC-Modell wie AX41)?
        |
        +-- Ja  -> Cloud-Image ZWINGEND (Packer-Autoinstall-Callback
        |          funktioniert dort technisch nicht)
        |          Beispiel: scripts/build-ax41-cloud-template.sh
        |
        +-- Nein -> Cloud-Image als DEFAULT
                    (weniger Zeremonie, schnellerer Build, läuft übers
                    Tailnet). Nur bei den oben genannten Sonderfällen auf
                    Packer-Autoinstall wechseln.
```

**Kurzfassung:**

- **Standard-VMs → Cloud-Image (Default).** Schneller, weniger bewegliche
  Teile, läuft übers Tailnet ohne Sonderweg.
- **Packer-Autoinstall → Sonderfälle:** LUKS-Full-Disk-Encryption, custom
  Partitionierung/RAID, Hardening das bereits zur Build-Zeit gebacken sein
  muss, oder wenn dem Vendor-Cloud-Image bewusst nicht vertraut werden soll.
- **Remote-/Tailnet-Nodes ohne LAN-Callback-Weg zur Build-VM (z. B. AX41):**
  zwingend Cloud-Image — der Packer-Autoinstall-Callback ist dort technisch
  nicht möglich.

## Referenz-Implementierungen

| Weg | Node | Dateien |
|---|---|---|
| Packer-Autoinstall | PVE1 (Cluster, LAN) | `packer/linux/ubuntu-2404/`, `packer/linux/ubuntu-2404-docker/`, `packer/linux/ubuntu-2404-luks/`, `packer/linux/ubuntu-2604*`, `packer/windows/windows-11/`; CI-Jobs `validate_*`/`build_*`/`rotate_latest_*` in `.gitlab-ci.yml` |
| Cloud-Image | AX41 (`defks-proxmox-01`, Hetzner Tailnet-Node) | `scripts/build-ax41-cloud-template.sh`; CI-Job `build_ax41_ubuntu_2404_cloud` (Basis `.ax41_cloud_template_base`) in `.gitlab-ci.yml` |

Der Cloud-Image-Weg ist bewusst **parametrisiert** (VMID, Name, Bridge,
Storage, CPU/RAM/Disk als Positionsargumente) — für ein weiteres
Cloud-Image-Template (anderes OS oder ein weiterer Tailnet-Node) reicht ein
neuer, kleiner CI-Job, der `.ax41_cloud_template_base` erweitert bzw. das
Skript mit anderen Parametern/anderer Image-URL aufruft, statt eine
komplette neue Packer-Pipeline aufzusetzen.
