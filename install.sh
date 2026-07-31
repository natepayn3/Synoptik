#!/usr/bin/env fish

function say
    set_color -o cyan
    printf '==> '
    set_color normal
    echo $argv
end

set_color -o cyan
echo '███████╗██╗   ██╗███╗   ██╗ ██████╗ ██████╗ ████████╗██╗██╗  ██╗'
echo '██╔════╝╚██╗ ██╔╝████╗  ██║██╔═══██╗██╔══██╗╚══██╔══╝██║██║ ██╔╝'
echo '███████╗ ╚████╔╝ ██╔██╗ ██║██║   ██║██████╔╝   ██║   ██║█████╔╝ '
echo '╚════██║  ╚██╔╝  ██║╚██╗██║██║   ██║██╔═══╝    ██║   ██║██╔═██╗ '
echo '███████║   ██║   ██║ ╚████║╚██████╔╝██║        ██║   ██║██║  ██╗'
echo '╚══════╝   ╚═╝   ╚═╝  ╚═══╝ ╚═════╝ ╚═╝        ╚═╝   ╚═╝╚═╝  ╚═╝'
set_color normal
echo ""

if test (id -u) -eq 0
    echo "Don't run this as root — run it as your normal user."
    exit 1
end

if not command -v pacman >/dev/null
    echo "pacman not found. Aborting."
    exit 1
end

set AUR_HELPER ""
if command -v paru >/dev/null
    set AUR_HELPER paru
else if command -v yay >/dev/null
    set AUR_HELPER yay
else
    say "Installing yay..."
    sudo pacman -S --needed --noconfirm base-devel git
    or exit 1
    set tmpdir (mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    or exit 1
    set orig_dir (pwd)
    cd "$tmpdir/yay"
    makepkg -si --noconfirm
    or exit 1
    cd "$orig_dir"
    rm -rf "$tmpdir"
    set AUR_HELPER yay
end

set PACMAN_PKGS \
    hyprland \
    base-devel \
    git \
    qt6-base \
    qt6-declarative \
    qt6-5compat \
    qt6-multimedia \
    fish \
    python \
    curl \
    jq \
    wireplumber \
    pipewire \
    pipewire-audio \
    pipewire-pulse \
    pipewire-alsa \
    cava \
    networkmanager \
    bluez \
    bluez-utils \
    brightnessctl \
    playerctl \
    wl-clipboard \
    grim \
    slurp \
    satty \
    showmethekey \
    wf-recorder \
    hypridle \
    libnotify \
    ffmpeg \
    procps-ng \
    psmisc \
    xdg-utils \
    gawk \
    sed \
    coreutils \
    util-linux

say "Installing pacman packages..."
sudo pacman -S --needed $PACMAN_PKGS
or exit 1

set AUR_PKGS \
    quickshell-git \
    awww \
    mpvpaper \
    cliphist \
    ttf-material-symbols-variable-git

say "Installing AUR packages..."
$AUR_HELPER -S --needed $AUR_PKGS
or exit 1

say "Done!"
