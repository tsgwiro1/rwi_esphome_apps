# Changelog - ha-weather-station

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [2.0.0] - 2026-08-29

### Achtung beim Update

**Trigger point Rain** und **Rain trigger hysteresis** entfallen. Die ESPHome-Integration entfernt sie beim ersten Reconnect selbst aus der Entitätenregistry, von Hand ist nichts aufzuräumen. Die neuen Regler starten so, dass das Erkennungsverhalten unverändert bleibt - keine Nachjustierung nötig. Automatisierungen und Dashboards, die die alten Entitäten ansprechen, müssen dagegen auf `Rain Threshold Wet` bzw. `Rain Threshold Dry` umgestellt werden.

### Hinzugefügt

* **`Regen kürzlich`** (`device_class: moisture`) neben `Regen Shed`, mit der neuen Haltezeit **Rain Hold Time** (Default 45 min). `Regen Shed` beantwortet «ist der Sensor jetzt nass?», `Regen kürzlich` «hat es in den letzten Minuten geregnet?». Grund: Der beheizte Sensor trocknet zwischen zwei Schauern in Minuten ab, ein Regenereignis zerfällt dadurch in mehrere Meldungen. An zwei Regentagen nachgemessen und mit Schwellen oder einem längeren *Rain Off Delay* nicht behebbar.

### Geändert

* **`Trigger point Rain` und `Rain trigger hysteresis` ersetzt durch `Rain Threshold Wet` und `Rain Threshold Dry`** - zwei unabhängige Anteile der Trockenfrequenz. Bisher hing die Ausschaltschwelle über die Hysterese am Einschaltpunkt: Wer empfindlicher stellte, schob sie mit nach oben, bis sie über der Trockenfrequenz lag und das Gerät nie mehr auf «trocken» zurückgekommen wäre. Diese Kopplung hat die Empfindlichkeit blockiert. Nebeneffekt: Auch die Ausschaltschwelle folgt nun dem Temperaturgang, der die Trockenfrequenz über den Tag verschiebt.
* **Startwerte 0.926 und 0.954** bilden die bewährte Einstellung 0.94/0.03 nach; die Abweichung liegt weit unter dem Rauschen.
* **Mindestabstand der Schwellen** (`wet_band_min`, 0.01). Liegt `Rain Threshold Dry` näher an `Rain Threshold Wet` oder darunter, hebt die Firmware ihn an und warnt im Log - ohne Band gäbe es keine Hysterese mehr.

Keine Änderung an der Heizungsregelung, der Selbstkalibrierung oder den Melderaten. Getestet mit ESPHome 2026.7.4 (RAM 28.4 %, Flash 54.5 %), per OTA geflasht und im Betrieb geprüft.

## [1.1.0] - 2026-08-29

### Hinzugefügt

* **`1.5 Heizung Störung`** (`device_class: problem`) - meldet einen unplausiblen NTC-Wert oder eine Übertemperatur. Ohne diese Entität wäre der neue Failsafe unsichtbar: die Heizung ginge still aus und niemand erführe warum.
* **Übertemperatur-Abschaltung bei 60 °C** (`heater_cutout_temp`). Das Kunststoffteil, in dem der Sensor sitzt, verträgt nicht mehr; die Heizleistung auf dem Keramiksubstrat reicht im Normalfall ohnehin nicht so weit. Wird der Wert dennoch erreicht, stimmt etwas nicht und der Regler bleibt auf `OFF`.

### Behoben

