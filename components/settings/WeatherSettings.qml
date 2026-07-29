import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: weatherRoot

    // Public properties
    property string zipcode: ""
    
    // Output properties
    property string temp: "--"
    property string feelsLike: "--"
    property string desc: "Loading..."
    property string glyph: "cloud"
    property double lastFetchTime: 0

    readonly property string _weatherUrl: {
        const baseUrl = "https://wttr.in/";
        const query = "?format=j1";
        let target = zipcode.trim() !== "" ? zipcode.trim() : (typeof Config !== "undefined" && Config.locationQuery ? Config.locationQuery.trim() : "");
        return target !== "" ? (baseUrl + "~" + encodeURIComponent(target) + query) : (baseUrl + query);
    }

    function fetchWeather(force) {
        let now = Date.now();
        if (force || lastFetchTime === 0 || (now - lastFetchTime > 900000)) {
            if (!weatherFetcher.running) {
                weatherFetcher.running = true;
            }
        }
    }

    onZipcodeChanged: fetchWeather(true)

    property Process fetcherProcess: Process {
        id: weatherFetcher
        command: ["curl", "-s", "-H", "User-Agent: curl/7.68.0", weatherRoot._weatherUrl]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                let trimmed = this.text ? this.text.trim() : "";
                
                if (!trimmed.startsWith("{") && !trimmed.startsWith("[")) {
                    weatherFetcher.running = false;
                    return;
                }

                try {
                    let data = JSON.parse(trimmed);
                    if (data.current_condition && data.current_condition.length > 0) {
                        let current = data.current_condition[0];
                        weatherRoot.temp = current.temp_F + "°F";
                        weatherRoot.feelsLike = current.FeelsLikeF + "°F";
                        
                        let code = current.weatherCode.toString();
                        let descMap = { 
                            "0": "Clear Sky", "1": "Mainly Clear", "2": "Partly Cloudy", "3": "Overcast", 
                            "45": "Foggy", "48": "Rime Fog", "51": "Light Drizzle", "53": "Moderate Drizzle", 
                            "55": "Dense Drizzle", "61": "Slight Rain", "63": "Moderate Rain", "65": "Heavy Rain", 
                            "71": "Light Snow", "73": "Moderate Snow", "75": "Heavy Snow", "80": "Light Showers", 
                            "85": "Light Snow Showers", "95": "Thunderstorm" 
                        };
                        let iconMap = { 
                            "0": "wb_sunny", "1": "partly_cloudy_day", "2": "partly_cloudy_day", "3": "cloud", 
                            "45": "foggy", "48": "foggy", "51": "rainy", "53": "rainy", "55": "rainy", 
                            "61": "rainy", "63": "rainy", "65": "rainy", "71": "ac_unit", "73": "ac_unit", 
                            "75": "ac_unit", "80": "rainy", "85": "ac_unit", "95": "thunderstorm" 
                        };
                        
                        weatherRoot.desc = descMap[code] || (current.weatherDesc && current.weatherDesc[0] ? current.weatherDesc[0].value : "Clear");
                        weatherRoot.glyph = iconMap[code] || "cloud";
                        weatherRoot.lastFetchTime = Date.now();
                    }
                } catch(e) {
                    // Silently fail to avoid journal log spamming
                }
                weatherFetcher.running = false;
            }
        }
    }
}