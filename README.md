# Nemesis Cloud

Nemesis Cloud builds a reusable Arch Linux VM image with GNOME, BlackArch tools,
CLI configuration, cloud-init support, VM tools, and a shim/GRUB Secure Boot
boot path.

The normal workflow is:

```text
build image locally -> import qcow2/raw into a VM platform -> boot VM -> enroll MOK if Secure Boot is enabled -> log in
```

## Start Here

1. Install the build dependencies on the machine that will create the image:

```bash
sudo pacman -Sy --needed packer qemu-base xorriso
```

2. Create a local build config:

```bash
cp nemesis-cloud.conf.example nemesis-cloud.conf
```

3. Edit `nemesis-cloud.conf`.

The defaults are usable, so you can skip this edit if you just want the standard
image:

```bash
NEMESIS_USER="user"
NEMESIS_USER_PASSWORD="Ch4ngeM3!"
NEMESIS_HOSTNAME=""
ENABLE_GRAPHICAL_LOGIN="false"
SSH_AUTHORIZED_KEY=""
RDP_USER="rdp"
RDP_PASSWORD="rdp"
```

4. Build the image:

```bash
./build-image.sh
```

The build takes a while. It downloads the current Arch cloud image, starts it
with Packer/QEMU, provisions the system, cleans it for reuse, and converts the
final qcow2 to raw.

When it finishes, use one of these files:

```text
packer/output/nemesis-cloud/nemesis-cloud.qcow2
packer/output/nemesis-cloud/nemesis-cloud.raw
```

Use `nemesis-cloud.qcow2` for local QEMU/libvirt/Cockpit. Use
`nemesis-cloud.raw` for providers that require raw disk uploads.

## What This Builds

| Area | What is included |
|------|------------------|
| Base OS | Official Arch cloud image, updated during build |
| Desktop | Optional GNOME, Firefox, LibreOffice, Ghostty, Wofi, Thunar |
| Security tooling | BlackArch repo, selected BlackArch/AUR tools |
| CLI setup | fish, tmux, Neovim, Catppuccin-style config |
| Remote access | SSH enabled, optional GNOME Remote Desktop |
| VM support | VM tools, cloud-init, NetworkManager, systemd-resolved |
| Secure Boot | Microsoft-signed shim, GRUB, local MOK signing |
| Storage | Optional file-backed LUKS workspace helper |
| Output formats | qcow2 and raw; optional Docker image on GHCR |

The repo contains the project scripts, configs, dotfiles, wallpaper, GNOME theme,
GRUB theme, and Wofi CSS. Package installs still use the Arch, BlackArch, AUR,
and GitHub upstreams during the build.

## WSL Setup

For a fresh Arch WSL install that only has `root`, use the WSL profile instead
of building a VM image.

Inside WSL:

```bash
pacman -Sy --needed git
git clone https://github.com/cinerieus/nemesis-cloud.git
cd nemesis-cloud
cp nemesis-cloud.conf.example nemesis-cloud.conf
vim nemesis-cloud.conf
./scripts/install --wsl
```

At minimum, set:

```bash
NEMESIS_USER="youruser"
NEMESIS_USER_PASSWORD="change-this"
INSTALL_PROFILE="wsl"
```

The WSL profile:

- creates and configures `NEMESIS_USER`
- sets that user as the default WSL user in `/etc/wsl.conf`
- enables WSL systemd
- configures systemd-resolved and `/etc/resolv.conf`
- sets up `/opt/workspace` permissions and default ACLs
- locks the root password after the user/sudo path exists
- installs BlackArch, `yay`, CLI/security tooling, and shell/editor/tmux config
- skips GNOME, RDP, cloud-init, bootloader/Secure Boot, VM tools, NetworkManager, and SSH server enablement

After it finishes, restart WSL from Windows:

```powershell
wsl --shutdown
```

Then reopen the distro. It should start as `NEMESIS_USER`.

## Container Image

The container profile is the minimal (non-desktop) toolset in an Arch
container. It is not a wrap of the Packer qcow2.

Local build:

```bash
docker build -t nemesis .
docker run -it --rm nemesis
```

Published image (GitHub Actions, weekly plus manual dispatch):

```bash
docker pull ghcr.io/cinerieus/nemesis
docker run -it --rm ghcr.io/cinerieus/nemesis
```

Default login inside the image is `user / Ch4ngeM3!` (sudo). Root's password is
locked.

The container profile:

