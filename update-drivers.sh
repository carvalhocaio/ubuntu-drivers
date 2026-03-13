#!/usr/bin/env bash
#
# Driver update script — Lenovo ThinkPad E14
# Ubuntu 24.04 | Intel Iris Xe | Intel Tiger Lake Audio
#
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✔]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✘]${NC} $*"; }
header(){ echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${GREEN}  $*${NC}"; echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    err "Please run with sudo: sudo $0"
    exit 1
fi

header "Driver Update — Lenovo ThinkPad E14"

# ──────────────────────────────────────────────
header "1/7 — Updating repositories and system packages"
# ──────────────────────────────────────────────
apt update
apt upgrade -y
info "System packages updated"

# ──────────────────────────────────────────────
header "2/7 — Video Drivers (Intel Iris Xe / Mesa)"
# ──────────────────────────────────────────────
apt install -y --only-upgrade \
    mesa-vulkan-drivers \
    libgl1-mesa-dri \
    libglu1-mesa \
    libegl-mesa0 \
    libglx-mesa0 \
    mesa-utils \
    intel-media-va-driver \
    intel-gpu-tools \
    xserver-xorg-video-intel 2>/dev/null || true

# Install recommended drivers via ubuntu-drivers
if command -v ubuntu-drivers &>/dev/null; then
    info "Checking recommended drivers..."
    ubuntu-drivers install 2>/dev/null || warn "No additional recommended drivers found"
fi

info "Video drivers updated"

# ──────────────────────────────────────────────
header "3/7 — Audio Drivers (Intel Tiger Lake / PipeWire)"
# ──────────────────────────────────────────────
apt install -y --only-upgrade \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    wireplumber \
    alsa-utils \
    alsa-base \
    firmware-sof-signed \
    linux-firmware 2>/dev/null || true

info "Audio drivers updated"

# ──────────────────────────────────────────────
header "4/7 — Network Drivers (Realtek Wi-Fi/Bluetooth/Ethernet)"
# ──────────────────────────────────────────────
apt install -y --only-upgrade \
    firmware-realtek \
    r8168-dkms \
    bluez \
    bluez-tools 2>/dev/null || true

info "Network drivers updated"

# ──────────────────────────────────────────────
header "5/7 — Firmware and Security Drivers"
# ──────────────────────────────────────────────

# Kernel and security modules
apt install -y --only-upgrade \
    linux-generic \
    linux-firmware \
    intel-microcode \
    fwupd \
    tpm2-tools \
    thermald 2>/dev/null || true

# Ensure thermald is enabled (prevents thermal throttling and freezes)
if systemctl is-enabled thermald &>/dev/null; then
    systemctl start thermald 2>/dev/null || true
    info "thermald is active"
else
    systemctl enable --now thermald 2>/dev/null || warn "Could not enable thermald"
fi

# Vendor firmware (Lenovo) via fwupd
if command -v fwupdmgr &>/dev/null; then
    info "Checking Lenovo firmware via fwupd..."
    fwupdmgr refresh --force 2>/dev/null || true
    fwupdmgr get-updates 2>/dev/null && \
        fwupdmgr update -y 2>/dev/null || warn "No firmware updates available"
fi

info "Security drivers and firmware updated"

# ──────────────────────────────────────────────
header "6/7 — Development Tools"
# ──────────────────────────────────────────────
apt install -y \
    make \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    wget \
    curl \
    llvm \
    libncurses5-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libffi-dev \
    liblzma-dev \
    git \
    vim

info "Development tools installed"

# ──────────────────────────────────────────────
header "7/7 — Cleanup"
# ──────────────────────────────────────────────
apt autoremove -y
apt autoclean -y
info "Cleanup complete"

# ──────────────────────────────────────────────
header "Summary"
# ──────────────────────────────────────────────
echo "  Kernel:    $(uname -r)"
echo "  Mesa:      $(dpkg -l libgl1-mesa-dri 2>/dev/null | awk '/^ii/{print $3}')"
echo "  PipeWire:  $(pipewire --version 2>/dev/null | head -1 || echo 'N/A')"
echo "  Microcode: $(dpkg -l intel-microcode 2>/dev/null | awk '/^ii/{print $3}')"
echo "  fwupd:     $(fwupdmgr --version 2>/dev/null | head -1 || echo 'N/A')"
echo ""

NEEDS_REBOOT=false
if [[ -f /var/run/reboot-required ]]; then
    NEEDS_REBOOT=true
fi

if $NEEDS_REBOOT; then
    warn "Reboot required to apply all updates."
    read -rp "Reboot now? [y/N]: " answer
    if [[ "${answer,,}" == "y" ]]; then
        reboot
    fi
else
    info "No reboot required."
fi

info "Done!"
