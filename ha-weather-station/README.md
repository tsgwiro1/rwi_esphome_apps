# ha-weather-station - Wetterstation mit beheiztem Regensensor

![Version](https://img.shields.io/badge/version-1.0.1-blue)
[![ESPHome](https://img.shields.io/badge/ESPHome-Ready-03a9f4?logo=esphome&logoColor=white)](https://esphome.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Dieses ESPHome-Projekt misst Temperatur, Luftfeuchte, Luftdruck und Taupunkt und erkennt Niederschlag über einen frequenzbasierten Regensensor. Der Regensensor wird von einem nativen PID-Regler beheizt, damit er nach dem Regen zuverlässig abtrocknet und nicht betaut. Die Trockenfrequenz des Sensors wird im Betrieb laufend selbst nachkalibriert, sodass Alterung und Verschmutzung die Erkennungsschwelle nicht verschieben.

---

## Haftungsausschluss (Disclaimer)

⚠️ **WICHTIGER HINWEIS: VERWENDUNG AUF EIGENE GEFAHR!** ⚠️

Dieses Projekt beschreibt ein privates Bastelprojekt zur Optimierung der eigenen Hausautomatisierung. Die Nutzung, der Nachbau sowie das Einspielen des bereitgestellten Codes und der Konfigurationen erfolgen ausdrücklich auf **eigene Gefahr und eigenes Risiko**.

Der Autor übernimmt **keinerlei Haftung, Gewährleistung oder Verantwortung** für:
* **Schäden jeglicher Art** an den Sensoren, der Elektronik oder anderen Komponenten der Haustechnik.
* **Folgeschäden** durch Fehlfunktionen oder Fehlmessungen (z. B. eine Bewässerung, die trotz Regen startet, oder eine dauerhaft bestromte Sensorheizung).
* **Überhitzung der Sensorheizung**: Der PID-Regler steuert ein Heizelement. Bei falscher Verdrahtung, defektem NTC oder invertierter Treiberstufe kann die Heizung mit voller Leistung laufen. Aufbau und Verdrahtung sind vor dem Dauerbetrieb zu prüfen und thermisch abzusichern.
* Die Richtigkeit, Aktualität oder Vollständigkeit des bereitgestellten Codes oder der Dokumentation.

Mit der Verwendung dieses Codes oder Nachbau der Hardware erklärst du dich damit einverstanden, auf jegliche Schadensersatzansprüche gegenüber dem Autor zu verzichten.

---

## 1. Funktionsprinzip

* **Messwerte:** Temperatur (AM2315), Luftfeuchte (SHT31) und Luftdruck (BMP280) werden über einen gemeinsamen I²C-Bus erfasst. Der Taupunkt wird nach der Magnus-Formel aus AM2315-Temperatur und SHT31-Feuchte berechnet.
* **Regenerkennung:** Der Regensensor liefert eine Frequenz, die mit zunehmender Nässe **sinkt**. Erkannt wird nicht gegen einen festen Absolutwert, sondern gegen die gelernte Trockenfrequenz des Sensors.
* **Beheizter Sensor:** Ein nativer ESPHome-PID-Regler hält den Regensensor über einem einstellbaren Sollwert (wahlweise Taupunkt oder Umgebungstemperatur, plus Überhöhung). So trocknet er nach Regen ab und beschlägt in feuchten Nächten nicht.
* **Selbstkalibrierung:** Die Trockenfrequenz wird nur unter kontrollierten Bedingungen nachgeführt (siehe Abschnitt 2). Dadurch bleibt die Auslöseschwelle über die Lebensdauer des Sensors stabil.
* **Anti-Kondensation am SHT31:** Übersteigt die Luftfeuchte 98 %, startet ein Heizzyklus über den internen Heizer des SHT31. Während des Zyklus werden die Messwerte verworfen, damit die aufgeheizten (und damit falschen) Feuchtewerte nicht in Home Assistant landen.
* **Lokale Autonomie:** Regenerkennung, Heizungsregelung und Kalibrierung laufen vollständig auf dem ESP32. Ein WLAN- oder HA-Ausfall unterbricht die Logik nicht, er wird nur über die Status-LED und die Diagnose gemeldet.

---

## 2. Regenerkennung & Selbstkalibrierung

### Schwellen mit Hysterese

Die Auslöseschwelle wird bei jedem Durchlauf relativ zur gelernten Trockenfrequenz `freq_dry` gebildet:

```
trigger_point = freq_dry × Trigger point Rain      (Default 0.80, also 80 % der Trockenfrequenz)
hyst          = trigger_point × Rain trigger hysteresis ÷ 2
rain_start    = trigger_point − hyst               (Einschaltschwelle)
rain_stop     = trigger_point + hyst               (Ausschaltschwelle)
```

* **Regen EIN:** Sobald die Frequenz unter `rain_start` fällt, wird sofort auf «Regen» geschaltet - ohne Verzögerung, damit z. B. eine Bewässerung rechtzeitig abbricht.
* **Regen AUS:** Erst wenn die Frequenz für die volle Dauer von **Rain Off Delay** (Default 3 min) über `rain_stop` bleibt. Jeder Messwert im Nassbereich setzt diesen Timer zurück. Das verhindert Flattern bei Nieselregen und während des Abtrocknens.

### Wann kalibriert wird

Die Trockenfrequenz wird als gleitender Mittelwert nachgeführt (`freq_dry = (15 × freq_dry + f) ÷ 16`), aber **nur** wenn alle Bedingungen gleichzeitig erfüllt sind:

1. Es regnet aktuell nicht.
2. Die Frequenz liegt über `rain_stop` (Sensor gilt als trocken).
3. Der Sensor ist aufgeheizt (Isttemperatur ≥ Zieltemperatur − 2 K).
4. Seit dem Trockenwerden ist **Calibration delay** (Default 30 min) vergangen.
5. Die Abweichung zur bisherigen Trockenfrequenz liegt innerhalb von **Range for Calibration** (Default 4 %).

Welche Bedingung gerade blockiert, ist im Klartext an der Diagnose-Entität `1.1 Dry Frequency Calibration Status` ablesbar: `Regen aktiv`, `Sensor noch zu nass`, `Heizt auf`, `Wartet auf Delay`, `Frequenz-Drift zu hoch` oder `Kalibriert`. Beim Start steht dort `Warte auf Sensorwerte`, bis der Frequenzzähler gültige Werte liefert.

Die Begrenzung über *Range for Calibration* ist bewusst eng gewählt: Sie verhindert, dass ein schleichend nasser oder defekter Sensor seine eigene Referenz mitzieht und die Regenerkennung dadurch blind wird.

### Heizungssollwert

```
Ziel = (Taupunkt ODER Umgebungstemperatur) + Heater Temperature Elevation
Ziel = clamp(Ziel, Heater Min Temperature, Heater Max Temperature)
```

Die Quelle ist über **Heater Source** umschaltbar. `Dew Point` (Default) hält den Sensor gezielt über dem Taupunkt und ist die energiesparendere Variante; `Ambient` bezieht sich auf die Umgebungstemperatur.

**Failsafe:** Liefern die Sensoren keine gültigen Werte (`NaN`, z. B. direkt nach dem Booten), wird der PID-Regler zwingend auf `OFF` gesetzt, statt auf einen undefinierten Sollwert zu regeln.

---

## 3. Hardware & Pinout (ESP32 DevKit)

Das Projekt läuft auf einem ESP32 (`esp32dev`) unter dem ESP-IDF-Framework.

| Peripherie / Funktion | GPIO | Beschreibung / Besonderheit |
| :--- | :---: | :--- |
| **I²C SDA** | `GPIO21` | Gemeinsamer Bus für AM2315, SHT31 und BMP280 |
| **I²C SCL** | `GPIO22` | Bus-Scan beim Start aktiviert |
| **Regensensor (Frequenz)** | `GPIO32` | `pulse_counter`, 1 s Messfenster, Glitch-Filter 2 µs |
| **NTC Sensorheizung** | `GPIO36` | ADC (12 dB), Spannungsteiler mit 680 Ω gegen GND |
| **Heizung PWM** | `GPIO27` | LEDC, 2 kHz, **invertiert** (siehe Hinweis unten) |
| **Status-LED rot** | `GPIO16` | invertiert |
| **Status-LED grün** | `GPIO17` | invertiert |
| **Status-LED blau** | `GPIO18` | invertiert |
| **Activity-LED** | `GPIO15` | invertiert, blitzt 50 ms im 10-s-Takt |

**I²C-Adressen:** SHT31 `0x44`, BMP280 `0x76`, AM2315 `0x5C` (über die `am2320`-Plattform, protokollkompatibel).

**NTC-Kette:** Die Temperatur der Sensorheizung wird in vier Stufen berechnet - ADC-Rohspannung → `resistance` (680 Ω, DOWNSTREAM) → `ntc` (B = 3750, 1 kΩ @ 25 °C) → Glättung über 10 Messwerte. Der schnelle interne Wert (100 ms) speist den PID-Regler, an Home Assistant geht ein auf 10 s gemittelter Wert. *Sinkt die angezeigte Temperatur, wenn der NTC erwärmt wird, muss `configuration` auf `UPSTREAM` gestellt werden.*

**Hinweis zum invertierten PWM:** Der Heizungsausgang ist mit `inverted: true` konfiguriert. ESPHome rechnet dabei intern `Duty = 1 − Stellwert`, d. h. der PID-Modus `OFF` erzeugt **100 % Tastverhältnis** am Pin. Das ist korrekt für eine low-aktive Treiberstufe - bei einem high-aktiven Treiber würde die Heizung stattdessen bei jedem Abschalten volle Leistung ziehen. Vor dem Dauerbetrieb gegen den Schaltplan prüfen.

**Hinweis zu GPIO15:** Der Pin ist beim ESP32 ein Strapping-Pin (MTDO, interner Pull-Up) und beeinflusst die Boot-Log-Ausgabe. Als Activity-LED funktioniert er in dieser Schaltung, `esphome config` gibt dazu aber eine Warnung aus.

---

## 4. Status-LEDs

Die RGB-LED zeigt im 2-Sekunden-Takt den Verbindungszustand:

| Farbe | Bedeutung |
| :--- | :--- |
| 🟢 **Grün** | API-Verbindung zu Home Assistant steht |
| 🔵 **Blau** | WLAN verbunden, aber keine API-Verbindung |
| 🔴 **Rot** | Kein WLAN |

Die separate Activity-LED blitzt bei jedem Durchlauf der Hauptlogik (alle 10 s) für 50 ms und zeigt so, dass die Regelschleife lebt.

---

## 5. Home Assistant Integration

### Konfiguration (Bedienbar in HA)

Alle Werte sind als Eingabefeld (`mode: box`) ausgeführt, in der Kategorie *Konfiguration* gruppiert und überstehen einen Neustart.

| Entität | Bereich | Default | Bedeutung |
| :--- | :---: | :---: | :--- |
| **Heater Source** | Dew Point / Ambient | Dew Point | Bezugsgrösse für den Heizungssollwert |
| **Heater Temperature Elevation** | 0…50 K | 10 | Überhöhung über die Bezugsgrösse |
| **Heater Min Temperature** | 0…100 °C | 10 | Untere Klemmung des Sollwerts |
| **Heater Max Temperature** | 0…100 °C | 50 | Obere Klemmung des Sollwerts |
| **Trigger point Rain** | 0.1…1.0 | 0.80 | Auslöseschwelle als Anteil der Trockenfrequenz |
| **Rain trigger hysteresis** | 0.01…0.5 | 0.12 | Breite des Hysteresebands |
| **Rain Off Delay [min]** | 0…60 | 3 | Trockenzeit, bis «Regen» zurückgesetzt wird |
| **Calibration delay [min]** | 1…120 | 30 | Wartezeit nach dem Trockenwerden bis zur Kalibrierung |
| **Range for Calibration** | 0.01…0.2 | 0.04 | Maximal zulässige Drift für eine Kalibrierung |
| **SHT Heater Time [min]** | 1…30 | 5 | Heizdauer des SHT31-Defog-Zyklus |
| **SHT Recovery Time [min]** | 1…30 | 3 | Abkühlzeit, in der keine Werte publiziert werden |
| **Barometer Elevation Correction** | −200…200 hPa | 0.0 | Höhenkorrektur des Luftdrucks |

### Messwerte (Read-Only in HA)

* **Temperature Shed (`sensor.temperature_shed`):** Umgebungstemperatur vom AM2315.
* **Humidity Shed (`sensor.humidity_shed`):** Relative Luftfeuchte vom SHT31. Während eines Defog-Zyklus werden keine Werte publiziert, HA hält den letzten Stand.
* **Barometic Pressure Shed (`sensor.barometic_pressure_shed`):** Luftdruck vom BMP280 inkl. Höhenkorrektur.
* **Dew Point Shed (`sensor.dew_point_shed`):** Berechneter Taupunkt (Magnus-Formel).
* **Regen Shed (`binary_sensor.raining`):** Niederschlagserkennung, `device_class: moisture`.
* **Weather Station Frequency (`sensor.weather_station_frequency`):** Aktuelle Sensorfrequenz, sekündlich gemessen und über 60 s gemittelt.
* **Weather Station Sensor Heater (`sensor.weather_station_sensor_heater`):** Isttemperatur der Sensorheizung, über 60 s gemittelt.
* **Rain Sensor Heater PID (`climate.ha_weather_station_rain_sensor_heater_pid`):** Der PID-Regler als Climate-Entität, inkl. Soll-/Isttemperatur und Betriebszustand.

> **Hinweis zu Namen und IDs:** Die hier genannten Bezeichnungen sind die Namen aus der Firmware. In der bestehenden Home-Assistant-Instanz sind mehrere Entitäten manuell umbenannt (`Humidity Shed` → «Outdoor Humidity», `Weather Station Frequency` → «Sensor Frequency», `Weather Station Sensor Heater` → «Temperature Rainsensor», `Regen Shed` → «Raining»). Solche Umbenennungen liegen in der HA-Registry und werden von Firmware-Updates nicht überschrieben. Auch die Entity-IDs hängen vom Registrierungszeitpunkt ab - ältere Entitäten tragen keinen Gerätepräfix, später hinzugekommene (u. a. alle Diagnose-Entitäten) dagegen schon. Bei einer Neuinstallation ergeben sich daher andere IDs.

### Diagnose (Read-Only in HA)

Die Kategorie 1.x ist projektlokal, 2.x bis 6.x kommen aus `common/diagnostics.yaml`.

* **1.0 Weather Station Dry Frequency:** Aktuell gelernte Trockenfrequenz - die Referenz der gesamten Regenerkennung.
* **1.1 Dry Frequency Calibration Status:** Klartext-Grund, warum gerade (nicht) kalibriert wird.
* **1.2 Dry Frequency Calibration Active:** EIN, solange die Trockenfrequenz nachgeführt wird.
* **1.3 SHT Defog Status:** `Normalbetrieb`, `Heizt (Kondensationsschutz)` oder `Abkühlphase`.
* **1.4 SHT Defog Cycle Active:** EIN während des gesamten Defog-Zyklus (Heiz- **und** Abkühlphase).

---

## 6. Inbetriebnahme & Webserver

Das Gerät verfügt über einen integrierten **Webserver** auf Port 80. Falls Home Assistant einmal ausfallen sollte, lassen sich Messwerte, PID-Regler und alle Konfigurationsfelder über die IP-Adresse des Geräts in jedem Webbrowser einsehen und bedienen.

Benötigte Secrets: `weatherstation_api_key`, `weatherstation_ota_key`, `weatherstation_fallback_ap_ssid`, `weatherstation_fallback_ap_password` sowie `wifi_ssid`/`wifi_password`. Das eingebundene Diagnose-Paket benötigt zusätzlich `mac_bssid_ug`, `mac_bssid_eg` und `mac_bssid_dg`.

Nach dem ersten Start sollte die Trockenfrequenz beobachtet werden: `1.0 Weather Station Dry Frequency` startet beim Vorgabewert von 32 000 Hz und läuft erst dann auf den tatsächlichen Wert des verbauten Sensors ein, wenn die Kalibrierbedingungen erfüllt sind. Weicht der reale Trockenwert stark von 32 000 Hz ab, blockiert *Range for Calibration* das Einlaufen - in dem Fall den Bereich einmalig aufweiten, bis der Wert passt, und danach wieder eng stellen.

---

## 7. Datenrate gegenüber Home Assistant

Die Entitäten sind bewusst darauf ausgelegt, wenig zu senden. Die Regelung läuft davon unabhängig, sie ist nicht an die Publiziererate gekoppelt.

> **Wichtig zur Einordnung:** Eine Meldung ist nicht automatisch eine Datenbankzeile. Home Assistant schreibt nur, wenn sich Status **oder** Attribute tatsächlich ändern; eine identische Wiederholung feuert bloss `STATE_REPORTED` und wird vom Recorder verworfen. Die Kadenzen unten senken deshalb zuverlässig **Netzwerk- und Event-Bus-Last** — Datenbankzeilen sparen sie nur dort, wo sich der Wert real bei jeder Meldung ändert. Das ist bei den Messwerten mit vielen Nachkommastellen der Fall und war es vor allem bei der Climate-Entität, deren `current_temperature` als Attribut ständig mitlief.

| Entität | Kadenz | Meldungen/Tag |
| :--- | :--- | ---: |
| `climate` Rain Sensor Heater PID | ≤ alle 2 s (an die PID-Rechenrate gekoppelt) | ~43'000 |
| Temperatur, Feuchte, Luftdruck, Taupunkt | 60 s | je 1'440 |
| Sensor Frequency, Temperature Rainsensor | 60 s (Mittelwert) | je 1'440 |
| 1.0 Dry Frequency | 300 s | 288 |
| 1.1 Calibration Status, 1.2 Calibration Active | nur bei Änderung | wenige |
| Regen Shed, 1.4 SHT Defog Cycle Active | nur bei Flankenwechsel | wenige |

Drei Entwurfsentscheidungen dahinter:

* **Der PID-Regler bestimmt seine eigene Meldungsrate.** ESPHomes `PIDClimate` publiziert bei jeder Änderung der Isttemperatur, und der Regler rechnet genau dann, wenn sein Eingangssensor einen Wert liefert. `send_every` an `heater_temp_fast` steuert deshalb beides zugleich. Der ADC tastet weiterhin mit 10 Hz ab, publiziert aber nur alle 2 s einen Mittelwert - bei einer Aufheizrate von rund 0.1 K/s bewegt sich die Temperatur zwischen zwei Abtastungen um 0.2 K, für eine träge Heizung völlig ausreichend.
* **Der PID wird nur bei echter Änderung angefasst.** Jeder `ClimateCall::perform()` löst intern ein `publish_state()` **und** ein `save_state_()` ins NVS aus. Die Hauptschleife setzt Modus und Sollwert daher nur noch, wenn der Modus wechselt oder sich der Sollwert um mindestens 0.1 K verschiebt.
* **Statusmeldungen werden entprellt.** `BinarySensor::publish_state` und `TextSensor::publish_state` senden in ESPHome ohne Vergleich mit dem Vorwert. Kalibrierstatus, Regenstatus und Defog-Status führen deshalb in der Firmware selbst Buch und melden nur Änderungen.

Nicht angefasst ist das gemeinsame `common/diagnostics.yaml` (Kategorien 2.x bis 6.x, zusammen rund 12'000 Meldungen/Tag), weil es von allen Projekten geteilt wird. Wer dort sparen will, sollte es projektübergreifend entscheiden.

---

## 8. Bekannte Punkte

* **SHT31-Defog ohne Begrenzung:** Bei anhaltendem Nebel triggert der Zyklus unmittelbar neu, was auf ca. 62 % Einschaltdauer des internen Sensorheizers führt. Der Heizer ist laut Datenblatt nicht für Dauerbetrieb vorgesehen; ein Zykluszähler oder eine Mindestpause wäre sinnvoll. Vor einer Änderung lohnt ein Blick in den Verlauf von `1.4 SHT Defog Cycle Active` - tritt der Fall selten auf, ist der Aufwand nicht gerechtfertigt.
* **Schreibweise `Barometic`** statt `Barometric` im Entitätsnamen. Eine Korrektur ändert die Entity-ID in Home Assistant und kostet den bisherigen Verlauf, ist deshalb kein reiner Kosmetik-Fix.
* **Climate-Entität als grösster verbleibender Sender:** Wer die ~43'000 Meldungen/Tag auch noch loswerden will, kann `climate` auf `internal: true` setzen. Funktional kostet das nichts - die Hauptschleife überschreibt jede manuelle Änderung ohnehin innerhalb von 10 s -, man verliert aber die Sicht auf Soll-/Isttemperatur und Reglerzustand in HA. Alternativ lässt sich die Entität in HAs `recorder` ausschliessen, dann bleibt sie sichtbar, landet aber nicht mehr in der Datenbank.
