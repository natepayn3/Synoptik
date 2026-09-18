#!/usr/bin/env bash

# --- Flag parsing ---
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=1
            ;;
        -h|--help)
            echo "Usage: install.sh [--dry-run] [-h|--help]"
            echo ""
            echo "  --dry-run   Preview every change this installer would make"
            echo "              (packages, services, files) without applying any of it."
            echo "  -h, --help  Show this help text."
            exit 0
            ;;
        *)
            echo "Unknown option: $arg (see --help)"
            exit 1
            ;;
    esac
done

# Prevent running as root
if [ "$(id -u)" -eq 0 ]; then
    echo "Don't run this as root — run it as your normal user."
    exit 1
fi

# Ensure pacman exists (Arch Linux check)
if ! command -v pacman >/dev/null 2>&1; then
    echo "pacman not found. Synoptik requires Arch Linux. Aborting."
    exit 1
fi

# --- Single source of truth for what gets installed / touched ---
PACMAN_PKGS=(
    hyprland base-devel git qt6-base qt6-declarative qt6-5compat
    qt6-multimedia qt6-multimedia-ffmpeg gst-plugins-good gst-plugins-bad
    gst-plugin-pipewire v4l-utils fish python python-gobject curl jq
    wireplumber pipewire pipewire-audio pipewire-pulse pipewire-alsa cava
    networkmanager bluez bluez-utils brightnessctl playerctl wl-clipboard
    grim slurp satty showmethekey wf-recorder hypridle libnotify ffmpeg
    procps-ng psmisc xdg-utils gawk sed coreutils util-linux
    power-profiles-daemon libcanberra qt6-webview qt6-imageformats
    noto-fonts-emoji polkit sddm
)
AUR_PKGS=(
    quickshell-git awww mpvpaper cliphist
    ttf-material-symbols-variable-git iris-colors
)

TARGET_DIR="$HOME/.config/quickshell/Synoptik"
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
LUA_MARKER='require("hypr_style")'
HYPR_STYLE="$HOME/.config/hypr/hypr_style.lua"
MEDIA_CARD_MARKER='float-synoptik-media-card'
SDDM_THEME_IDS=("synoptik" "synoptik-city")
SDDM_THEME_ID="synoptik"  # default active greeter on a fresh install
SDDM_THEMES_DIR="/usr/share/sddm/themes"
SDDM_CONF_FILE="/etc/sddm.conf.d/theme.conf"

# Given an AUR package spec, report whether it (or its -git-stripped base
# package, or a locally-installed provider) already satisfies the install -
# mirrors the detection the real installer uses, so the dry-run preview
# doesn't lie about what's actually missing.
aur_pkg_missing() {
    local pkg="$1"
    local base_pkg="${pkg%-git}"
    pacman -T "$pkg" >/dev/null 2>&1 && return 1
    pacman -T "$base_pkg" >/dev/null 2>&1 && return 1
    pacman -Qs "^$base_pkg" >/dev/null 2>&1 && return 1
    return 0
}

