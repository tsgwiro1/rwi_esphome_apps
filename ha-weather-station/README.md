# ha-weather-station - Wetterstation mit beheiztem Regensensor

![Version](https://img.shields.io/badge/version-3.1.0-blue)
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

* **Messwerte:** Temperatur (AM2315), Luftfeuchte (SHT31) und Luftdruck (BMP280) werden über einen gemeinsamen I²C-Bus erfasst. Der Taupunkt wird nach der Magnus-Formel mit den Konstanten des Sensorherstellers aus Temperatur **und** Feuchte des SHT31 berechnet - beide Grössen aus demselben Chip, damit die relative Feuchte bei ihrer eigenen Messtemperatur ausgewertet wird.
* **Regenerkennung:** Der Regensensor liefert eine Frequenz, die mit zunehmender Nässe **sinkt**. Erkannt wird nicht gegen einen festen Absolutwert, sondern gegen die gelernte Trockenfrequenz des Sensors. Das Ergebnis wird in zwei Entitäten gemeldet: «ist der Sensor jetzt nass» und «hat es in den letzten Minuten geregnet» (siehe Abschnitt 2).
* **Beheizter Sensor:** Ein nativer ESPHome-PID-Regler hält den Regensensor über einem einstellbaren Sollwert (wahlweise Taupunkt oder Umgebungstemperatur, plus Überhöhung). So trocknet er nach Regen ab und beschlägt in feuchten Nächten nicht.
* **Selbstkalibrierung:** Die Trockenfrequenz wird nur unter kontrollierten Bedingungen nachgeführt (siehe Abschnitt 2). Dadurch bleibt die Auslöseschwelle über die Lebensdauer des Sensors stabil.
* **Wartungszyklus für den SHT31:** Alle **SHT Maintenance Interval** Tage (Default 7) läuft der interne Heizer des SHT31 für **SHT Heater Time** und treibt angelagerte Verunreinigungen aus. Sensirion nennt für diesen Heizer genau zwei Zwecke - Plausibilitätsprüfung und das Rückgängigmachen kontaminationsbedingter Drift -, beides wiederkehrende Wartung und kein Ereignis. Deshalb ein Zeitintervall und keine Feuchteschwelle. Während des Zyklus und für **SHT Recovery Time** danach werden die Messwerte verworfen; HA hält so lange den letzten Stand, statt die aufgeheizten und damit zu trockenen Werte zu übernehmen. Bei Regen wartet der Zyklus, weil der Heizungssollwert am Taupunkt und damit an der Feuchte hängt.
* **Lokale Autonomie:** Regenerkennung, Heizungsregelung und Kalibrierung laufen vollständig auf dem ESP32. Ein WLAN- oder HA-Ausfall unterbricht die Logik nicht, er wird nur über die Status-LED und die Diagnose gemeldet.

---

## 2. Regenerkennung & Selbstkalibrierung

### Zwei Schwellen, beide relativ zur Trockenfrequenz

Ein- und Ausschaltschwelle werden bei jedem Durchlauf getrennt aus der gelernten Trockenfrequenz `freq_dry` gebildet:

```
rain_start = freq_dry × Rain Threshold Wet    (Default 0.926 - Einschaltschwelle)
rain_stop  = freq_dry × Rain Threshold Dry    (Default 0.954 - Ausschaltschwelle)
```

* **Regen EIN:** Sobald die Frequenz unter `rain_start` fällt, wird sofort auf «Regen» geschaltet - ohne Verzögerung, damit z. B. eine Bewässerung rechtzeitig abbricht.
* **Regen AUS:** Erst wenn die Frequenz für die volle Dauer von **Rain Off Delay** (Default 3 min) über `rain_stop` bleibt. Jeder Messwert im Nassbereich setzt diesen Timer zurück. Das verhindert Flattern bei Nieselregen und während des Abtrocknens.

Beide Regler sind voneinander unabhängig; der Abstand zwischen ihnen **ist** die Hysterese. Liegt `Rain Threshold Dry` weniger als 0.01 über `Rain Threshold Wet`, hebt die Firmware ihn auf diesen Abstand an und schreibt eine Warnung ins Log - ohne Band flatterte der Zustand im Rauschen.

### Warum die Schwellen so stehen

Nach oben begrenzt das Rauschen der Basislinie, gemessen über eine Beobachtungsreihe von zehn Tagen: näher an die Trockenfrequenz heran gäbe es Fehlalarme. Nach unten kostet jede Reserve Vorwarnzeit - die frühere, deutlich unempfindlichere Einstellung meldete den Regenbeginn rund eine halbe Stunde später, ebenfalls gemessen.

Der Abstand der beiden Schwellen ist die Hysterese und liegt bei etwa dem Fünffachen der Rauschbreite. Enger heisst Flattern beim Abtrocknen, weiter heisst, dass der Sensor länger als nötig als nass gilt. Beide müssen unter 1.0 bleiben: auf oder über der Trockenfrequenz käme das Gerät nie mehr auf «trocken» zurück und die Selbstkalibrierung stünde still.

> Bis V1.1.0 hing die Ausschaltschwelle über eine Hysterese am Einschaltpunkt statt an der Trockenfrequenz. Wer empfindlicher stellte, schob sie mit nach oben, bis sie über der Trockenfrequenz lag - diese Kopplung hat die Empfindlichkeit blockiert.

### Zwei Fragen, zwei Entitäten

Der beheizte Sensor trocknet zwischen zwei Schauern in Minuten ab, ein Regenereignis zerfällt dadurch in mehrere Meldungen. Das ist physikalisch echt - an zwei Regentagen nachgemessen - und mit Schwellen oder einem längeren *Rain Off Delay* nicht zu beheben.

* **Regen Shed** - ist der Sensor **jetzt** nass? Schaltet innert 10 s ein, nach *Rain Off Delay* wieder aus. Für alles, was sofort reagieren muss.
* **Regen kürzlich** - hat es **in den letzten Minuten** geregnet? Geht ein, sobald der Sensor nass wird, und fällt erst nach *Rain Hold Time* ununterbrochener Trockenheit. Für Storen, Fenster, Bewässerung - alles, was ein Regenereignis als Ganzes braucht.

Die Haltezeit zählt ab der letzten Nässe, nicht ab dem Abschalten von *Regen Shed*. Ihr Vorgabewert ist eine Annahme, kein Messergebnis: er überbrückt die kurzen Trockenpausen eines Regentags, ohne getrennte Schauer zusammenzukleben. Höher stellen heisst eher «der Boden ist noch feucht», tiefer schneller freigeben; auf 0 fällt sie unmittelbar mit dem Trockenwerden zurück.

### Warum es keine Flankenerkennung gibt

Nicht jede Benetzung drückt die Frequenz tief genug, um die Absolutschwelle zu erreichen; Nieselregen und die ersten Tropfen eines Schauers bleiben darüber. V2.1.0 bis V2.2.1 versuchten sie am Tempo des Abfalls zu fassen: Steigung alle 10 s als Differenz zweier 60-s-Mittel, Schwelle −1000 Hz/min. **V3.0.0 hat das wieder entfernt.**

Gemessen wurde: Das Rauschen dieser Steigung liegt im Trockenen bei **σ = 338 Hz/min**, die Schwelle lag damit bei 3.0 σ. Im Betrieb ergab das **zwei Fehlauslösungen in 41 trockenen Stunden**, je 45-60 Minuten «Regen kürzlich» ohne einen Tropfen. Nachschärfen half nicht: ab −2408 Hz/min (0.926 × Trockenfrequenz) verlangt die Flanke binnen einer Minute mehr Abfall, als die Absolutschwelle insgesamt braucht - sie käme damit nie zuerst. Zwischen «nicht mehr im Rauschen» (5 σ ≈ 1690) und dieser Grenze liegt ein Faktor 1.4.

Wer schwache Benetzungen doch erkennen will, prüft den geglätteten **Pegel** gegen die Trockenschwelle statt seine Steigung: gleiches Signal, um √2 weniger Rauschen, und es bleibt stehen, statt nach einer Minute wieder zu verschwinden. Gebaut ist das nicht - die dokumentierten ersten Tropfen lagen bei 95.5 % der Trockenfrequenz, *Rain Threshold Dry* steht auf 95.4 %, und das ist zu knapp, um es ohne eigene Messreihe zu entscheiden.

### Wann kalibriert wird

Die Trockenfrequenz wird als gleitender Mittelwert nachgeführt (`freq_dry = (15 × freq_dry + f) ÷ 16`), aber **nur** wenn alle Bedingungen gleichzeitig erfüllt sind:

1. Es regnet aktuell nicht.
2. Die Frequenz liegt über `rain_stop` (Sensor gilt als trocken).
3. Der Sensor ist aufgeheizt (Isttemperatur ≥ Zieltemperatur − 2 K).
4. Seit dem Trockenwerden ist **Calibration delay** (Default 30 min) vergangen.
5. Die Abweichung zur bisherigen Trockenfrequenz liegt innerhalb von **Range for Calibration** (Default 4 %).

Welche Bedingung gerade blockiert, ist im Klartext an der Diagnose-Entität `1.1 Dry Frequency Calibration Status` ablesbar: `Regen aktiv`, `Sensor noch zu nass`, `NTC unplausibel - Heizung aus`, `Übertemperatur - Heizung aus`, `Sensordaten fehlen - Heizung aus`, `Heizt auf`, `Wartet auf Delay`, `Frequenz-Drift zu hoch` oder `Kalibriert`. Beim Start steht dort `Warte auf Sensorwerte`, bis der Frequenzzähler gültige Werte liefert.

Die Begrenzung über *Range for Calibration* ist bewusst eng gewählt: Sie verhindert, dass ein schleichend nasser oder defekter Sensor seine eigene Referenz mitzieht und die Regenerkennung dadurch blind wird.

### Heizungssollwert

```
Ziel = (Taupunkt ODER Umgebungstemperatur) + Heater Temperature Elevation
Ziel = clamp(Ziel, Heater Min Temperature, Heater Max Temperature)
```

Die Quelle ist über **Heater Source** umschaltbar. `Dew Point` (Default) hält den Sensor gezielt über dem Taupunkt und ist die energiesparendere Variante; `Ambient` bezieht sich auf die Umgebungstemperatur.

**Failsafe:** Der PID-Regler wird zwingend auf `OFF` gesetzt, sobald **eine** der drei Bedingungen nicht erfüllt ist:

* **Sollwert gültig** - liefert die Quelle (Taupunkt bzw. Umgebungstemperatur) `NaN`, etwa direkt nach dem Booten, wird nicht auf einen undefinierten Sollwert geregelt.
* **Istwert plausibel** (`ntc_min_plausible`, −30 °C) - ein defekter Fühler meldet kein `NaN`, sondern eine plausibel aussehende Zahl: sowohl bei Kurzschluss (über `log(0)`) als auch bei offener Leitung (über den sehr grossen Widerstand) landet die Rechnung bei rund −273 °C. **Beide Fehlerfälle laufen nach unten**, die untere Grenze fängt daher beide ab. Ohne diese Prüfung bildet der Regler aus dem scheinbar eiskalten Sensor einen riesigen Fehler und fährt die Heizung dauerhaft auf volle Leistung.
* **Keine Übertemperatur** (`heater_cutout_temp`, 60 °C) - die zulässige Höchsttemperatur des Sensors. Sie liegt 10 K über der einstellbaren Obergrenze von **Heater Max Temperature** (50 °C), ein regulärer Sollwert löst sie also nie aus. Wird sie trotzdem erreicht, liegt ein Fehler vor und die Heizung bleibt aus.

Die beiden Fühler-Fälle werden über `1.5 Heizung Störung` gemeldet; im Kalibrierstatus sind alle drei im Klartext unterschieden.

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

**NTC-Kette:** Die Temperatur der Sensorheizung wird in vier Stufen berechnet - ADC-Rohspannung (Abtastung 100 ms) → `resistance` (680 Ω, DOWNSTREAM) → `ntc` (B = 3750, 1 kΩ @ 25 °C) → gleitender Mittelwert über 20 Messwerte, der alle 2 s publiziert. Dieser 2-s-Wert speist den PID-Regler, seit V1.1.0 auch die Plausibilitätsprüfung und die Warm-Bedingung der Selbstkalibrierung; an Home Assistant geht ein zusätzlich auf 60 s gemittelter Wert. *Sinkt die angezeigte Temperatur, wenn der NTC erwärmt wird, muss `configuration` auf `UPSTREAM` gestellt werden.*

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
| **Heater Min Temperature** | 0…50 °C | 10 | Untere Klemmung des Sollwerts |
| **Heater Max Temperature** | 0…50 °C | 50 | Obere Klemmung des Sollwerts (bewusst unter der Übertemperatur-Abschaltung) |
| **Rain Threshold Wet** | 0.5…1.0 | 0.926 | Einschaltschwelle als Anteil der Trockenfrequenz |
| **Rain Threshold Dry** | 0.5…1.0 | 0.954 | Ausschaltschwelle als Anteil der Trockenfrequenz |
| **Rain Off Delay [min]** | 0…60 | 3 | Trockenzeit, bis «Regen Shed» zurückgesetzt wird |
| **Rain Hold Time [min]** | 0…180 | 45 | Nachlaufzeit von «Regen kürzlich» |
| **Calibration delay [min]** | 1…120 | 30 | Wartezeit nach dem Trockenwerden bis zur Kalibrierung |
| **Range for Calibration** | 0.01…0.2 | 0.04 | Maximal zulässige Drift für eine Kalibrierung |
| **SHT Heater Time [min]** | 1…30 | 5 | Heizdauer des SHT31-Wartungszyklus |
| **SHT Recovery Time [min]** | 1…30 | 12 | Abkühlzeit, in der keine Werte publiziert werden |
| **SHT Maintenance Interval [d]** | 0…30 | 7 | Abstand zwischen zwei Wartungszyklen (0 = aus) |
| **Barometer Elevation Correction** | −200…200 hPa | 0.0 | Höhenkorrektur des Luftdrucks |

### Messwerte (Read-Only in HA)

* **Temperature Shed (`sensor.temperature_shed`):** Umgebungstemperatur vom AM2315. Bleibt bewusst bei diesem Fühler, obwohl der SHT31 der besser spezifizierte wäre: ein Wechsel ändert die Quelle einer langen Reihe und ist samt Migration der Historie ein eigener Schritt.
* **Humidity Shed (`sensor.humidity_shed`):** Relative Luftfeuchte vom SHT31. Während eines Wartungszyklus werden keine Werte publiziert, HA hält den letzten Stand.
* **Barometic Pressure Shed (`sensor.barometic_pressure_shed`):** Luftdruck vom BMP280 inkl. Höhenkorrektur.
* **Dew Point Shed (`sensor.dew_point_shed`):** Berechneter Taupunkt (Magnus-Formel).
* **Regen Shed (`binary_sensor.raining`):** Ist der Sensor jetzt nass? `device_class: moisture`.
* **Regen kürzlich:** Hat es innerhalb der *Rain Hold Time* geregnet? `device_class: moisture`.
* **Temperature SHT31:** Temperatur des SHT31, gemessen im selben Chip wie die Luftfeuchte. Seit V3.1.0 die Temperatur der Taupunktrechnung. Während eines Wartungszyklus werden keine Werte publiziert.
* **Weather Station Frequency (`sensor.weather_station_frequency`):** Aktuelle Sensorfrequenz, sekündlich gemessen und über 60 s gemittelt.
* **Weather Station Sensor Heater (`sensor.weather_station_sensor_heater`):** Isttemperatur der Sensorheizung, über 60 s gemittelt.
* **Rain Sensor Heater PID (`climate.ha_weather_station_rain_sensor_heater_pid`):** Der PID-Regler als Climate-Entität, inkl. Soll-/Isttemperatur und Betriebszustand.

> **Hinweis zu Namen und IDs:** Die hier genannten Bezeichnungen sind die Namen aus der Firmware. In der bestehenden Home-Assistant-Instanz sind mehrere Entitäten manuell umbenannt (`Humidity Shed` → «Outdoor Humidity», `Weather Station Frequency` → «Sensor Frequency», `Weather Station Sensor Heater` → «Temperature Rainsensor», `Regen Shed` → «Raining»). Solche Umbenennungen liegen in der HA-Registry und werden von Firmware-Updates nicht überschrieben. Auch die Entity-IDs hängen vom Registrierungszeitpunkt ab - ältere Entitäten tragen keinen Gerätepräfix, später hinzugekommene (u. a. alle Diagnose-Entitäten) dagegen schon. Bei einer Neuinstallation ergeben sich daher andere IDs.

### Diagnose (Read-Only in HA)

Die Kategorie 1.x ist projektlokal, 2.x bis 6.x kommen aus `common/diagnostics.yaml`.

* **1.0 Weather Station Dry Frequency:** Aktuell gelernte Trockenfrequenz - die Referenz der gesamten Regenerkennung.
* **1.1 Dry Frequency Calibration Status:** Klartext-Grund, warum gerade (nicht) kalibriert wird.
* **1.2 Dry Frequency Calibration Active:** EIN, solange die Trockenfrequenz nachgeführt wird.
* **1.3 SHT Wartungsstatus:** `Normalbetrieb`, `Heizt (Wartungszyklus)` oder `Abkühlphase`.
* **1.4 SHT Wartungszyklus aktiv:** EIN während des gesamten Zyklus (Heiz- **und** Abkühlphase).
* **1.5 Heizung Störung** (`device_class: problem`): EIN, wenn der NTC-Wert das Plausibilitätsfenster verlässt und die Heizung deshalb zwangsweise aus ist. Im Normalbetrieb kippt der Zustand nie - eignet sich daher direkt als Auslöser für eine Benachrichtigung in Home Assistant.
* **1.7 Temperature Delta SHT31 - AM2315:** Temperaturunterschied zwischen den beiden Sensoren. Hat die Umstellung in V3.1.0 ausgelöst und geht seither in keine Rechnung mehr ein. Bleibt als Kreuzprüfung - die einzige Redundanz der Station (siehe Abschnitt 8).

> Die Nummer **1.6** ist frei: dort lag bis V2.2.1 die Steigung der Flankenerkennung. Die verbleibenden Entitäten rücken bewusst nicht nach - eine Umbenennung ändert die Entity-ID und kostet den Verlauf.

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
| Temperature SHT31, 1.7 Temperature Delta | 60 s | je 1'440 |
| 1.1 Calibration Status, 1.2 Calibration Active | nur bei Änderung | wenige |
| Regen Shed, Regen kürzlich, 1.4 SHT Wartungszyklus aktiv | nur bei Flankenwechsel | wenige |

Drei Entwurfsentscheidungen dahinter:

* **Der PID-Regler bestimmt seine eigene Meldungsrate.** ESPHomes `PIDClimate` publiziert bei jeder Änderung der Isttemperatur, und der Regler rechnet genau dann, wenn sein Eingangssensor einen Wert liefert. `send_every` an `heater_temp_fast` steuert deshalb beides zugleich. Der ADC tastet weiterhin mit 10 Hz ab, publiziert aber nur alle 2 s einen Mittelwert - bei einer Aufheizrate von rund 0.1 K/s bewegt sich die Temperatur zwischen zwei Abtastungen um 0.2 K, für eine träge Heizung völlig ausreichend.
* **Der PID wird nur bei echter Änderung angefasst.** Jeder `ClimateCall::perform()` löst intern ein `publish_state()` **und** ein `save_state_()` ins NVS aus. Die Hauptschleife setzt Modus und Sollwert daher nur noch, wenn der Modus wechselt oder sich der Sollwert um mindestens 0.1 K verschiebt.
* **Statusmeldungen werden entprellt.** `BinarySensor::publish_state` und `TextSensor::publish_state` senden in ESPHome ohne Vergleich mit dem Vorwert. Kalibrierstatus, Regenstatus und Wartungsstatus führen deshalb in der Firmware selbst Buch und melden nur Änderungen.

Nicht angefasst ist das gemeinsame `common/diagnostics.yaml` (Kategorien 2.x bis 6.x, zusammen rund 12'000 Meldungen/Tag), weil es von allen Projekten geteilt wird. Wer dort sparen will, sollte es projektübergreifend entscheiden.

---

## 8. Bekannte Punkte

* **Der konstante Versatz zwischen den beiden Temperaturfühlern bleibt offen.** Über 169 Stunden gemessen trennt SHT31 und AM2315 ein Versatz von **+0.19 K**, der nicht von der Temperaturrampe abhängt. Er enthält die Kalibrieroffsets zweier Exemplare zweier Hersteller; welcher der beiden recht hat, sagt nur ein Referenzfühler. V3.1.0 hat den *dynamischen* Anteil beseitigt, indem der Taupunkt beide Grössen aus dem SHT31 nimmt - der konstante Anteil ist geblieben. Weil die angezeigte `Temperature Shed` weiterhin vom AM2315 kommt, trägt die Spanne Temperatur minus Taupunkt diesen Versatz weiterhin.
* **Der Wartungszyklus zählt ab dem Systemstart.** Die Firmware misst den Abstand über die Laufzeit, nicht über die Uhrzeit - jeder Neustart und jedes OTA setzt den Zähler zurück. Wird das Gerät häufiger als alle sieben Tage neu gestartet, läuft der Zyklus nie. Ein Nachziehen bräuchte eine echte Zeitquelle (`time:`), die das Projekt bisher nicht einbindet.
* **Kondensat auf dem SHT31 wird nicht behandelt.** Der interne Heizer würde Kondensat verdampfen, ist dafür aber nicht spezifiziert, und die Feuchteschwelle von 98 % traf den Fall nicht: In 31 Tagen löste sie genau einen Zyklus aus, und dieser korrigierte nichts - die Feuchte stand davor und nach voller Erholung auf demselben Wert. Wer echten Kondensationsschutz will, müsste auf «Feuchte klebt über mehrere Minuten bei rund 100 %» auslösen statt auf das Überschreiten einer Schwelle.
* **Schreibweise `Barometic`** statt `Barometric` im Entitätsnamen. Eine Korrektur ändert die Entity-ID in Home Assistant und kostet den bisherigen Verlauf, ist deshalb kein reiner Kosmetik-Fix.
* **Climate-Entität als grösster verbleibender Sender:** Wer die ~43'000 Meldungen/Tag auch noch loswerden will, kann `climate` auf `internal: true` setzen. Funktional kostet das nichts - die Hauptschleife überschreibt jede manuelle Änderung ohnehin innerhalb von 10 s -, man verliert aber die Sicht auf Soll-/Isttemperatur und Reglerzustand in HA. Alternativ lässt sich die Entität in HAs `recorder` ausschliessen, dann bleibt sie sichtbar, landet aber nicht mehr in der Datenbank.
