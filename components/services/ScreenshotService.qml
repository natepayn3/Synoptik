import QtQuick
import Quickshell

QtObject {
    id: screenshotRoot

    // Region capture, piped straight into satty for annotation. Satty owns
    // all the actual behavior (save path, copy action, etc.) via its own
    // config file (~/.config/satty/config.toml) or CLI flags - this just
    // triggers the same capture pipeline from both the IPC handler and the
    // LeftModules button instead of duplicating the command in each.
    function capture() {
        Quickshell.execDetached(["fish", "-c", "sleep 0.1; grim -g (slurp) -t ppm - | satty --filename -"])
    }
}