# --- Dry-run: read-only preview, no sudo, no mutation ---
if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> Synoptik install — DRY RUN (no changes will be made)"
    echo ""

    if command -v fish >/dev/null 2>&1; then
        echo "[ok]      fish is already installed"
    else
        echo "[install] fish shell (required to run the rest of the installer)"
    fi

    if command -v paru >/dev/null 2>&1; then
        echo "[ok]      AUR helper found: paru"
    elif command -v yay >/dev/null 2>&1; then
        echo "[ok]      AUR helper found: yay"
    else
        echo "[install] no AUR helper found — would bootstrap yay from the AUR"
    fi

    missing_pacman=()
    for pkg in "${PACMAN_PKGS[@]}"; do
        pacman -T "$pkg" >/dev/null 2>&1 || missing_pacman+=("$pkg")
    done
    if [ "${#missing_pacman[@]}" -eq 0 ]; then
        echo "[ok]      all ${#PACMAN_PKGS[@]} pacman packages already satisfied"
    else
        echo "[install] ${#missing_pacman[@]}/${#PACMAN_PKGS[@]} pacman packages: ${missing_pacman[*]}"
    fi

    missing_aur=()
    for pkg in "${AUR_PKGS[@]}"; do
        aur_pkg_missing "$pkg" && missing_aur+=("$pkg")
    done
    if [ "${#missing_aur[@]}" -eq 0 ]; then
        echo "[ok]      all ${#AUR_PKGS[@]} AUR packages already satisfied"
    else
        echo "[install] ${#missing_aur[@]}/${#AUR_PKGS[@]} AUR packages: ${missing_aur[*]}"
    fi

    if systemctl is-enabled --quiet power-profiles-daemon.service 2>/dev/null; then
        echo "[ok]      power-profiles-daemon.service already enabled"
    else
        echo "[enable]  systemd service: power-profiles-daemon.service"
    fi

    if systemctl is-enabled --quiet bluetooth.service 2>/dev/null; then
        echo "[ok]      bluetooth.service already enabled"
    else
        echo "[enable]  systemd service: bluetooth.service"
    fi

    if systemctl is-enabled --quiet sddm.service 2>/dev/null; then
        echo "[ok]      sddm.service already enabled"
    else
        echo "[enable]  systemd service: sddm.service (becomes the active display manager, replacing any other enabled one)"
    fi

    if [ -d "$TARGET_DIR/.git" ]; then
        echo "[sync]    $TARGET_DIR exists as a git checkout — would git fetch + reset --hard origin/main"
        echo "          (any local, uncommitted edits under this directory would be discarded)"
    elif [ -d "$TARGET_DIR" ]; then
        echo "[replace] $TARGET_DIR exists but is NOT a git checkout — would be deleted entirely and re-cloned"
    else
        echo "[install] would clone Synoptik to $TARGET_DIR"
    fi

    for id in "${SDDM_THEME_IDS[@]}"; do
        dest="$SDDM_THEMES_DIR/$id"
        if [ -d "$dest" ]; then
            echo "[sync]    $dest exists — would be replaced with the repo's current $id theme files"
        else
            echo "[install] would install the $id SDDM greeter theme to $dest"
        fi
    done

    current_val=""
    if [ -f "$SDDM_CONF_FILE" ]; then
        current_val="$(grep -h '^Current=' "$SDDM_CONF_FILE" 2>/dev/null | tail -1 | cut -d= -f2)"
    fi
    already_ours=0
    for id in "${SDDM_THEME_IDS[@]}"; do
        [ "$current_val" = "$id" ] && already_ours=1
    done
    if [ "$already_ours" -eq 1 ]; then
        echo "[ok]      $SDDM_CONF_FILE already set to your chosen greeter (Current=$current_val), would leave it"
    else
        echo "[modify]  would set Current=$SDDM_THEME_ID in $SDDM_CONF_FILE"
    fi

    if [ -f "$HYPR_LUA" ] && grep -q "$LUA_MARKER" "$HYPR_LUA" 2>/dev/null; then
        echo "[ok]      $HYPR_LUA already requires hypr_style, would skip"
    else
        echo "[modify]  would back up $HYPR_LUA and append:"
        echo "              -- Load custom isolated dynamic border style configuration"
        echo "              require(\"hypr_style\")"
    fi

    if [ -f "$HYPR_STYLE" ] && grep -q "$MEDIA_CARD_MARKER" "$HYPR_STYLE" 2>/dev/null; then
        echo "[ok]      $HYPR_STYLE already has the Synoptik Media Card float rule, would skip"
    else
        echo "[modify]  would back up $HYPR_STYLE (if present) and append the Synoptik Media Card float window rule"
    fi

    if pgrep -x quickshell >/dev/null 2>&1 || pgrep -x qs >/dev/null 2>&1; then
        echo "[restart] a running quickshell/qs instance would be killed and relaunched as 'qs -c Synoptik'"
    else
        echo "[start]   would launch 'qs -c Synoptik'"
    fi

    echo ""
    echo "Dry run complete — no changes were made. Run without --dry-run to apply."
    exit 0
fi

# 1. Install fish if missing
if ! command -v fish >/dev/null 2>&1; then
    echo "==> Installing fish shell via pacman..."
    sudo pacman -S --needed --noconfirm fish || exit 1
fi

export SYN_PACMAN_PKGS="${PACMAN_PKGS[*]}"
export SYN_AUR_PKGS="${AUR_PKGS[*]}"
export SYN_TARGET_DIR="$TARGET_DIR"
export SYN_HYPR_LUA="$HYPR_LUA"
export SYN_HYPR_STYLE="$HYPR_STYLE"
export SYN_SDDM_THEME_ID="$SDDM_THEME_ID"
export SYN_SDDM_THEME_IDS="${SDDM_THEME_IDS[*]}"
export SYN_SDDM_THEMES_DIR="$SDDM_THEMES_DIR"
export SYN_SDDM_CONF_FILE="$SDDM_CONF_FILE"

# 2. Hand execution off to fish
exec fish -c '
# Ensure terminal scroll region is restored on exit or error
function cleanup
    # Reset scrolling region to full screen
    tput csr 0 (tput lines)
    # Move cursor to bottom
    tput cup (tput lines) 0
end
trap cleanup EXIT INT TERM

# Clear screen completely
clear

