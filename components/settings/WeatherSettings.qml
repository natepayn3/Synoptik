pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."

SettingsPage {
    id: root

    title: "Weather"
    description: "Location override for the forecast shown in the bar, calendar and desktop widgets."
    icon: "thermostat"

    SettingsCard {
        title: Config.weather.temp !== "--"
            ? `${Config.weather.temp} • ${Config.weather.desc}`
            : "Weather Forecast"
        subtitle: (Config.weather.areaName ? (Config.weather.areaName + " • ") : "")
            + (Config.locationQuery ? ("Custom: " + Config.locationQuery) : "Auto IP geolocation")
        icon: Config.weather.glyph
        watermark: Config.weather.glyph
        watermarkSeed: 26

        accessory: SettingsButton {
            label: "Sync"
            icon: "refresh"
            busy: Config.weather.isFetching
            onClicked: Config.weather.fetchWeather(true)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: SettingsStyle.tightGap

            Repeater {
                model: [
                    { icon: "water_drop", label: "Humidity", value: Config.weather.humidity },
                    { icon: "air",        label: "Wind",     value: Config.weather.windSpeed },
                    { icon: "wb_sunny",   label: "UV Index", value: Config.weather.uvIndex }
                ]

                delegate: Rectangle {
                    id: statChip

                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: SettingsStyle.controlRadius
                    color: SettingsStyle.controlBg
                    border.width: 1
                    border.color: SettingsStyle.controlBorder

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: statChip.modelData.icon
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 15
                            color: Config.accent
                        }

                        Text {
                            text: `${statChip.modelData.label}: ${statChip.modelData.value}`
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            color: Config.textMain
                        }
                    }
                }
            }
        }
    }

    SettingsCard {
        title: "Location"
        icon: "location_on"
        subtitle: "A city, ZIP code or airport code overrides IP-based geolocation. Leave blank for automatic lookup."

        SettingsTextField {
            id: locationField

            text: Config.locationQuery
            placeholder: "e.g. 90210, London, Tokyo — or blank for Auto IP"
            icon: "search"

            onEditingFinished: value => {
                if (!Config.isLoaded) return
                Config.locationQuery = value.trim()
                Config.weather.fetchWeather(true)
            }

            // Keeps the field in step when the query is changed elsewhere
            // (a preset chip below, or another panel) without stomping on
            // what the user is part-way through typing.
            Connections {
                target: Config
                function onLocationQueryChanged() {
                    if (!locationField.input.activeFocus && locationField.text !== Config.locationQuery) {
                        locationField.text = Config.locationQuery
                    }
                }
            }

            trailing: Text {
                text: "close"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 16
                color: clearHover.hovered ? Config.textMain : Config.textMuted
                visible: locationField.text !== ""

                TapHandler {
                    onTapped: {
                        locationField.text = ""
                        if (!Config.isLoaded) return
                        Config.locationQuery = ""
                        Config.weather.fetchWeather(true)
                    }
                }
                HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
            }
        }

        SettingsField {
            label: "Presets"

            SettingsSegmented {
                currentValue: Config.locationQuery
                model: [
                    { label: "Auto (IP)", value: "",         icon: "my_location" },
                    { label: "New York",  value: "New York" },
                    { label: "London",    value: "London" },
                    { label: "Tokyo",     value: "Tokyo" },
                    { label: "Paris",     value: "Paris" }
                ]
                onSelected: value => {
                    if (!Config.isLoaded) return
                    Config.locationQuery = value
                    locationField.text = value
                    Config.weather.fetchWeather(true)
                }
            }
        }

        SettingsNote {
            text: "Weather refreshes automatically every 15 minutes and updates the calendar, desktop widgets and status bar."
        }
    }
}
