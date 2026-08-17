# syntax=docker/dockerfile:1

FROM archlinux:latest

ENV LANG=en_GB.UTF-8
ENV TERM=xterm-256color

COPY . /usr/src/nemesis-cloud
WORKDIR /usr/src/nemesis-cloud

RUN <<'EOF'
set -euo pipefail

sed -i 's/^CheckSpace/#CheckSpace/' /etc/pacman.conf
pacman -Sy --noconfirm --needed archlinux-keyring
pacman -Syu --noconfirm

cat > nemesis-cloud.conf <<'CONF'
NEMESIS_USER=""
NEMESIS_USER_PASSWORD=""
NEMESIS_HOSTNAME=""
ENABLE_GRAPHICAL_LOGIN="false"
INSTALL_PROFILE="container"
SSH_AUTHORIZED_KEY=""
RDP_USER=""
RDP_PASSWORD=""
NEMESIS_REPO_URL=""
NEMESIS_REPO_REF="main"
CONF

./scripts/install --container --force-config

pacman -Scc --noconfirm
rm -rf \
  /usr/src/nemesis-cloud \
  /var/cache/pacman/pkg/* \
  /tmp/* \
  /var/tmp/* \
  /root/.cache \
  /home/builder/.cache
EOF

WORKDIR /root
CMD ["fish"]