# Print fixed ASCII Art at the top (Lines 1–8)
set_color -o cyan
echo "███████╗██╗   ██╗███╗   ██╗ ██████╗ ██████╗ ████████╗██╗██╗  ██╗"
echo "██╔════╝╚██╗ ██╔╝████╗  ██║██╔═══██╗██╔═══██╗╚══██╔══╝██║██║ ██╔╝"
echo "███████╗ ╚████╔╝ ██╔██╗ ██║██║   ██║██████╔╝   ██║   ██║█████╔╝ "
echo "╚════██║  ╚██╔╝  ██║╚██╗██║██║   ██║██╔═══╝    ██║   ██║██╔═██╗ "
echo "███████║   ██║   ██║ ╚████║╚██████╔╝██║        ██║   ██║██║  ██╗"
echo "╚══════╝   ╚═╝   ╚═╝  ╚═══╝ ╚═════╝ ╚═╝        ╚═╝   ╚═╝╚═╝  ╚═╝"
set_color normal
echo "-----------------------------------------------------------------"

# Lock lines 1–9 at the top and set scroll region from line 10 to screen bottom
set lines (tput lines)
tput csr 9 $lines
# Position cursor at line 10 to begin execution output
tput cup 9 0

function say
    set_color -o cyan
    printf "==> "
    set_color normal
    echo $argv
end

# Check for or bootstrap an AUR helper (paru or yay)
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

# Official Arch packages (passed in from the bash wrapper - single source of truth)
set PACMAN_PKGS (string split " " "$SYN_PACMAN_PKGS")

say "Installing pacman packages..."
sudo pacman -S --needed --noconfirm $PACMAN_PKGS
or exit 1

# Explicit AUR packages (passed in from the bash wrapper - single source of truth)
set AUR_PKGS (string split " " "$SYN_AUR_PKGS")

# Check both exact package names and provided capabilities via pacman -T / pacman -Qs
set MISSING_AUR_PKGS
for pkg in $AUR_PKGS
    # Strip -git suffix for local capability comparison
    set base_pkg (string replace -r -- "-git\$" "" $pkg)

    # Test if package, base package, or capability is satisfied
    if pacman -T $pkg >/dev/null 2>&1
        continue
    else if pacman -T $base_pkg >/dev/null 2>&1
        continue
    else if pacman -Qs "^$base_pkg" >/dev/null 2>&1
        continue
    else
        set -a MISSING_AUR_PKGS $pkg
    end
end

if test -n "$MISSING_AUR_PKGS"
    say "Installing missing AUR packages: $MISSING_AUR_PKGS..."
    $AUR_HELPER -S --needed $MISSING_AUR_PKGS
    or exit 1
else
    say "All AUR packages are already installed, skipping."
end

say "Enabling systemd services..."
sudo systemctl enable --now power-profiles-daemon.service
or exit 1
sudo systemctl enable --now bluetooth.service
or exit 1

set TARGET_DIR "$SYN_TARGET_DIR"
say "Deploying Synoptik Shell files..."

mkdir -p "$HOME/.config/quickshell"

# CD out of target directory to ensure working directory stays valid during clone/removal
cd "$HOME"

# Clone or pull latest repository state
if test -d "$TARGET_DIR/.git"
    say "Existing git installation detected at $TARGET_DIR. Syncing with remote..."
    cd "$TARGET_DIR"
    git fetch origin main >/dev/null 2>&1
    and git reset --hard origin/main >/dev/null 2>&1
    or begin
        echo "Failed to sync repo at $TARGET_DIR"
        exit 1
    end
else
    say "Cloning repository to $TARGET_DIR..."
    if test -d "$TARGET_DIR"
        rm -rf "$TARGET_DIR"
    end
    git clone -b main https://github.com/natepayn3/Synoptik.git "$TARGET_DIR"
    or begin
        echo "Failed to clone repository."
        exit 1
    end
end

