# Changelog - ha-weather-station

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.0.0] - 2026-07-28

### Erstrelease

* **Messwerte:** Temperatur (AM2315 über die `am2320`-Plattform), Luftfeuchte (SHT31, `0x44`), Luftdruck (BMP280, `0x76`, mit einstellbarer Höhenkorrektur) und daraus berechneter Taupunkt (Magnus-Formel) auf einem gemeinsamen I²C-Bus (GPIO21/GPIO22).
* **Regenerkennung (GPIO32):** Frequenzbasierter Sensor über `pulse_counter` (1 s Fenster, 2 µs Glitch-Filter, exponentielle Glättung). Auslösung relativ zur gelernten Trockenfrequenz mit Hysterese - Regen schaltet sofort EIN, das Zurücksetzen auf «trocken» erfordert eine durchgehende Trockenphase (Default 3 min).
* **Selbstkalibrierung der Trockenfrequenz:** Gleitender Mittelwert (1/16-Gewichtung), der nur bei trockenem und aufgeheiztem Sensor, nach abgelaufener Wartezeit (Default 30 min) und innerhalb eines engen Driftfensters (Default 4 %) nachgeführt wird. Der jeweils blockierende Grund wird im Klartext als Diagnose-Entität publiziert.
* **PID-geregelte Sensorheizung (GPIO27):** Nativer ESPHome-PID-Regler (kp 0.157, ki 0.040, kd 0.039) auf LEDC-PWM mit 2 kHz. Sollwert wahlweise über Taupunkt oder Umgebungstemperatur plus Überhöhung, geklemmt zwischen Min- und Max-Temperatur. Failsafe: Bei ungültigen Sensorwerten (`NaN`) wird der Regler zwingend auf `OFF` gesetzt.
* **Temperaturmessung der Heizung (GPIO36):** Vierstufige NTC-Kette aus ADC → `resistance` (680 Ω) → `ntc` (B = 3750, 1 kΩ @ 25 °C) → Glättung. Schneller interner Wert (100 ms) für den Regler, 10-s-Mittelwert für Home Assistant.
* **Anti-Kondensations-Zyklus für den SHT31:** Ab 98 % Luftfeuchte wird der interne Sensorheizer per I²C-Kommando für eine einstellbare Zeit aktiviert; während Heiz- und Abkühlphase werden die Feuchtewerte verworfen, damit keine verfälschten Werte nach Home Assistant gelangen.
* **Status-LEDs:** RGB-LED (GPIO16/17/18) mit grün = API verbunden, blau = nur WLAN, rot = kein WLAN; separate Activity-LED (GPIO15), die den Durchlauf der Hauptlogik im 10-s-Takt anzeigt.
* **Bedienung:** Zwölf in Home Assistant einstellbare Konfigurationswerte (Heizungsquelle, Sollwertgrenzen, Regenschwellen, Kalibrierparameter, Defog-Zeiten, Luftdruckkorrektur), alle neustartfest; Webserver auf Port 80 für den Betrieb ohne HA.
* Gemeinsames Diagnose-Paket `common/diagnostics.yaml` (V1.2.1) eingebunden.
* Zugangsdaten (API-Key, OTA-Passwort, Fallback-AP) über `!secret` ausgelagert.

Getestet mit ESPHome 2026.7.2 (`esphome config` und `esphome compile` fehlerfrei, RAM 27.9 %, Flash 54.3 %).
