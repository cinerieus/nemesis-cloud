# Nemesis Cloud

Nemesis Cloud builds a reusable Arch Linux VM image with GNOME, BlackArch tools,
CLI configuration, cloud-init support, VM tools, and a shim/GRUB Secure Boot
boot path.

The normal workflow is:

```text
build image locally -> import qcow2/raw into a VM platform -> boot VM -> enroll MOK if Secure Boot is enabled -> log in
```

## Start Here

Install the build dependencies on the machine that will create the image:

```bash
sudo pacman -Sy --needed packer qemu-base xorriso
```

Build the image:

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
| Desktop | GNOME, Firefox, LibreOffice, Kitty, Wofi, Thunar |
| Security tooling | BlackArch repo, selected BlackArch/AUR tools |
| CLI setup | fish, tmux, Neovim, Catppuccin-style config |
| Remote access | SSH enabled, GNOME Remote Desktop configured |
| VM support | VM tools, cloud-init, NetworkManager, systemd-resolved |
| Secure Boot | Microsoft-signed shim, GRUB, local MOK signing |
| Storage | Optional file-backed LUKS workspace helper |
| Output formats | qcow2 and raw |

The repo contains the project scripts, configs, dotfiles, wallpaper, GNOME theme,
GRUB theme, and Wofi CSS. Package installs still use the Arch, BlackArch, AUR,
and GitHub upstreams during the build.

## Default Credentials

Local console user:

```text
user / Ch4ngeM3!
```

GNOME Remote Desktop bootstrap credentials:

```text
rdp / rdp
```

SSH password login is intentionally disabled. Use SSH keys for SSH.

Cloud-init or a provider UI can replace the console user password, root
password, hostname, and SSH keys when the VM is created.

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

## Enabling The Desktop Login

The desktop is installed and themed, but graphical login is disabled by default
for base-image reuse.

Enable it inside the VM:

```bash
sudo systemctl enable --now gdm.service gnome-remote-desktop.service
```

Or enable it with cloud-init when creating the VM:

```yaml
#cloud-config
runcmd:
  - [bash, -lc, "systemctl enable --now gdm.service gnome-remote-desktop.service"]
```

There is a small example cloud-init file at:

```text
examples/user-data.yaml
```

## Encrypted Workspace

Root disk encryption should be handled before first boot, during image creation
or provider provisioning. This repo does not repartition and encrypt an already
running root filesystem.

For a simpler encrypted working area inside the VM:

```bash
sudo nemesis-workspace init --size 50G
sudo nemesis-workspace open
sudo nemesis-workspace close
```

This creates file-backed LUKS storage for `/opt/workspace`.

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

`init.sh` installs the repo into:

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

`/etc/nemesis-cloud.conf` controls the provisioning script:

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

For the normal Packer image build, this file is written by `init.sh` during the
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
├── .github/workflows/        # Optional GitHub Actions build workflow
├── assets/                   # Vendored visual assets
├── examples/                 # Runtime cloud-init examples
├── files/                    # System/user config copied into the image
├── packer/                   # Packer QEMU template
├── scripts/                  # Provisioning and helper scripts
├── build-image.sh            # Packer wrapper and raw converter
└── init.sh                   # Local/existing-VM installer
```

## Validation

Useful checks while editing:

```bash
bash -n build-image.sh init.sh scripts/nemesis-firstboot scripts/nemesis-gnome-firstlogin scripts/nemesis-workspace
packer validate -var output_directory=/tmp/nemesis-cloud-validate-output packer/nemesis-cloud.pkr.hcl
cloud-init schema -c examples/user-data.yaml
```
