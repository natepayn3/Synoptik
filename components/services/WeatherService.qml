import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: weatherRoot

    // Zipcode or city query override from Config
    property string zipcode: ""

    // Output properties
    property string temp: "--"
    property string feelsLike: "--"
    property string desc: "Loading..."
    property string glyph: "cloud"
    property string areaName: ""
    property string humidity: "--"
    property string windSpeed: "--"
    property string uvIndex: "--"
    property bool isFetching: false
    property double lastFetchTime: 0

    // 7-day forecast (Open-Meteo)
    property var forecast: []

    readonly property var wmoDesc: ({
        "0": "Clear Sky", "1": "Mainly Clear", "2": "Partly Cloudy", "3": "Overcast",
        "45": "Foggy", "48": "Rime Fog", "51": "Light Drizzle", "53": "Moderate Drizzle",
        "55": "Dense Drizzle", "61": "Slight Rain", "63": "Moderate Rain", "65": "Heavy Rain",
        "71": "Light Snow", "73": "Moderate Snow", "75": "Heavy Snow",
        "80": "Light Showers", "81": "Moderate Showers", "82": "Violent Showers",
        "85": "Light Snow Showers", "86": "Heavy Snow Showers",
        "95": "Thunderstorm", "96": "Thunderstorm with Hail", "99": "Severe Thunderstorm"
    })

    function wmoGlyph(code) {
        if (code === 0) return "wb_sunny";
        if (code === 1 || code === 2) return "partly_cloudy_day";
        if (code === 3) return "cloud";
        if (code === 45 || code === 48) return "foggy";
        if (code >= 51 && code <= 67) return "rainy";
        if (code >= 71 && code <= 77) return "ac_unit";
        if (code >= 80 && code <= 82) return "rainy";
        if (code === 85 || code === 86) return "ac_unit";
        if (code >= 95) return "thunderstorm";
        return "cloud";
    }

    // Step 2: once we have coordinates, fetch current conditions + 7-day
    // forecast from Open-Meteo in a single request.
    function fetchWeatherData(latVal, lonVal) {
        weatherRoot.isFetching = true;
        weatherFetcher.running = false;
        let url = "https://api.open-meteo.com/v1/forecast?latitude=" + latVal + "&longitude=" + lonVal
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,uv_index"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=auto&forecast_days=7";
        weatherFetcher.command = ["curl", "-s", "-L", "--max-time", "10", url];
        weatherFetcher.running = true;
    }

    property Process weatherFetcherProcess: Process {
        id: weatherFetcher
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                weatherRoot.isFetching = false;
                let trimmed = this.text ? this.text.trim() : "";
                if (!trimmed.startsWith("{")) return;

                try {
                    let data = JSON.parse(trimmed);

                    if (data.current) {
                        let current = data.current;
                        let code = current.weather_code;

                        weatherRoot.temp = Math.round(current.temperature_2m) + "°F";
                        weatherRoot.feelsLike = Math.round(current.apparent_temperature) + "°F";
                        weatherRoot.humidity = current.relative_humidity_2m + "%";
                        weatherRoot.windSpeed = Math.round(current.wind_speed_10m) + " mph";
                        weatherRoot.uvIndex = (current.uv_index !== undefined && current.uv_index !== null)
                            ? Math.round(current.uv_index).toString() : "--";
                        weatherRoot.desc = weatherRoot.wmoDesc[code.toString()] || "Clear";
                        weatherRoot.glyph = weatherRoot.wmoGlyph(code);
                        weatherRoot.lastFetchTime = Date.now();
                    }

                    if (data.daily && data.daily.time) {
                        let days = [];
                        for (let i = 0; i < data.daily.time.length; i++) {
                            days.push({
                                date: data.daily.time[i],
                                maxF: Math.round(data.daily.temperature_2m_max[i]),
                                minF: Math.round(data.daily.temperature_2m_min[i]),
                                glyph: weatherRoot.wmoGlyph(data.daily.weather_code[i])
                            });
                        }
                        weatherRoot.forecast = days;
                    }
                } catch (e) {
                    console.error("Failed to parse weather JSON:", e);
                }
            }
        }
    }

    // Step 1: resolve a zipcode/city query to coordinates via Open-Meteo's
    // geocoding API, or fall back to IP-based geolocation (ipwho.is) when no
    // location is configured ("Auto IP Geolocation" mode).
    function fetchWeather(force) {
        weatherRoot.isFetching = true;
        locationFetcher.running = false;

        let loc = "";
        if (zipcode && zipcode.toString().trim() !== "") {
            loc = zipcode.toString().trim();
        } else if (typeof Config !== "undefined" && Config.locationQuery) {
            loc = Config.locationQuery.toString().trim();
        }

        if (loc !== "") {
            locationFetcher.mode = "geocode";
            let url = "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(loc) + "&count=1&format=json";
            locationFetcher.command = ["curl", "-s", "-L", "--max-time", "10", url];
        } else {
            locationFetcher.mode = "ip";
            locationFetcher.command = ["curl", "-s", "-L", "--max-time", "10", "https://ipwho.is/"];
        }
        locationFetcher.running = true;
    }

    onZipcodeChanged: {
        if (typeof Config !== "undefined" && Config.isLoaded) {
            lastFetchTime = 0;
            fetchWeather(true);
        }
    }

    property Process locationFetcherProcess: Process {
        id: locationFetcher
        running: false
        property string mode: "geocode"

        stdout: StdioCollector {
            onStreamFinished: {
                let trimmed = this.text ? this.text.trim() : "";
                if (!trimmed.startsWith("{")) {
                    weatherRoot.isFetching = false;
                    return;
                }

                try {
                    let data = JSON.parse(trimmed);
                    let latVal, lonVal;

                    if (locationFetcher.mode === "geocode") {
                        if (!data.results || data.results.length === 0) {
                            weatherRoot.isFetching = false;
                            weatherRoot.desc = "Location not found";
                            return;
                        }
                        let place = data.results[0];
                        latVal = place.latitude;
                        lonVal = place.longitude;
                        weatherRoot.areaName = place.admin1 ? (place.name + ", " + place.admin1) : place.name;
                    } else {
                        if (!data.success) {
                            weatherRoot.isFetching = false;
                            return;
                        }
                        latVal = data.latitude;
                        lonVal = data.longitude;
                        weatherRoot.areaName = data.region ? (data.city + ", " + data.region) : data.city;
                    }

                    weatherRoot.fetchWeatherData(latVal, lonVal);
                } catch (e) {
                    weatherRoot.isFetching = false;
                    console.error("Failed to parse location JSON:", e);
                }
            }
        }
    }
}
