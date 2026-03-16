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

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
as_user() { sudo -u "$REAL_USER" bash -c "$*"; }

header "Driver Update — Lenovo ThinkPad E14"

# ──────────────────────────────────────────────
header "1/10 — Updating repositories and system packages"
# ──────────────────────────────────────────────
apt update
apt upgrade -y
info "System packages updated"

# ──────────────────────────────────────────────
header "2/10 — Video Drivers (Intel Iris Xe / Mesa)"
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
header "3/10 — Audio Drivers (Intel Tiger Lake / PipeWire)"
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
header "4/10 — Network Drivers (Realtek Wi-Fi/Bluetooth/Ethernet)"
# ──────────────────────────────────────────────
apt install -y --only-upgrade \
    firmware-realtek \
    r8168-dkms \
    bluez \
    bluez-tools 2>/dev/null || true

info "Network drivers updated"

# ──────────────────────────────────────────────
header "5/10 — Firmware and Security Drivers"
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
header "6/10 — Development Tools"
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
header "7/10 — Shell Setup (Fish + Starship)"
# ──────────────────────────────────────────────
apt install -y fish
chsh -s /usr/bin/fish "$REAL_USER"
info "Fish shell installed and set as default"

curl -sS https://starship.rs/install.sh | sh -s -- -y
info "Starship prompt installed"

as_user mkdir -p "$REAL_HOME/.config/fish"

cat > "$REAL_HOME/.config/fish/config.fish" << 'FISHEOF'
if status is-interactive
    starship init fish | source
    eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)
    set -gx PATH $HOME/.asdf/shims $PATH
end
FISHEOF
chown "$REAL_USER":"$REAL_USER" "$REAL_HOME/.config/fish/config.fish"

cat > "$REAL_HOME/.config/starship.toml" << 'STAREOF'
# Get editor completions based on the config schema
"$schema" = 'https://starship.rs/config-schema.json'

# Inserts a blank line between shell prompts
add_newline = true

# Replace the '❯' symbol in the prompt with '➜'
[character] # The name of the module we are configuring is 'character'
success_symbol = '[➜](bold green)' # The 'success_symbol' segment is being set to '➜' with the color 'bold green'
error_symbol = '[➜](bold green)'

# Disable the package module, hiding it from the prompt completely
[package]
disabled = true

[nodejs]
symbol = "⬢ "

[gcloud]
disabled = true
STAREOF
chown "$REAL_USER":"$REAL_USER" "$REAL_HOME/.config/starship.toml"
info "Fish and Starship configured"

# ──────────────────────────────────────────────
header "8/10 — Homebrew + asdf"
# ──────────────────────────────────────────────
if [[ ! -d /home/linuxbrew/.linuxbrew ]]; then
    as_user 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    info "Homebrew installed"
else
    info "Homebrew already installed"
fi

as_user 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && brew install asdf'
info "asdf installed"

as_user 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && asdf plugin add python || true'
as_user 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && asdf plugin add nodejs || true'
info "asdf plugins added (python, nodejs)"

as_user 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && asdf install python 3.10.14 && asdf set --u python 3.10.14'
info "Python 3.10.14 installed"

as_user 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && asdf install nodejs 24.14.0 && asdf set --u nodejs 24.14.0'
info "Node.js 24.14.0 installed"

# ──────────────────────────────────────────────
header "9/10 — Tools (gh CLI + Zed)"
# ──────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    apt update
    apt install -y gh
    info "gh CLI installed"
else
    info "gh CLI already installed"
fi

as_user 'curl -f https://zed.dev/install.sh | sh'
info "Zed editor installed"

# ──────────────────────────────────────────────
header "10/10 — Cleanup"
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
echo "  Fish:      $(fish --version 2>/dev/null || echo 'N/A')"
echo "  Starship:  $(starship --version 2>/dev/null | head -1 || echo 'N/A')"
echo "  Python:    $(as_user '$HOME/.asdf/shims/python --version' 2>/dev/null || echo 'N/A')"
echo "  Node.js:   $(as_user '$HOME/.asdf/shims/node --version' 2>/dev/null || echo 'N/A')"
echo "  gh:        $(gh --version 2>/dev/null | head -1 || echo 'N/A')"
echo "  Zed:       $(as_user '$HOME/.local/bin/zed --version' 2>/dev/null || echo 'N/A')"
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
