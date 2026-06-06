# Changelog - Common Diagnostics

Alle wichtigen Änderungen an diesem gemeinsamen Diagnose-Paket werden in dieser Datei dokumentiert. Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/) und diese Versionierung folgt dem [Semantic Versioning](https://semver.org/lang/de/).

---

## [1.2.1] - 2026-06-06
*(Hinweis: Dieses Release fasst die initialen Entwicklungsphasen V1.0.0 bis V1.2.1 in einem konsolidierten Update zusammen).*

### Hinzugefügt
- **Access Point Namensauflösung:** Neuer Template-Sensor `Verbundener Access Point`, der bekannte AP-BSSIDs auf benutzerfreundliche Namen auflöst (z. B. "🏠 UG", "🏠 EG", "🏠 DG"). Unbekannte APs werden mit ihrer MAC-Adresse und einem ❓-Prefix angezeigt, nicht verbundene Zustände mit ⚠️ abgefangen.
- **WLAN Signalqualität (%):** Neuer `copy`-Sensor, der den RSSI-Wert (dBm) linear in eine intuitive Prozent-Skala (0–100 %) umrechnet. Ideal für Dashboards und Automations-Trigger in Home Assistant.
- **Restart-Button:** Hinzufügen eines `button`-Elements (`platform: restart`) zur direkten Auslösung eines Neustarts über die Home Assistant UI, ohne OTA oder physischen Zugang.
- **Safe Mode Button:** Zusätzlicher Button (`platform: safe_mode`) für einen Neustart in den abgesicherten Modus. Ermöglicht OTA-Updates auch bei fehlerhafter Firmware, die das normale Booten verhindert.
- **Kategorisierte Sortierung:** Einführung eines Nummern-Prefix-Systems (2.x–6.x) für alle Entitäten, das eine thematische Gruppierung auf der Home Assistant Geräteseite erzwingt. Kategorie 1.x ist für projektspezifische lokale Sensoren reserviert. Reihenfolge: 2.x WLAN, 3.x Netzwerk-IDs, 4.x System, 5.x Versionen, 6.x Steuerung.
- **Explizite Icons:** Alle Sensoren haben jetzt ein definiertes MDI-Icon zugewiesen, um das generische "Auge"-Standardicon zu eliminieren (`mdi:ip`, `mdi:identifier`, `mdi:access-point`, `mdi:access-point-network`, `mdi:wifi-check`, `mdi:wifi-arrow-up-down`, `mdi:memory`, `mdi:timer-sand`, `mdi:alert-circle-outline`, `mdi:package-variant`).

### Geändert
- **Laufzeit-Einheit:** Umstellung der Uptime-Anzeige von Minuten auf Stunden (`unit_of_measurement: "h"`, `accuracy_decimals: 2`) für bessere Lesbarkeit bei langlebigen Geräten.
- **BSSID-Sensor auf `internal`:** Der rohe BSSID-Sensor (`wifi_info > bssid`) ist jetzt als `internal: true` markiert und wird nicht mehr als eigenständige Entität in Home Assistant exponiert. Er dient nur noch als Datenquelle für den neuen AP-Namens-Sensor.
- **Sensor-Benennung:** Alle Entitäten tragen jetzt ein numerisches Prefix (z. B. "2.1 WLAN Status") zur Steuerung der Anzeigereihenfolge.
- **WLAN Status:** An Position 2.1 verschoben (Ampel als erstes in der Gruppe). Icon geändert auf `mdi:wifi-check`.
- **WLAN Signalpegel & Signalqualität:** Icon geändert auf `mdi:wifi-arrow-up-down`.
- **SSID-Icon:** Geändert von Standard auf `mdi:access-point` für konsistentere Darstellung in der WLAN-Gruppe.
- **AP-Sensor-Icon:** Geändert von `mdi:access-point` auf `mdi:access-point-network` zur Unterscheidung vom SSID-Sensor.
- **Nummerierung:** Umstellung auf nullbasierte Nummerierung innerhalb jeder Kategorie (z. B. 2.0, 2.1, 2.2 statt 2.1, 2.2, 2.3). Die Ampel-/Status-Sensoren stehen jeweils an Position x.0 als Übersichtseintrag der Gruppe.

### Entfernt
- **Entität "Verbundener AP (MAC)":** Wird durch den neuen, aussagekräftigeren Sensor `Verbundener Access Point` ersetzt. Die Rohdaten bleiben intern verfügbar.

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