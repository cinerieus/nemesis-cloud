<div align="left">

<h3>Arch VM Base Image Builder</h3>
<p><i>Build a reusable Nemesis desktop/cloud image with Packer, GNOME, BlackArch tooling, cloud-init, and shim Secure Boot support.</i></p>

[![Packer](https://img.shields.io/badge/packer-qemu-1a1a2e?style=flat-square)](https://developer.hashicorp.com/packer)
[![Platform](https://img.shields.io/badge/platform-arch%20%7C%20qemu%2Fkvm-1793d1?style=flat-square)]()
[![Cloud Init](https://img.shields.io/badge/cloud--init-ready-8b5cf6?style=flat-square)](https://cloud-init.io/)

<p>
  <a href="#overview">Overview</a> •
  <a href="#features">Features</a> •
  <a href="#build">Build</a> •
  <a href="#runtime-customization">Runtime Customization</a> •
  <a href="#existing-vms">Existing VMs</a> •
  <a href="#layout">Layout</a>
</p>

</div>

---

## Overview

Nemesis Cloud builds a reusable Arch-based VM image from the official Arch cloud
qcow2. The build installs the desktop, tooling, themes, CLI configuration, VM
integration, cloud-init, and a shim/GRUB Secure Boot path.

The primary artifacts are:

```text
packer/output/nemesis-cloud/nemesis-cloud.qcow2
packer/output/nemesis-cloud/nemesis-cloud.raw
```

Use the qcow2 locally with QEMU/libvirt/Cockpit. Use the raw image for providers
that only accept raw disk uploads.

## Features

| Feature | Description |
|---------|-------------|
| **Arch Cloud Base** | Starts from the official Arch cloud image |
| **Packer Build** | Produces repeatable qcow2 output and converts it to raw |
| **Cloud-Init Ready** | Cleans machine identity and cloud-init state for reuse |
| **GNOME Desktop** | Installs and themes GNOME, but leaves graphical login disabled by default |
| **Remote Desktop** | Configures GNOME RDP credentials as `rdp / rdp` |
| **CLI Setup** | Applies fish, tmux, Neovim, Kitty, Wofi, font, and shell config |
| **BlackArch/AUR** | Enables BlackArch and installs selected AUR packages |
| **Secure Boot Path** | Uses Microsoft-signed shim, GRUB, and local MOK signing |
| **Encrypted Workspace** | Includes `nemesis-workspace` for file-backed LUKS storage under `/opt/workspace` |
| **VM Integration** | Installs VM tools and keeps the image ready for KVM/Cockpit/cloud providers |

## Build

Install host dependencies:

```bash
sudo pacman -Sy --needed packer qemu-base xorriso
```

Build the image:

```bash
./build-image.sh
```

Override Packer variables when needed:

```bash
./build-image.sh -var 'memory=12288' -var 'cpus=6'
./build-image.sh -var 'disk_size=80G'
```

The build flow is:

```text
Arch cloud qcow2
  -> Packer QEMU VM
  -> init.sh installs repo files
  -> nemesis-firstboot provisions the system
  -> Packer cleans identity/cloud-init/build state
  -> qcow2 output
  -> raw conversion
```

## Outputs

```text
packer/output/nemesis-cloud/
├── nemesis-cloud.qcow2
└── nemesis-cloud.raw
```

`build-image.sh` prints `qemu-img info` for both images after conversion.

## Runtime Customization

The built image keeps cloud-init installed and cleaned. VM platforms can provide
instance-specific values at creation time, such as:

| Value | Source |
|-------|--------|
| Hostname | cloud-init metadata/user-data |
| User password | cloud-init user-data or provider UI |
| Root password | cloud-init user-data or provider UI |
| SSH keys | cloud-init user-data or provider UI |
| Desktop service state | cloud-init `runcmd` |

The baked local console account is:

```text
user / Ch4ngeM3!
```

The baked GNOME RDP account is:

```text
rdp / rdp
```

SSH password login is intentionally disabled. Use SSH keys.

Example runtime user-data:

```text
examples/user-data.yaml
```

Enable graphical login and GNOME Remote Desktop on a new VM:

```yaml
#cloud-config
runcmd:
  - [bash, -lc, "systemctl enable --now gdm.service gnome-remote-desktop.service"]
```

## Existing VMs

For an already-created VM, clone this repo and run:

```bash
./init.sh
```

Common options:

```bash
./init.sh --user USER --hostname PC
./init.sh --enable-desktop-login
./init.sh --password 'new-password'
./init.sh --luks-note
./init.sh --ssh-key "ssh-ed25519 ..."
./init.sh --force-config
```

`init.sh` installs this repo into `/usr/local/share/nemesis-cloud`, writes
`/etc/nemesis-cloud.conf`, and runs provisioning with logs at:

```text
/var/log/nemesis-firstboot.log
```

## Build Config

`/etc/nemesis-cloud.conf` controls provisioning:

```bash
NEMESIS_USER="user"
NEMESIS_HOSTNAME=""        # Empty generates DESKTOP-XXXXXXX.
NEMESIS_USER_PASSWORD="Ch4ngeM3!"
ENABLE_GRAPHICAL_LOGIN="false"
ENABLE_LUKS_NOTE="false"
NEMESIS_REPO_URL=""
NEMESIS_REPO_REF="main"
SSH_AUTHORIZED_KEY=""
RDP_USER="rdp"
RDP_PASSWORD="rdp"
```

GNOME, theming, RDP configuration, VM tools, BlackArch, AUR/yay, CLI config, and
shim-signed GRUB are configured during image provisioning. `gdm.service` and
`gnome-remote-desktop.service` stay disabled unless
`ENABLE_GRAPHICAL_LOGIN="true"`.

## Secure Boot

The image uses Microsoft-signed shim, GRUB, and a local Machine Owner Key.

On first boot with Secure Boot enabled, MokManager should appear. Enroll
`MOK.cer` from the EFI system partition. After a successful boot, remove:

```text
MOK.cer
EFI/BOOT/mmx64.efi
```

A pacman hook re-signs GRUB and the kernel after updates.

## Encrypted Workspace

Root LUKS encryption should be done during image build or installation, before
the first boot into cloud-init.

For a simple encrypted workspace inside the image:

```bash
sudo nemesis-workspace init --size 50G
sudo nemesis-workspace open
sudo nemesis-workspace close
```

This encrypts `/opt/workspace` without changing the root filesystem.

## Config Assets

The repo contains the project scripts, system config, dotfiles, GNOME theme,
GRUB theme, wallpaper, and Wofi CSS needed for the image configuration.

The build still fetches external OS/package sources:

| Source | Purpose |
|--------|---------|
| Arch mirrors | Base packages and updates |
| BlackArch | BlackArch repository and packages |
| AUR | `yay-bin`, `shim-signed`, GNOME extensions, themes |
| GitHub/raw URLs | Editor, tmux, fish plugin/theme installs |

## Layout

```text
.
├── .github/workflows/        # Manual GitHub Actions image build
├── archive/cloud-config/     # Older generated cloud-config flow
├── assets/                   # Vendored visual assets
├── docs/                     # Supporting documentation
├── examples/                 # Runtime cloud-init examples
├── files/                    # System/user config copied into the image
├── packer/                   # Packer QEMU template
├── scripts/                  # Provisioning and helper scripts
├── build-image.sh            # Packer wrapper + raw converter
└── init.sh                   # Local/existing-VM installer
```

## Validation

Useful checks while editing:

```bash
bash -n build-image.sh init.sh scripts/nemesis-firstboot scripts/nemesis-gnome-firstlogin scripts/nemesis-workspace
packer validate -var output_directory=/tmp/nemesis-cloud-validate-output packer/nemesis-cloud.pkr.hcl
cloud-init schema -c examples/user-data.yaml
```