* **Ein defekter NTC liess die Heizung dauerhaft mit voller Leistung laufen.** Der bisherige Failsafe prüfte nur die Sollwertquelle (Taupunkt bzw. Umgebungstemperatur) auf `NaN`, nicht den Istwert. Die Fehlerfälle des Fühlers liefern aber keinen `NaN`, sondern eine plausibel aussehende Zahl: sowohl bei Kurzschluss (über `log(0)`) als auch bei offener Leitung (über den sehr grossen Widerstand) landet die Rechnung bei rund −273 °C - **beide laufen also nach unten**. `PIDClimate::update_pid_()` schaltet nur bei `NaN` ab und bildet sonst aus dem riesigen Regelfehler dauerhaft 100 % Stellwert. Der Istwert wird jetzt gegen `ntc_min_plausible` (−30 °C) geprüft; darunter bleibt der Regler zwingend auf `OFF`.
* **Nach einem Neustart entfiel die Wartezeit vor der Selbstkalibrierung.** `time_since_dry` startete mit `0`, wodurch `millis() - time_since_dry` sofort grösser war als jeder eingestellte *Calibration delay*. Ein Reboot kurz nach dem Regen konnte den Sensor damit auf eine noch feuchte Frequenz kalibrieren lassen. Der Wert wird jetzt in `on_boot` auf `millis()` gesetzt.
* **Der Kalibrierstatus flatterte beim Aufheizen.** Die Bedingung «Sensor ist warm» verglich den auf 60 s gemittelten HA-Wert (`Weather Station Sensor Heater`) gegen einen frischen Sollwert. Ein einzelner Minutenmittelwert kippte die Aussage, worauf der Status für genau einen Schleifendurchlauf auf `Heizt auf` sprang - am 14. und 16.08.2026 mehrfach für je 10 s beobachtet. Verglichen wird jetzt der schnelle interne Istwert (2 s). Verschärft wurde das durch eine niedrig eingestellte *Heater Temperature Elevation*: bei 3 K Überhöhung liegt das 2-K-Band knapp unter dem Sollwert.
* **Ehrlicher Status statt `Heizt auf`,** wenn Soll- oder Istwert fehlen. Bisher fiel die Anzeige in beiden Fällen auf `Heizt auf` zurück, obwohl die Heizung zwangsweise **aus** war - `target_temp` ist dann `NaN` und jeder Vergleich dagegen falsch. Neu: `NTC unplausibel - Heizung aus`, `Übertemperatur - Heizung aus` und `Sensordaten fehlen - Heizung aus`.
* **Grenzwert `rain_stop` einheitlich.** Die Nässe-Erkennung verwendete `<`, die Statusermittlung `<=`; bei exakt `f == rain_stop` meldeten Logik und Status Verschiedenes.

### Geändert

* **Startwerte der Regenschwellen auf `Trigger point Rain: 0.94` und `Rain trigger hysteresis: 0.03`** (vorher 0.80 / 0.12). Die alte Kombination verlangte einen Frequenzeinbruch von 15.4 %, bevor Regen gemeldet wurde, und liess sich nicht entschärfen: `rain_stop` hängt am Trigger point, nicht an der Trockenfrequenz, und wandert ab Trigger point ≈ 0.94 bei Hysterese 0.12 **über** die Trockenfrequenz - das Gerät käme nie mehr auf «trocken» zurück. Die neuen Startwerte laufen seit dem 23.08.2026 im Betrieb: Einschaltschwelle bei 92.6 % statt 84.6 % der Trockenfrequenz, an zwei Regentagen (25. und 28.08.) ohne Fehlalarm, mit rund einer halben Stunde früherer Meldung beim Regenbeginn am 25.08. Die Werte lagen bisher nur im NVS; ein Neuaufbau hätte wieder in der Sackgasse begonnen.

* **Obergrenze von `Heater Max Temperature` von 100 auf 50 °C gesenkt.** Der einstellbare Sollwert muss unter der Übertemperatur-Abschaltung liegen, sonst löste ein regulär eingestellter Wert von z. B. 80 °C die Schutzabschaltung aus und würde als Störung gemeldet. 50 °C lässt 10 K Reserve und war ohnehin der Vorgabewert; für einen Sensor, der nur wenige Kelvin über dem Taupunkt gehalten wird, ist das reichlich.

Keine Änderung an Regelverhalten im Normalbetrieb, an der Hysteresemechanik oder an den Melderaten. Getestet mit ESPHome 2026.7.4 (`config` und `compile` fehlerfrei, RAM 28.3 %, Flash 54.5 %).

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
