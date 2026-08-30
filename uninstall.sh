#!/usr/bin/env bash
#
# Uninstall Synoptik. Reverses exactly what install.sh did:
#   - stops any running quickshell/qs instance
#   - removes the "require(\"hypr_style\")" directive it appended to
#     ~/.config/hypr/hyprland.lua (backing the file up first)
#   - moves ~/.config/quickshell/Synoptik out of the way (or deletes it
#     outright with --purge)
#
# It deliberately does NOT remove pacman/AUR packages or disable the
# power-profiles-daemon.service install.sh enabled — those are shared
# system state other things may depend on, and pruning them automatically
# is exactly the kind of "helpful" surprise an uninstaller shouldn't spring
# on you. They're listed at the end instead.

set -u

DRY_RUN=0
PURGE=0
ASSUME_YES=0

for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=1
            ;;
        --purge)
            PURGE=1
            ;;
        -y|--yes)
            ASSUME_YES=1
            ;;
        -h|--help)
            echo "Usage: uninstall.sh [--dry-run] [--purge] [-y|--yes] [-h|--help]"
            echo ""
            echo "  --dry-run   Preview what would be removed without changing anything."
            echo "  --purge     Delete the Synoptik config directory outright instead of"
            echo "              moving it to a timestamped backup next to it."
            echo "  -y, --yes   Don't prompt for confirmation before making changes."
            echo "  -h, --help  Show this help text."
            exit 0
            ;;
        *)
            echo "Unknown option: $arg (see --help)"
            exit 1
            ;;
    esac
done

TARGET_DIR="$HOME/.config/quickshell/Synoptik"
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
LUA_COMMENT='-- Load custom isolated dynamic border style configuration'
LUA_MARKER='require("hypr_style")'
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

running_pid=""
if pgrep -x quickshell >/dev/null 2>&1; then
    running_pid="quickshell"
elif pgrep -x qs >/dev/null 2>&1; then
    running_pid="qs"
fi

lua_has_marker=0
if [ -f "$HYPR_LUA" ] && grep -qF "$LUA_MARKER" "$HYPR_LUA" 2>/dev/null; then
    lua_has_marker=1
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> Synoptik uninstall — DRY RUN (no changes will be made)"
    echo ""

    if [ -n "$running_pid" ]; then
        echo "[stop]    running $running_pid process would be killed"
    else
        echo "[ok]      no running quickshell/qs instance found"
    fi

    if [ "$lua_has_marker" -eq 1 ]; then
        echo "[modify]  would back up $HYPR_LUA and remove the hypr_style require directive"
    else
        echo "[ok]      $HYPR_LUA has no hypr_style directive, nothing to remove"
    fi

    if [ -d "$TARGET_DIR" ]; then
        if [ "$PURGE" -eq 1 ]; then
            echo "[delete]  $TARGET_DIR would be permanently deleted (--purge)"
        else
            echo "[move]    $TARGET_DIR would be moved to ${TARGET_DIR}.removed-${TIMESTAMP}"
        fi
    else
        echo "[ok]      $TARGET_DIR does not exist, nothing to remove"
    fi

    echo ""
    echo "Not touched (shared system state — remove manually if you want them gone):"
    echo "  - pacman/AUR packages installed for Synoptik (hyprland, quickshell-git, cava, awww, ...)"
    echo "  - the power-profiles-daemon.service systemd unit"
    echo ""
    echo "Dry run complete — no changes were made. Run without --dry-run to apply."
    exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
    echo "This will stop Synoptik, remove its hyprland.lua directive, and"
    if [ "$PURGE" -eq 1 ]; then
        echo "permanently delete $TARGET_DIR."
    else
        echo "move $TARGET_DIR aside to a timestamped backup."
    fi
    read -r -p "Continue? [y/N] " reply
    case "$reply" in
        y|Y|yes|YES) ;;
        *) echo "Aborted, nothing changed."; exit 0 ;;
    esac
fi

echo "==> Stopping Synoptik..."
killall quickshell >/dev/null 2>&1
killall qs >/dev/null 2>&1

if [ "$lua_has_marker" -eq 1 ]; then
    echo "==> Removing hypr_style directive from $HYPR_LUA..."
    cp "$HYPR_LUA" "$HYPR_LUA.bak-$TIMESTAMP"
    # Drop the marker line and, if it directly precedes it, the comment line
    # Synoptik's installer writes above it. Leaves everything else in the
    # file untouched, including any blank line the installer added before it.
    grep -vF "$LUA_MARKER" "$HYPR_LUA.bak-$TIMESTAMP" | grep -vF "$LUA_COMMENT" > "$HYPR_LUA"
    echo "    backup saved to $HYPR_LUA.bak-$TIMESTAMP"
else
    echo "==> $HYPR_LUA has no hypr_style directive, skipping."
fi

if [ -d "$TARGET_DIR" ]; then
    if [ "$PURGE" -eq 1 ]; then
        echo "==> Deleting $TARGET_DIR..."
        rm -rf "$TARGET_DIR"
    else
        dest="${TARGET_DIR}.removed-${TIMESTAMP}"
        echo "==> Moving $TARGET_DIR to $dest..."
        mv "$TARGET_DIR" "$dest"
        echo "    (delete it yourself once you're sure, or re-run with --purge next time)"
    fi
else
    echo "==> $TARGET_DIR does not exist, skipping."
fi

echo ""
echo "Done. Synoptik has been removed."
echo ""
echo "Not touched (shared system state — remove manually if you want them gone):"
echo "  - pacman/AUR packages installed for Synoptik (hyprland, quickshell-git, cava, awww, ...)"
echo "  - the power-profiles-daemon.service systemd unit"
