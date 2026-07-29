# Changelog - ha-weather-station

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.0.1] - 2026-07-28

### Geändert

* **Datenrate gegenüber Home Assistant um rund 90 % gesenkt.** Am laufenden Gerät gemessen: 224 der 236 wiederkehrenden Meldungen in 30 s (96 %) stammten von der Climate-Entität - hochgerechnet rund 645'000 Meldungen pro Tag, die in HA jeweils eine neue `states`- plus `state_attributes`-Zeile erzeugten, weil `current_temperature` als Attribut ständig wechselt.
  * `heater_temp_fast` publiziert über `sliding_window_moving_average` (Fenster 20, `send_every: 20`) nur noch alle 2 s statt 10-mal pro Sekunde. Da `PIDClimate` an diesem Sensor-Callback hängt, senkt das zugleich Rechen- und Meldungsrate des Reglers. Der ADC tastet unverändert mit 10 Hz ab, die Mittelung wird dadurch sogar besser.
  * Der PID-Regler wird von der Hauptschleife nur noch angefasst, wenn der Modus wechselt oder sich der Sollwert um ≥ 0.1 K ändert - vorher bei jedem 10-s-Durchlauf.
  * `Weather Station Frequency` und `Weather Station Sensor Heater` mitteln jetzt über 60 s statt 10 s, `1.0 Weather Station Dry Frequency` meldet alle 300 s statt 60 s.
  * Kalibrierstatus und -Flag werden nur noch bei Wertänderung publiziert (vorher alle 10 s identisch).
  * `Regen Shed` und `1.4 SHT Defog Cycle Active` sind von zyklischem Polling auf ereignisgesteuertes Publizieren umgestellt.
* **Reaktionszeit der Regenerkennung in HA verbessert:** von bis zu 60 s (Polling-Intervall des Binärsensors) auf maximal 10 s (Flanke wird direkt aus der Logikschleife gemeldet).
* **Flash-Verschleiss reduziert:** `flash_write_interval` von 1 min auf 10 min. Zusammen mit dem selteneren PID-Aufruf entfallen die bisherigen rund 525'000 NVS-Schreibvorgänge pro Jahr weitgehend.
* **`state_class: measurement`** ergänzt bei Luftfeuchte, Luftdruck, Taupunkt, beiden Frequenz-Sensoren und der Heizungstemperatur. Home Assistant führt für diese Werte damit Langzeitstatistik.

### Behoben

* Driftberechnung der Kalibrierung nutzt `fabsf()` statt `abs()`. Das bisherige Verhalten war korrekt (der Compiler löste nachweislich auf die Fliesskomma-Variante auf), hing aber an Header-Details.

Keine Änderung an Regelverhalten, Schwellenlogik oder Bedienung. Getestet mit ESPHome 2026.7.2 (`config` und `compile` fehlerfrei, RAM 27.9 %, Flash 54.4 %).

> **Nachtrag vom 2026-07-29 — nach 24 Stunden im Betrieb nachgemessen:**
>
> | Entität | vorher/Tag | jetzt/Tag |
> | :--- | ---: | ---: |
> | `climate` Rain Sensor Heater PID | ~645'000 | **0** (zusätzlich im `recorder` ausgeschlossen) |
> | `Weather Station Sensor Heater` | ~8'640 | **1'442** |
> | `Weather Station Frequency` | ~8'640 | **1'442** |
> | `1.0 Dry Frequency` | 1'440 | **288** |
>
> Zur Einordnung, welche Massnahmen tatsächlich Datenbankzeilen gespart haben: Die drei Punkte zur Melderate (`heater_temp_fast`, PID-Aufruf, 60-s-Mittelung) wirken voll, weil sich diese Werte bei jeder Meldung real ändern. Die Entprellung von **Kalibrierstatus, Regensensor und Defog-Flag** senkt dagegen nur Netzwerk- und Event-Bus-Last: Home Assistant verwirft identische Wiederholungen ohnehin, ohne eine Zeile zu schreiben. Die ursprüngliche Formulierung in Abschnitt 7 der README legte das Gegenteil nahe und ist korrigiert.
>
> Funktional bestätigt: Die Selbstkalibrierung arbeitet, der Status steht auf `Kalibriert` und die gelernte Trockenfrequenz ist im ersten Tag von 33'165 auf 32'587 Hz eingelaufen.

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