# Make all backend helper scripts executable
if test -d "$TARGET_DIR/scripts"
    say "Setting executable permissions on backend scripts..."
    chmod +x "$TARGET_DIR"/scripts/*
end

# The SDDM greeter theme ships inside the repo (sddm-theme/<id>) so it stays
# in sync with everything else on a `git reset --hard` re-run, rather than
# living only on whichever machine first built it.
set SDDM_THEME_ID "$SYN_SDDM_THEME_ID"
set SDDM_THEME_IDS (string split " " "$SYN_SDDM_THEME_IDS")
set SDDM_THEMES_DIR "$SYN_SDDM_THEMES_DIR"
set SDDM_CONF_FILE "$SYN_SDDM_CONF_FILE"

set INSTALLED_ANY_THEME 0
for id in $SDDM_THEME_IDS
    set theme_src "$TARGET_DIR/sddm-theme/$id"
    set theme_dest "$SDDM_THEMES_DIR/$id"
    if test -d "$theme_src"
        say "Installing the $id SDDM greeter theme..."
        sudo rm -rf "$theme_dest"
        sudo cp -r "$theme_src" "$theme_dest"
        or begin
            echo "Failed to install SDDM theme to $theme_dest"
            exit 1
        end
        set INSTALLED_ANY_THEME 1
    else
        say "No sddm-theme/$id directory found in the repo, skipping."
    end
end

if test $INSTALLED_ANY_THEME -eq 1
    sudo mkdir -p (dirname "$SDDM_CONF_FILE")

    # Avoid clobbering a greeter the user already picked (via Settings) among
    # the themes we ship - only fall back to the default on a fresh config
    # or one pointed at something outside our set.
    set CURRENT_VAL ""
    if test -f "$SDDM_CONF_FILE"
        set CURRENT_VAL (grep -h '\''^Current='\'' $SDDM_CONF_FILE 2>/dev/null | tail -1 | cut -d= -f2)
    end
    set ALREADY_OURS 0
    for id in $SDDM_THEME_IDS
        if test "$CURRENT_VAL" = "$id"
            set ALREADY_OURS 1
        end
    end

    if test $ALREADY_OURS -eq 0
        if test -f "$SDDM_CONF_FILE"; and grep -q '\''^Current='\'' "$SDDM_CONF_FILE"
            sudo sed -i "s/^Current=.*/Current=$SDDM_THEME_ID/" "$SDDM_CONF_FILE"
        else
            printf '\''[Theme]\nCurrent=%s\n'\'' "$SDDM_THEME_ID" | sudo tee "$SDDM_CONF_FILE" >/dev/null
        end
    end

    say "Enabling sddm.service..."
    sudo systemctl enable --now sddm.service
    or exit 1
end

set HYPR_LUA "$SYN_HYPR_LUA"
set LUA_DIRECTIVE "-- Load custom isolated dynamic border style configuration\nrequire(\"hypr_style\")"

say "Updating Hyprland Lua configuration..."
mkdir -p "$HOME/.config/hypr"
touch "$HYPR_LUA"

# Append the directive only if it does not already exist in the file
if not grep -q "require(\"hypr_style\")" "$HYPR_LUA"
    # Back up before mutating so the change is trivially reversible
    cp "$HYPR_LUA" "$HYPR_LUA.bak-"(date +%Y%m%d%H%M%S)
    # Ensure file ends with a newline before appending logic
    test -s "$HYPR_LUA"; and test (tail -c 1 "$HYPR_LUA" | wc -l) -eq 0; and echo "" >> "$HYPR_LUA"
    echo -e "\n$LUA_DIRECTIVE" >> "$HYPR_LUA"
    say "Appended hypr_style require directive to $HYPR_LUA (backup saved alongside it)"
else
    say "Directive already present in $HYPR_LUA, skipping."
end

# The detached Media Card widget is a real floating (xdg-toplevel) window,
# not a layer-shell panel, so Hyprland tiles it like any other app window
# unless a rule says otherwise - without this it opens tiled into whatever
# workspace layout is active instead of floating where it was dropped.
set HYPR_STYLE "$SYN_HYPR_STYLE"
# Double-quoted (not single-quoted, like LUA_DIRECTIVE above) - this whole
# fish script is itself embedded in a single-quoted bash string, so a raw
# single quote in here would terminate that outer string early.
set MEDIA_CARD_RULE "hl.window_rule({\n    name  = \"float-synoptik-media-card\",\n    match = { title = \"^Synoptik Media Card\$\" },\n    float = true,\n})"

say "Ensuring Synoptik Media Card float rule exists in hypr_style.lua..."
mkdir -p "$HOME/.config/hypr"
touch "$HYPR_STYLE"

if not grep -q "float-synoptik-media-card" "$HYPR_STYLE"
    # Back up before mutating so the change is trivially reversible
    cp "$HYPR_STYLE" "$HYPR_STYLE.bak-"(date +%Y%m%d%H%M%S)
    test -s "$HYPR_STYLE"; and test (tail -c 1 "$HYPR_STYLE" | wc -l) -eq 0; and echo "" >> "$HYPR_STYLE"
    echo -e "\n$MEDIA_CARD_RULE" >> "$HYPR_STYLE"
    say "Appended Synoptik Media Card float rule to $HYPR_STYLE (backup saved alongside it)"
else
    say "Float rule already present in $HYPR_STYLE, skipping."
end

say "Restarting quickshell..."
# Suppress error outputs if no instances were running
killall quickshell >/dev/null 2>&1
killall qs >/dev/null 2>&1

# Launch new instance and disown job
qs -c Synoptik >/dev/null 2>&1 &
disown

echo ""
say "Done! Synoptik Shell is ready and running."
'
