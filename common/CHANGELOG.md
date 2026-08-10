# Changelog - Common Diagnostics

Alle wichtigen Änderungen an diesem gemeinsamen Diagnose-Paket werden in dieser Datei dokumentiert. Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/) und diese Versionierung folgt dem [Semantic Versioning](https://semver.org/lang/de/).

---

## [1.4.1] - 2026-08-10

### Behoben
- **`2.2 WLAN Signalqualität` erzeugt in Home Assistant keine Warnung mehr.** Der Sensor setzt jetzt ausdrücklich `device_class: ""`.

  Ursache: `2.2` ist ein `copy`-Sensor, und dessen `FINAL_VALIDATE_SCHEMA` enthält `inherit_property_from(CONF_DEVICE_CLASS, CONF_SOURCE_ID)` — er erbt die `device_class` von der Quelle. Quelle ist `raw_wifi_signal` der Plattform `wifi_signal`, die `device_class=DEVICE_CLASS_SIGNAL_STRENGTH` fest vorgibt. Die Konfiguration überschrieb zwar `unit_of_measurement` auf `%`, die `device_class` aber nicht. Home Assistant lässt zu `signal_strength` nur `dBm` und `dB` zu und protokollierte deshalb bei jedem Start pro Gerät eine Warnung:

  > `Entity sensor.<gerät>_2_2_wlan_signalqualitat … is using native unit of measurement '%' which is not a valid unit for the device class ('signal_strength'); expected one of ['dBm', 'dB']`

  Das blosse Weglassen von `device_class` half nicht — die Eigenschaft stand gar nicht in der Datei, sie wurde geerbt. Nötig war das ausdrückliche Setzen auf den Leerwert; `DEVICE_CLASS_EMPTY = ""` ist in ESPHomes `DEVICE_CLASSES` enthalten, und `inherit_property_from` erbt nicht, wenn die Eigenschaft bereits gesetzt ist.

  Nachgewiesen an `ha-irrigation` als Testgerät: Nach dem Flashen fehlt `device_class` in den Entitätsattributen, `unit_of_measurement: "%"` und `state_class: measurement` bleiben erhalten (die Langzeitstatistik läuft also ungebrochen weiter), und der Wert stimmt weiterhin exakt mit der Umrechnung aus `2.1` überein. Beim anschliessenden Home-Assistant-Neustart erschienen statt sieben nur noch sechs Warnungen — die des Testgeräts blieb aus.

### Nicht geändert
- `2.1 WLAN Signalpegel` behält `device_class: signal_strength` mit `dBm`. Dort ist die Kombination korrekt.

---

## [1.4.0] - 2026-07-30

### Behoben
- **Kein falsches „🔴 Kritisch" mehr nach einem Neustart.** `2.0 WLAN Status` und `4.0 System Gesundheit` fangen den Startwert `NAN` jetzt mit `std::isnan()` ab und melden stattdessen **„⚪ Startet"**, bis der jeweilige Quellsensor seine erste Messung geliefert hat.

  Ursache: Ein ESPHome-Sensor beginnt mit `Sensor::Sensor() : state(NAN), raw_state(NAN)` (`sensor/sensor.cpp:45`). Die Quellsensoren `2.1 WLAN Signalpegel` und `4.1 Freier Speicher` haben beide `polling_component_schema("60s")` und liefern ihren ersten Wert daher erst nach 60 Sekunden. Die Ampel-Lambdas verglichen diesen Startwert ungeprüft mit ihren Schwellen — und in C++ ist **jeder** `>`-Vergleich gegen `NAN` falsch. Beide fielen dadurch in den `else`-Zweig und meldeten nach jedem Reboot oder OTA rund eine Minute lang „🔴 Kritisch", obwohl das Gerät einwandfrei lief.

  Praktische Folge: Die Werte waren nicht nur optisch irritierend, sondern hätten auch jede Home-Assistant-Automation oder Benachrichtigung, die auf diese beiden Ampeln reagiert, bei jedem Neustart fälschlich ausgelöst.

### Nicht geändert
- `2.4 Verbundener Access Point` steht nach dem Start weiterhin kurz auf „⚠️ Nicht verbunden", weil `raw_bssid` noch leer ist. Der Zustand ist inhaltlich korrekt — das Gerät *ist* in diesem Moment noch nicht verbunden — und lässt sich ohne zusätzliche Uptime-Prüfung nicht von einem echten Verbindungsabbruch unterscheiden. Bewusst so belassen.

---

## [1.3.0] - 2026-07-28

### Geändert
- **Interpretierende Text-Sensoren melden nur noch bei Wertänderung.** Betroffen sind `2.0 WLAN Status`, `2.4 Verbundener Access Point`, `4.0 System Gesundheit` und `5.1 Common Diagnostics Version`. ESPHome dedupliziert in `TextSensor::publish_state()` nicht — die dortige Prüfung spart nur die Heap-Allokation, `notify_frontend_()` wird trotzdem immer aufgerufen. Ein zyklisch pollender Template-Sensor schickte seinen Wert also auch dann erneut, wenn sich nichts geändert hatte. Umgesetzt über einen Lambda-Filter, der die Filterkette bei unverändertem Wert abbricht (`LambdaFilter::new_value` liefert `false`, `internal_send_state_to_frontend` wird nicht erreicht).

  Einsparung pro Gerät: rund **7'200 Meldungen pro Tag** (2.4 im 30-s-Takt: 2'880; die drei übrigen im 60-s-Takt: je 1'440). Besonders `5.1` ist eine zur Compilezeit eingesetzte Konstante, die bisher 1'440-mal täglich unverändert gemeldet wurde und jetzt genau einmal meldet.

  **Wo die Einsparung wirkt:** bei der API-Verbindung zwischen Gerät und Home Assistant, beim Event-Bus von Home Assistant und bei der Rechenzeit auf dem ESP. **Nicht** in der Datenbank — siehe Nachtrag.

  > **Nachtrag vom 2026-07-29 (Korrektur):** Die ursprüngliche Fassung dieses Eintrags behauptete, die wiederholten Meldungen erzeugten in Home Assistant Datenbankzeilen. Das ist falsch. Home Assistant dedupliziert bereits selbst: Wird eine Entität mit unverändertem Status **und** unveränderten Attributen neu gemeldet, feuert nur `STATE_REPORTED` statt `STATE_CHANGED`, und der Recorder schreibt nichts.
  >
  > Nachgemessen über 24 Stunden mit `ha-flowmeter` und `wp-solar-monitor` als Kontrollgruppe (beide noch auf V1.2.1, also ohne Deduplizierung) gegen `ha-weather-station` und `ha-irrigation` (V1.3.0): Für `5.1`, `2.4` und `4.0` schrieben **alle** Geräte exakt 3 Zeilen pro Tag — mit und ohne Filter identisch. Die Änderung spart also Netzwerk- und Event-Bus-Last, aber keine Datenbankzeilen.

  Unbedenklich für Home Assistant: ESPHome schickt jedem sich verbindenden Client über den `INITIAL_STATE`-Iterator ohnehin den aktuellen Stand aller Entitäten. Nach einem HA-Neustart sind die Werte also sofort wieder da, ohne auf die nächste Wertänderung warten zu müssen.

### Nicht geändert
- Die numerischen Sensoren (`2.1 WLAN Signalpegel`, `2.2 WLAN Signalqualität`, `4.1 Freier Speicher`, `4.2 Laufzeit`) behalten ihren 60-s-Takt. Das sind echte, sich laufend ändernde Messwerte — hier würde Deduplizierung nur Auflösung im Verlauf kosten.
- `2.3 Verbundene SSID`, `3.0 IP Adresse`, `3.1 Geräte MAC` (`wifi_info`), `4.3 Letzter Neustart Grund` und `5.0 ESPHome Version` publizieren bereits von sich aus nur bei Änderung — nachgemessen über ein 120-s-Fenster, in dem sie ausschliesslich im Initial-Burst auftauchten.

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