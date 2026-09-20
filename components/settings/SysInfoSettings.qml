import QtQuick
import ".."

SettingsPage {
    id: root

    title: "System Info"
    description: "Desktop telemetry overlay - identifiers, hardware specs, network metrics and resource bars."
    icon: "terminal"

    readonly property bool sysInfoEnabled: Config.showDesktopSysInfo !== false

    SettingsCard {
        title: "System Info Overlay"
        icon: "terminal"

        SettingsToggleRow {
            title: "Enable Desktop System Info Overlay"
            subtitle: "Render live telemetry, hardware specifications and resource bars onto your desktop"
            checked: Config.showDesktopSysInfo !== false
            onToggled: Config.showDesktopSysInfo = (Config.showDesktopSysInfo === false)
        }

        SettingsNote {
            text: "Click and drag anywhere on the widget to reposition it. Scroll directly on it to scale."
        }

        SettingsField {
            label: "Target Displays"
            hint: "With none selected the overlay appears on every display."
            active: root.sysInfoEnabled

            SettingsScreenPicker {
                enabledScreens: Config.enabledSysInfoScreens
                onToggle: screenName => Config.toggleSysInfoScreen(screenName)
            }
        }
    }

    SettingsCard {
        title: "System & OS Identifiers"
        icon: "badge"
        bodyEnabled: root.sysInfoEnabled

        SettingsToggleList {
            model: [
                { key: "sysInfoShowHost",     label: "Host & User Header",      desc: "Username@hostname header badge with accent glow", icon: "badge" },
                { key: "sysInfoShowOs",       label: "Operating System Distro", desc: "Linux distribution release name",                 icon: "desktop_windows" },
                { key: "sysInfoShowKernel",   label: "Kernel Release",          desc: "Running Linux kernel version (uname -r)",         icon: "memory" },
                { key: "sysInfoShowUptime",   label: "System Uptime",           desc: "Elapsed time since last boot",                    icon: "history" },
                { key: "sysInfoShowPackages", label: "Installed Packages",      desc: "Total installed pacman package count",            icon: "inventory_2" },
                { key: "sysInfoShowWm",       label: "Compositor / Window Mgr", desc: "Active Wayland compositor and build tag",         icon: "view_carousel" }
            ]
        }
    }

    SettingsCard {
        title: "Hardware Specifications"
        icon: "developer_board"
        bodyEnabled: root.sysInfoEnabled

        SettingsToggleList {
            model: [
                { key: "sysInfoShowBoard", label: "Motherboard / Machine Model", desc: "DMI hardware product and chassis identifier", icon: "developer_board" },
                { key: "sysInfoShowCpu",   label: "Processor Model",             desc: "CPU architecture brand and model identifier", icon: "memory_alt" },
                { key: "sysInfoShowCores", label: "CPU Core & Thread Count",     desc: "Total accessible logical processor threads",  icon: "grid_view" },
                { key: "sysInfoShowLoad",  label: "System Load Averages",        desc: "1, 5 and 15-minute system load averages",     icon: "speed" },
                { key: "sysInfoShowGpu",   label: "Dedicated Graphics (GPU)",    desc: "PCI display adapter and GPU controller name", icon: "videogame_asset" }
            ]
        }
    }

    SettingsCard {
        title: "Network & Routing"
        icon: "lan"
        bodyEnabled: root.sysInfoEnabled

        SettingsToggleList {
            model: [
                { key: "sysInfoShowIp",      label: "Primary IPv4 Address", desc: "Default routed private interface address", icon: "lan" },
                { key: "sysInfoShowGateway", label: "Default Gateway",      desc: "Default upstream gateway router IP",       icon: "router" },
                { key: "sysInfoShowDns",     label: "DNS Server",           desc: "Primary name resolution server",           icon: "dns" }
            ]
        }
    }

    SettingsCard {
        title: "Resource Usage Bars"
        icon: "speed"
        bodyEnabled: root.sysInfoEnabled

        SettingsToggleList {
            model: [
                { key: "sysInfoShowRam",      label: "Memory (RAM) Gauge",       desc: "Live physical memory usage and capacity bar", icon: "memory" },
                { key: "sysInfoShowSwap",     label: "Swap Memory Gauge",        desc: "Swap space allocation and usage bar",         icon: "swap_horiz" },
                { key: "sysInfoShowDisk",     label: "Root Storage (/) Gauge",   desc: "Root filesystem partition fill level",        icon: "hard_drive" },
                { key: "sysInfoShowDiskHome", label: "Home Storage (/home) Bar", desc: "Home directory filesystem fill level",        icon: "folder" }
            ]
        }
    }

    SettingsCard {
        title: "Styling & Refresh"
        icon: "palette"
        bodyEnabled: root.sysInfoEnabled

        SettingsToggleRow {
            title: "Show Card Background"
            subtitle: "Render a semi-transparent background panel behind the widget"
            checked: Config.sysInfoShowBg !== false
            onToggled: Config.sysInfoShowBg = (Config.sysInfoShowBg === false)
        }

        SettingsToggleRow {
            title: "Show Accent Glow"
            subtitle: "Apply an accent-coloured glow to the host header badge"
            checked: Config.sysInfoShowGlow !== false
            onToggled: Config.sysInfoShowGlow = (Config.sysInfoShowGlow === false)
        }

        SettingsField {
            label: "Refresh Rate"

            SettingsSegmented {
                currentValue: Config.sysInfoRefreshInterval || 3000
                itemWidth: 150
                model: [
                    { label: "1s (Realtime)", value: 1000,  icon: "bolt" },
                    { label: "3s (Balanced)", value: 3000,  icon: "balance" },
                    { label: "10s (Eco)",     value: 10000, icon: "eco" }
                ]
                onSelected: value => Config.sysInfoRefreshInterval = value
            }
        }
    }
}
