<div align="center">

  <h1>SYNOPTIK</h1>

  <p><strong>A fluid, morphing desktop shell built for Hyprland.</strong></p>

  <p>
    <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white" alt="Arch Linux" /></a>
    <a href="https://hyprland.org"><img src="https://img.shields.io/badge/Hyprland-33CCFF?style=for-the-badge&logo=hyprland&logoColor=white" alt="Hyprland" /></a>
    <a href="https://github.com/outfoxxed/quickshell"><img src="https://img.shields.io/badge/Quickshell-41CD52?style=for-the-badge&logo=qt&logoColor=white" alt="Quickshell" /></a>
  </p>

  <br />

  <a href="https://www.youtube.com/watch?v=Cv7NUWnxySg" target="_blank">
  <img width="1024" height="576" alt="5f1c7b8d-fe4a-4504-b6e1-1fac9ddfbc75" src="https://github.com/user-attachments/assets/a4d5413d-38fb-44c8-8418-54cd9f290504" />
  </a>

  <p><em>▶ Click the banner above to watch the showcase video on YouTube</em></p>

</div>

---

> **syn·op·tik** _(/səˈnäptik/)_ — *Bringing disparate elements together into a single, unified view.*

**Synoptik** replaces fragmented docks, status bars, and app launchers with a unified, reactive interface. Instead of rendering static, disjointed surfaces, Synoptik acts as an adaptive surface that morphs its physical footprint to project control panels, telemetry, system controls, and launchers—contracting back into a minimal footprint when idle.

---

## ✨ Key Features

* **Morphing Layouts:** A single persistent surface that fluidly expands and shifts into dedicated modules (App Launcher, Control Center, Media Player) without layout jumps.
* **Compositor Integration:** Leverages native Hyprland layer-shell protocol features, including real-time dynamic blur, custom alpha blending, and xray passthrough.
* **Integrated Lock & Idle IPC:** Bundled `hypridle` and custom IPC hooks for smooth screen locking and screensaver transitions.
* **Zero Boilerplate Deployment:** Single-command setup script with automatic self-update tracking.

---

## 📸 Screenshots

<div align="center">

|  |  |
|:---:|:---:|
| ![Control Center](assets/screenshots/control-center.jpg) | ![Calendar & Notes](assets/screenshots/calendar.jpg) |
| Control Center | Calendar & Notes |
| ![Wallpaper Picker](assets/screenshots/wallpaper-picker.jpg) | ![App Launcher](assets/screenshots/launcher.jpg) |
| Wallpaper Picker | App Launcher |
| ![Power Menu](assets/screenshots/power-menu.jpg) | ![Workspace Overview](assets/screenshots/workspaces.jpg) |
| Power Menu | Workspace Overview |

</div>

---

## ⚡ Quick Install

> [!WARNING]
> **Synoptik is under active development.** Check your existing configuration files before overwriting system styles.

Run the automated installer to clone the repository, link components, and enable update tracking:

```bash
curl -fsSL https://raw.githubusercontent.com/natepayn3/Synoptik/main/install.sh | bash
```

Use --dry-run to see what it would add to your system, and there is also an uninstall.sh
