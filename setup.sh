#!/usr/bin/env bash
set -e

echo "[*] Creating Debian Live ISO Repository Structure..."
# Create necessary directories
mkdir -p .github/workflows
mkdir -p auto
mkdir -p config/hooks
mkdir -p config/package-lists
mkdir -p config/includes.chroot/etc/skel/.config/autostart
mkdir -p config/includes.chroot/usr/local/bin

echo "[*] Generating auto/config..."
cat << 'EOF' > auto/config
#!/bin/sh
set -e
lb config noauto \
--architecture amd64 \
--distribution bookworm \
--archive-areas "main contrib non-free non-free-firmware" \
--binary-images iso-hybrid \
--debian-installer false \
--memtest none \
--iso-volume "MACOS-DEBIAN-LIVE" \
--apt-recommends false \
--apt-options "--yes --no-install-recommends" \
--parent-mirror-bootstrap "http://deb.debian.org/debian/" \
--parent-mirror-chroot "http://deb.debian.org/debian/" \
--mirror-bootstrap "http://deb.debian.org/debian/" \
--mirror-chroot "http://deb.debian.org/debian/" \
"${@}"
EOF

echo "[*] Generating desktop package list..."
cat << 'EOF' > config/package-lists/desktop.list.chroot
live-boot
live-config
live-config-systemd
linux-image-amd64
systemd-sysv
xfce4
xfce4-goodies
lightdm
lightdm-gtk-greeter
plank
arc-theme
papirus-icon-theme
xfce4-panel-profiles
network-manager
network-manager-gnome
firefox-esr
kitty
htop
git
curl
EOF

echo "[*] Generating chroot hook..."
cat << 'EOF' > config/hooks/0100-macos-theme.chroot
#!/bin/sh
set -e
echo "[*] Enabling system services inside chroot..."
systemctl enable lightdm
systemctl enable NetworkManager
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF

echo "[*] Generating autostart desktop entry..."
cat << 'EOF' > config/includes.chroot/etc/skel/.config/autostart/setup-macos-desktop.desktop
[Desktop Entry]
Type=Application
Name=Setup macOS Theme
Exec=/usr/local/bin/apply-macos-theme.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

echo "[*] Generating theme application script..."
cat << 'EOF' > config/includes.chroot/usr/local/bin/apply-macos-theme.sh
#!/bin/sh
sleep 2
xfconf-query -c xsettings -p /Net/ThemeName -s "Arc-Dark" --create -t string
xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark" --create -t string
xfconf-query -c xfwm4 -p /general/theme -s "Arc-Dark" --create -t string
mkdir -p ~/.config/autostart
cp /usr/share/applications/plank.desktop ~/.config/autostart/ 2>/dev/null || true
nohup plank >/dev/null 2>&1 &
EOF

echo "[*] Generating GitHub Actions workflow..."
cat << 'EOF' > .github/workflows/build-iso.yml
name: Build Custom macOS-Themed Debian ISO

on:
  workflow_dispatch:
  push:
    branches: [ "main" ]

jobs:
  build-iso:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Install Dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y live-build debootstrap squashfs-tools genisoimage xorriso

      - name: Initialize Live Build Configuration
        run: |
          chmod +x auto/config
          chmod +x config/hooks/*.chroot
          chmod +x config/includes.chroot/usr/local/bin/apply-macos-theme.sh

      - name: Build Debian Live ISO
        run: |
          sudo lb build

      - name: Locate and Prepare ISO
        run: |
          ls -lh *.iso
          # Optional: gzip the ISO if it's too large for raw upload limits, 
          # though upload-artifact handles large files well.

      - name: Upload ISO Artifact
        uses: actions/upload-artifact@v4
        with:
          name: macos-debian-live-iso
          path: *.iso
EOF

echo "[*] Setting file execution permissions..."
chmod +x auto/config
chmod +x config/hooks/*.chroot
chmod +x config/includes.chroot/usr/local/bin/apply-macos-theme.sh

echo "[*] Success! All folders and configuration files have been generated correctly."
echo "[*] You can now commit everything to git and push to GitHub."