- creates and configures `NEMESIS_USER`
- installs BlackArch, `yay`, CLI/security tooling, and shell/editor/tmux config
- sets up `/opt/workspace` permissions and default ACLs
- skips GNOME, RDP, cloud-init, bootloader/Secure Boot, VM tools, NetworkManager,
  SSH server enablement, `hostnamectl`/`timedatectl`, and WSL integration

Build from this repo with:

```bash
./scripts/install --container
```

or set `INSTALL_PROFILE="container"` in `nemesis-cloud.conf`.

## Default Credentials

Local console user:

```text
user / Ch4ngeM3!
```

GNOME Remote Desktop bootstrap credentials:

```text
rdp / rdp
```

The desktop image boots directly to GDM. GNOME Remote Desktop is installed and
configured but deliberately disabled so the known bootstrap credentials are not
exposed automatically. Enable RDP when required:

```bash
sudo systemctl enable --now gnome-remote-desktop.service
```

Connect to TCP port `3389` with `rdp / rdp`, then use the normal local account
at the GNOME login screen. Change the RDP credentials before exposing the
service to an untrusted network.

SSH password login is intentionally disabled. Use SSH keys for SSH.

Cloud-init or a provider UI can replace the console user password, root
password, hostname, and SSH keys when the VM is created.

## Configure Before Build

The file you normally edit before building is:

```text
nemesis-cloud.conf
```

Create it from the example:

```bash
cp nemesis-cloud.conf.example nemesis-cloud.conf
```

`nemesis-cloud.conf` is ignored by git so local passwords and keys do not get
committed accidentally.

Common settings:

| Setting | What it controls |
|---------|------------------|
| `NEMESIS_USER` | Local console/sudo user baked into the image |
| `NEMESIS_USER_PASSWORD` | Initial password for that local user |
| `NEMESIS_HOSTNAME` | Baked hostname; empty generates `DESKTOP-XXXXXXX` |
| `INSTALL_PROFILE` | `image` for VM/cloud builds, `wsl` for WSL, `container` for Docker |
| `ENABLE_GRAPHICAL_LOGIN` | Builds the desktop/RDP variant when `true`; minimal when `false` |
| `SSH_AUTHORIZED_KEY` | SSH key baked into the local user account |
| `RDP_USER` / `RDP_PASSWORD` | Initial GNOME Remote Desktop credentials |

Example:

```bash
NEMESIS_USER="cinereus"
NEMESIS_USER_PASSWORD="change-this"
NEMESIS_HOSTNAME="DESKTOP-NEMESIS"
ENABLE_GRAPHICAL_LOGIN="true"
INSTALL_PROFILE="image"
SSH_AUTHORIZED_KEY="ssh-ed25519 AAAA..."
RDP_USER="rdp"
RDP_PASSWORD="rdp"
```

Then build:

```bash
./build-image.sh
```

Command-line options to `scripts/install` are mainly for customizing an already-running
VM. For normal image builds, use `nemesis-cloud.conf`.

## Importing The Image

### Cockpit/libvirt

Use the qcow2:

```text
packer/output/nemesis-cloud/nemesis-cloud.qcow2
```

Create a VM from an existing disk image. Choose UEFI if available. Some Cockpit
and libvirt installations enable Secure Boot automatically when UEFI is chosen.
That is expected for this image.

If Cockpit's Automation tab is used, it passes values through cloud-init. With
Secure Boot enabled, the first boot may stop at MokManager before Linux reaches
cloud-init. If that happens, Cockpit's temporary cloud-init seed can be missed.
The baked credentials above still let you log in from the console.

### VPS/cloud providers

Use the raw image if the provider does not accept qcow2:

```text
packer/output/nemesis-cloud/nemesis-cloud.raw
```

Compress it before uploading if the provider accepts compressed raw images:

```bash
zstd -T0 -10 packer/output/nemesis-cloud/nemesis-cloud.raw
```

Decompress later with:

```bash
zstd -d nemesis-cloud.raw.zst
```

## First Boot With Secure Boot

This image uses Microsoft-signed shim and a local Machine Owner Key.

On the first boot with Secure Boot enabled, MokManager should appear. Enroll
`MOK.cer` from the EFI system partition.

After enrollment and a successful boot, remove these from the EFI system
partition:

```text
MOK.cer
EFI/BOOT/mmx64.efi
```

A pacman hook re-signs GRUB and the kernel after updates.

## Desktop Variant

Set this before building if you want GNOME, theming, GNOME Remote Desktop, and
graphical login:

```bash
ENABLE_GRAPHICAL_LOGIN="true"
```

