#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
packer_dir="$repo_dir/packer"

if ! command -v packer >/dev/null 2>&1; then
  echo "packer is required. Install it first, then rerun this script." >&2
  exit 1
fi

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
  echo "qemu-system-x86_64 is required. Install qemu first, then rerun this script." >&2
  exit 1
fi

if ! command -v qemu-img >/dev/null 2>&1; then
  echo "qemu-img is required. Install qemu-img/qemu-tools first, then rerun this script." >&2
  exit 1
fi

cd "$packer_dir"
packer init nemesis-cloud.pkr.hcl
packer build -force "$@" nemesis-cloud.pkr.hcl

qcow2_image="$packer_dir/output/nemesis-cloud/nemesis-cloud.qcow2"
raw_image="$packer_dir/output/nemesis-cloud/nemesis-cloud.raw"

if [[ ! -f "$qcow2_image" ]]; then
  echo "Expected Packer output not found: $qcow2_image" >&2
  exit 1
fi

echo "Converting qcow2 image to raw..."
rm -f "$raw_image"
qemu-img convert -p -f qcow2 -O raw "$qcow2_image" "$raw_image"
qemu-img info "$qcow2_image"
qemu-img info "$raw_image"
