# Changelog - Common Diagnostics

Alle wichtigen Änderungen an diesem gemeinsamen Diagnose-Paket werden in dieser Datei dokumentiert. Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/) und diese Versionierung folgt dem [Semantic Versioning](https://semver.org/lang/de/).

---

## [1.0.0] - 2026-05-30

### Hinzugefügt
- **Initialer Release:** Bereitstellung des zentralen, plattformübergreifenden Diagnose-Packages (`common/diagnostics.yaml`) zur Wiederverwendung in allen ESPHome-Projekten (ESP8266, ESP32, ESP32-C6, ESP32-S3).
- **Hardware-Metriken (Rohdaten):** Integration von Kern-Sensoren zur Überwachung der Systemstabilität: `wifi_signal` (WLAN-Pegel in dBm), `debug` (freier Heap-Speicher in Bytes) und `uptime` (Laufzeit, per Lambda-Filter automatisch in Minuten umgerechnet).
- **Signalglättung:** Hinzufügen eines Filters für den WLAN-Signalpegel mittels eines gleitenden Mittelwerts (`sliding_window_moving_average` über 3 Messungen), um unruhige Sensor-Historien in Home Assistant zu vermeiden.
- **Visuelles Ampel-System:** Erstellung interpretierter Text-Sensoren zur schnellen Statuserfassung mittels intuitiver Emojis:
  - *WLAN Status:* Dynamische Einteilung in `🟢 Exzellent`, `🟡 Okay (Roaming)` und `🔴 Kritisch` anhand konfigurierbarer RSSI-Schwellen.
  - *System Gesundheit:* Automatische Evaluierung des RAM-Zustands in `🟢 Stabil`, `🟡 Warnung` und `🔴 Kritisch` zur frühzeitigen Erkennung drohender Abstürze (Memory Leaks).
- **Netzwerk- & Roaming-Analyse:** Einbindung der `wifi_info`-Plattform zur Erfassung von IP-Adresse, aktiver SSID, Geräte-MAC und der BSSID (MAC-Adresse des spezifischen Routers/Repeaters), um Probleme beim Access-Point-Wechsel im Mesh-Netzwerk zu diagnostizieren.
- **Smarte Neustart-Analyse:** Integration des `reset_reason`-Sensors aus der `debug`-Plattform, um den genauen Grund des letzten Boot-Vorgangs (z. B. regulärer Neustart, Stromausfall, Hardware-Crash, Software-Watchdog) direkt in Home Assistant sichtbar zu machen.
- **Plattformunabhängige Schwellwerte (Substitutions):** Vollständige Auslagerung der Grenzwerte für RAM und Signalstärke in den `substitutions`-Block. Konservative Fallback-Werte für den ESP8266 sind vordefiniert. Diese können in den übergeordneten Projekt-YAMLs für stärkere Controller (ESP32/C6/S3) flexibel überschrieben werden, ohne die gemeinsame Paketdatei verändern zu müssen.
- **Zentrale Paket-Versionierung:** Implementierung des Text-Sensors `Common Diagnostics Version`, der die im Paket definierte Versionsvariable (`${version}`) ausliest. Dies erlaubt eine präzise Kontrolle darüber, welche Geräte im Netzwerk bereits per OTA-Update auf den neuesten Stand der Diagnose-Logik gebracht wurden.