The default is the minimal variant:

```bash
ENABLE_GRAPHICAL_LOGIN="false"
```

The desktop variant uses `graphical.target` and starts GDM automatically on
boot. RDP remains disabled by default and can be enabled with:

```bash
sudo systemctl enable --now gnome-remote-desktop.service
```

## Encrypted Workspace

This image includes `nemesis-workspace`, a helper for creating a file-backed
LUKS workspace at `/opt/workspace`.

```bash
sudo nemesis-workspace init --size 50G
sudo nemesis-workspace open
sudo nemesis-workspace resize --size 100G
sudo nemesis-workspace close
sudo nemesis-workspace status
```

The `init` command asks for a passphrase. Keep that passphrase safe; it is not
stored by the image. The resize command grows the sparse LUKS container; it does
not support shrinking. A copy of these commands is written to:

```text
/root/NEMESIS-WORKSPACE-NOTE.txt
```

## Building With Different Resources

Pass Packer variables through `build-image.sh`:

```bash
./build-image.sh -var 'memory=12288' -var 'cpus=6'
./build-image.sh -var 'disk_size=80G'
```

The default virtual disk size is set in:

```text
packer/nemesis-cloud.pkr.hcl
```

## Updating The Image Later

Rebuild from the current Arch cloud image:

```bash
./build-image.sh
```

The script overwrites the Packer output directory and regenerates both image
formats.

## Customizing An Existing VM

If you already have an Arch VM and want to apply this setup manually, clone this
repo inside that VM and run:

```bash
./scripts/install
```

Common options:

```bash
./scripts/install --user USER --hostname PC
./scripts/install --enable-desktop-login
./scripts/install --password 'new-password'
./scripts/install --ssh-key "ssh-ed25519 ..."
./scripts/install --force-config
```

`scripts/install` installs the repo into:

```text
/usr/local/share/nemesis-cloud
```

and writes:

```text
/etc/nemesis-cloud.conf
```

Provisioning logs are written to:

```text
/var/log/nemesis-firstboot.log
```

## Build Configuration

During provisioning, `scripts/install` writes `/etc/nemesis-cloud.conf` inside the VM.
It is generated from the repo-local `nemesis-cloud.conf` file when that file
exists, otherwise defaults are used:

```bash
NEMESIS_USER="user"
NEMESIS_HOSTNAME=""        # Empty generates DESKTOP-XXXXXXX.
NEMESIS_USER_PASSWORD="Ch4ngeM3!"
ENABLE_GRAPHICAL_LOGIN="false"
INSTALL_PROFILE="image"    # image | wsl | container
NEMESIS_REPO_URL=""
NEMESIS_REPO_REF="main"
SSH_AUTHORIZED_KEY=""
RDP_USER="rdp"
RDP_PASSWORD="rdp"
```

For the normal Packer image build, this file is written by `scripts/install` during the
build.

## Troubleshooting

### Check cloud-init inside a VM

```bash
sudo cloud-init status --long
sudo cloud-id
sudo journalctl -u cloud-init-local -u cloud-init -u cloud-config -u cloud-final --no-pager -b
```

If cloud-init says `disabled-by-generator` and `no datasource found`, the VM did
not receive a usable cloud-init datasource.

### Check whether a cloud-init seed disk is attached

Inside the VM:

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS
sudo blkid
```

Look for labels such as `cidata`, `CIDATA`, or `config-2`.

### Check image sizes

```bash
qemu-img info packer/output/nemesis-cloud/nemesis-cloud.qcow2
ls -lh packer/output/nemesis-cloud/
```

The raw image is the full virtual disk size. Compress it with `zstd` before
uploading or archiving.

## Repository Layout

```text
.
├── .github/workflows/        # VM image and container GitHub Actions workflows
├── assets/                   # Vendored visual assets
├── files/                    # System/user config copied into the image
├── packer/                   # Packer QEMU template
├── scripts/                  # Provisioning and helper scripts
├── Dockerfile                # Minimal Arch container image
├── build-image.sh            # Packer wrapper and raw converter
├── scripts/install           # Local/existing-VM/WSL/container installer
└── nemesis-cloud.conf.example
```

## Validation

Useful checks while editing:

```bash
bash -n build-image.sh scripts/install scripts/nemesis-firstboot scripts/nemesis-gnome-firstlogin scripts/nemesis-workspace
packer validate -var output_directory=/tmp/nemesis-cloud-validate-output packer/nemesis-cloud.pkr.hcl
```
