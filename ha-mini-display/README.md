# ha-mini-display - Rotierender Statusmonitor auf dem TTGO T-Display

![Version](https://img.shields.io/badge/version-1.0.1-blue)
[![ESPHome](https://img.shields.io/badge/ESPHome-Ready-03a9f4?logo=esphome&logoColor=white)](https://esphome.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ein TTGO T-Display (ESP32 mit 1.14"-Farbdisplay) als kleiner Statusmonitor auf
dem Schreibtisch. Das Gerät holt sich zwölf Entitäten aus Home Assistant und
blättert sie im 5-Sekunden-Takt über fünf Seiten: Fahrzeug, Wallbox, PV-Leistung,
Hausbatterie und Wetter. Die beiden Taster des Boards erlauben Blättern von Hand,
Anhalten der Rotation und Ausschalten der Beleuchtung.

Wichtig zum Verständnis: **das Gerät steuert nichts und misst nichts.** Es ist
ein Anzeigegerät ohne eigene Logik - alle Werte kommen aus Home Assistant, und
ohne Home Assistant zeigt es nichts an (siehe Abschnitt 6).

---

## Haftungsausschluss (Disclaimer)

⚠️ **WICHTIGER HINWEIS: VERWENDUNG AUF EIGENE GEFAHR!** ⚠️

Dieses Projekt beschreibt ein privates Bastelprojekt zur Optimierung der eigenen
Hausautomatisierung. Die Nutzung, der Nachbau sowie das Einspielen des
bereitgestellten Codes und der Konfigurationen erfolgen ausdrücklich auf
**eigene Gefahr und eigenes Risiko**.

Der Autor übernimmt **keinerlei Haftung, Gewährleistung oder Verantwortung**
für:

* **Schäden jeglicher Art** an Elektronik oder anderen Komponenten der
  Haustechnik.
* Die Richtigkeit der **angezeigten Werte.** Sie werden unverändert aus Home
  Assistant übernommen und sind nur so gut wie ihre jeweilige Quelle. Eine
  eingefrorene Anzeige ist von einem stehenden Istwert nicht zu unterscheiden
  (siehe Abschnitt 6).
* **Fehlinterpretationen der Anzeige.** Insbesondere ist eine leere oder
  unvollständige Wetterseite kein Hinweis auf gutes Wetter, sondern kann ein nicht
  abgedeckter Zustand sein (siehe Abschnitt 6).
* Die Richtigkeit, Aktualität oder Vollständigkeit des bereitgestellten Codes
  oder der Dokumentation.

---

## 1. Funktionsprinzip

### Die fünf Seiten

Die Seiten werden in dieser Reihenfolge durchlaufen:

| # | ID | Titel | Inhalt |
| :--- | :--- | :--- | :--- |
| 1 | `showtesla` | GRIGIO | Fahrzeugsymbol, Ladestand in Farbstufen, Restreichweite in km |
| 2 | `showcharger` | WALLBOX | Wallbox-Symbol, «CHARGING» mit Ladeleistung oder «READY» |
| 3 | `shownettopower` | SOLAR POWER | Solarpanel-Symbol, Wechselrichter-Eingangsleistung in W |
| 4 | `showbattery` | BATTERY | Batteriesymbol in fünf Stufen, SoC in %, Lade-/Entladeleistung |
| 5 | `show_weather` | - | animiertes Wetter-GIF, Zustandstext, Aussentemperatur, Regenstatus |

Der Ladestand des Fahrzeugs und der Füllstand der Hausbatterie sind die einzigen
Werte mit eigener Farb- bzw. Symbollogik:

| Schwelle | Fahrzeug (Farbe) | Hausbatterie (Symbol) |
| :--- | :--- | :--- |
| ab 80 % | grün | `b100` |
| ab 60 % | grün | `b80` |
| ab 40 % | hellgrün | `b60` |
| ab 20 % | orange | `b40` |
| darunter | hellrot | `b20` |

Die Batterieleistung ist grün bei Ladung und rot bei Entladung, dort als
Absolutwert - das Vorzeichen steckt also in der Farbe, nicht in der Zahl.

Vier der fünf Seiten prüfen ihre Hauptquelle mit `has_state()` und zeigen vor dem
ersten Wert «LOADING...». Die Wetterseite prüft Regenstatus und Aussentemperatur
einzeln und zeigt letztere bis zum ersten Wert als `--.- °C`.

Eine weitere Seite ist im Code auskommentiert und damit inaktiv: eine Datums- und
Uhrzeitanzeige.

Die Wetterseite deckt alle fünfzehn Zustände ab, die `weather.egnach` liefern
kann. Vier davon werden zweizeilig gesetzt, weil der Text sonst nicht auf die
Breite passt: «PARTLY / CLOUDY», «SNOWY / RAIN», «CLEAR / NIGHT» und
«LIGHTNING / RAINY».

### Rotation und Bedienung

Ein `interval` von 5 s blättert eine Seite weiter, sofern das Global `rotate`
gesetzt ist. Es startet auf `true` und ist **nicht** neustartfest - nach jedem
Reboot rotiert die Anzeige wieder.

Die beiden Taster des Boards liegen auf GPIO0 und GPIO35 und tragen je zwei
Funktionen, unterschieden über die Betätigungsdauer:

| Taster | Dauer | Funktion |
| :--- | :--- | :--- |
| GPIO0 | 1 - 1000 ms | eine Seite zurück |
| GPIO0 | 1001 - 5000 ms | Hintergrundbeleuchtung umschalten |
| GPIO35 | 1 - 1000 ms | eine Seite vor |
| GPIO35 | 1001 - 5000 ms | automatische Rotation an/aus |

Technisch ist jede der vier Funktionen ein eigener `binary_sensor` auf demselben
Pin, unterschieden über `min_length`/`max_length` im `on_click`. Deshalb steht bei
beiden Pins `allow_other_uses: true`. Eine Betätigung über 5 s löst nichts aus.

Das Display wird sekündlich neu gezeichnet (`update_interval: 1s`), zusätzlich
sofort bei jedem Blättern. Das Wetter-GIF rückt pro Zeichnung ein Bild vor,
läuft also nur während der fünf Sekunden, in denen seine Seite sichtbar ist.

---

## 2. Hardware & Pinout (TTGO T-Display, ESP32 `esp32dev`)

| Pin | Funktion |
| :--- | :--- |
| GPIO18 | SPI CLK |
| GPIO19 | SPI MOSI |
| GPIO5 | Display CS |
| GPIO16 | Display DC |
| GPIO23 | Display Reset |
| GPIO4 | Hintergrundbeleuchtung (dreifach belegt, siehe Abschnitt 6) |
| GPIO0 | Taster links, invertiert, interner Pull-up |
| GPIO35 | Taster rechts, invertiert (nur Eingang, Pull-up extern auf dem Board) |

**Display:** ST7789V, Modell `TTGO_TDISPLAY_135x240`, `rotation: 270°`. Panel
135x240 mit Offset 52/40, im Betrieb also 240x135 im Querformat. Der SPI-Bus hat
kein MISO - das Display wird nur beschrieben, nicht gelesen.

**Bildmaterial:** Die Grafiken (`pic/tesla.png`, `pic/wallbox.png`,
`pic/solarpanel-icon.png`, `pic/b100.png` bis `pic/b20.png`,
`pic/thermometer_icon.png`, `pic/rain_ws.png`, `pic/dry.png`) und die Animation
`pic/weather.gif` liegen wie bei den übrigen Display-Projekten in
`~/esphome/pic/` und sind nicht Teil dieses Repositories. Alle sind `type: RGB`,
die Symbole auf 80x80 bzw. 30x30 skaliert.

**Schriften:** vier Schnitte der Google-Font Lato (400 in 20 px, 700 in 24 px,
900 in 30 px und 50 px). Der 50-px-Schnitt `latoblackheading1` wird nur von der
auskommentierten Uhrzeitseite verwendet.

---

## 3. Home Assistant Integration

### Vom Gerät bereitgestellt

| Entität | Bedeutung |
| :--- | :--- |
| `binary_sensor.ha_mini_display_short_press_button_0` | Kurzdruck links |
| `binary_sensor.ha_mini_display_short_press_button_1` | Kurzdruck rechts |
| `binary_sensor.ha_mini_display_long_press_button_1` | Langdruck rechts |
| `light.ha_mini_display_backlight` | dimmbares Licht auf dem Backlight-Ausgang (siehe Abschnitt 6) |

Der Langdruck auf GPIO0 hat bewusst keinen Namen und erscheint nicht in Home
Assistant; er wirkt nur lokal auf die Beleuchtung.

Dazu die Diagnose-Entitäten aus `common/diagnostics.yaml` (Kategorien 2.x bis
6.x: WLAN, Netzwerk, System, Versionen, Neustart-Buttons). Sie tragen bei diesem
Gerät den Bereichspräfix `attic_`, also etwa
`sensor.attic_ha_mini_display_4_0_system_gesundheit` (siehe Abschnitt 6).

### Vom Gerät konsumiert

Zwölf Entitäten, alle als `platform: homeassistant`:

| Entität | Verwendung |
| :--- | :--- |
| `sensor.evcc_vehicle_soc` | Seite 1, Ladestand Fahrzeug |
| `sensor.evcc_vehicle_range` | Seite 1, Restreichweite |
| `binary_sensor.evcc_loadpoint_connected` | Seite 1 und 2, Torbedingung «verbunden» |
| `binary_sensor.evcc_loadpoint_charging` | Seite 2, «CHARGING» oder «READY» |
| `sensor.evcc_charge_power_w` | Seite 2, Ladeleistung |
| `sensor.input_power` | Seite 3, Wechselrichter-Eingangsleistung |
| `sensor.battery_state_of_capacity` | Seite 4, Ladestand Hausbatterie |
| `sensor.charge_discharge_power` | Seite 4, Lade-/Entladeleistung |
| `weather.egnach` | Seite 5, Wetterzustand (per `to_upper` in Grossbuchstaben) |
| `sensor.outdoor_temperature` | Seite 5, Aussentemperatur |
| `binary_sensor.raining` | Seite 5, WET/DRY |
| `sensor.weather_station_frequency` | Seite 5, Sensorfrequenz bei Nässe |

Dazu `time.homeassistant` als Zeitquelle - im aktiven Code ohne Funktion, weil
nur die auskommentierte Uhrzeitseite sie liest.

---

## 4. Secrets & Inbetriebnahme

Vier Einträge müssen in `~/esphome/secrets.yaml` stehen:

```yaml
minidisplay_api_key: "…"                 # API-Verschlüsselung
minidisplay_ota_key: "…"                 # OTA-Passwort
minidisplay_fallback_ap_ssid: "…"        # Fallback-Hotspot
minidisplay_fallback_ap_password: "…"
```

Dazu die gemeinsamen Einträge `wifi_ssid`, `wifi_password` sowie die von
`common/diagnostics.yaml` erwarteten `mac_bssid_ug`, `mac_bssid_eg` und
`mac_bssid_dg`.

Gebaut wird in `~/esphome`, wo `secrets.yaml`, `common/` und `pic/` auflösbar
sind:

```bash
PLATFORMIO_CORE_DIR="$HOME/.platformio_esphome" ~/.local/bin/esphome compile ha-mini-display.yaml
```

Nach dem Flash ist nichts einzustellen - das Gerät bezieht alles aus Home
Assistant und beginnt mit der Rotation. Fällt das WLAN aus, spannt es den
Fallback-AP mit Captive Portal auf. Einen lokalen Webserver hat dieses Gerät
nicht.

---

## 5. Datenlast gegenüber Home Assistant

Die Richtung ist hier umgekehrt zu den übrigen Projekten: das Gerät ist
überwiegend Abonnent, nicht Melder. Es liest zwölf Entitäten und schreibt selbst
fast nichts.

Eigene Zeilen entstehen nur durch die drei Taster-Binärsensoren - je Betätigung
zwei Zustandswechsel, also einige Zeilen pro Tag - sowie durch das Licht
«Backlight» und die Diagnose-Entitäten aus `common/diagnostics.yaml`. Diese
melden dank ihrer Lambda-Filter nur bei echter Änderung.

Für die Datenbank zählt ohnehin nur, was sich ändert: Home Assistant verwirft
unveränderte Wiederholungen im Recorder. Wer die tatsächliche Zeilenzahl wissen
will, misst sie über `total_count` je Entität in der Recorder-Historie, statt sie
aus dem Melde-Intervall zu schätzen.

Die sekündliche Neuzeichnung des Displays erzeugt **keine** Last in Home
Assistant - sie liest nur den lokal zwischengespeicherten Stand der abonnierten
Entitäten.

---

## 6. Bekannte Punkte

* **GPIO4 ist dreifach belegt, und die Dimmbarkeit funktioniert deshalb nicht.**
  Derselbe Pin ist `backlight_pin` des Displays, `ledc`-Ausgang hinter dem Licht
  «Backlight» **und** ein interner GPIO-Schalter für den Langdruck auf GPIO0. Die
  drei Komponenten schreiben unkoordiniert auf den Pin; wer zuletzt schreibt,
  gewinnt. Der Kommentar «Currently not working» in der YAML steht genau
  deswegen dort. `allow_other_uses: true` unterdrückt nur die Prüfung, es löst
  den Konflikt nicht. Sauber wäre **eine** Instanz - der `ledc`-Ausgang mit dem
  monochromatischen Licht - und der Verzicht auf `backlight_pin` und
  GPIO-Schalter.
* **Nebenwerte auf einer Seite hängen an der `has_state()`-Prüfung des
  Hauptwerts.** Jede Seite prüft ihre Leitgrösse, die übrigen Werte derselben
  Seite aber nicht einzeln: die Sensorfrequenz auf der Wetterseite hängt an
  `binary_sensor.raining`, Restreichweite und Ladeleistung hängen am
  Verbindungsstatus der Wallbox. Kommt eine dieser Nebengrössen später als ihre
  Leitgrösse, steht für einen Moment `nan` auf dem Display. In der Praxis stammen
  die Werte je Seite aus derselben Integration und treffen zusammen ein, weshalb
  das bisher nicht aufgefallen ist. Die Aussentemperatur, die als einzige gar
  keine Prüfung hatte, ist seit V1.0.1 abgefangen.
* **Die auskommentierte Uhrzeitseite bleibt Ballast.** Sie steht samt der
  Zeitquelle `esptime` und dem nur dort benutzten Schriftschnitt
  `latoblackheading1` in der YAML, ohne aktiv zu sein - anders als der frühere
  Einstrahlungsgraph, der mit V1.0.1 entfernt wurde. Sie liesse sich durch
  Entkommentieren sofort wieder aktivieren; solange das nicht entschieden ist,
  belegt sie nur Flash.
* **Die Fallunterscheidung auf Seite 3 ist wirkungslos.** Der Vergleich
  `id(solar_input).state > -1000` wählt zwischen zwei Schriftschnitten, gibt aber
  in beiden Zweigen denselben Text mit demselben Format aus. Da
  `sensor.input_power` die Eingangsleistung des Wechselrichters ist und nicht
  negativ wird, greift ohnehin immer der erste Zweig.
* **Ohne Home Assistant zeigt das Gerät nichts.** Alle zwölf Quellen sind
  `platform: homeassistant`. Ist HA nicht erreichbar, behält ESPHome die letzten
  bekannten Werte, und die Anzeige friert auf dem Stand des Verbindungsabbruchs
  ein - für den Betrachter nicht von einer stehenden Anlage zu unterscheiden. Nach
  einem Reboot ohne HA stehen alle Seiten auf «LOADING...». Es gibt keinen lokalen
  Webserver und keine Fallback-Anzeige.
* **Die Taster sind in Home Assistant als Binärsensoren sichtbar, nicht als
  Buttons.** «Short Press Button 0/1» und «Long Press Button 1» erscheinen als
  `binary_sensor` und tragen keine `device_class`. Für eine Auslösung von
  Automationen wären `event`- oder `button`-Entitäten die passendere Form.
* **Die Rotation ist nicht neustartfest.** Wer sie per Langdruck abschaltet, hat
  sie nach dem nächsten Reboot oder OTA wieder aktiv - das Global `rotate` ist
  ohne `restore_value`.
* **Die Display-Plattform `st7789v` ist ab ESPHome 2026.7 als deprecated
  markiert** und verweist auf `mipi_spi`. Sie ist dort noch der eigenständige
  Legacy-Treiber und funktioniert unverändert - die `mipi_spi`-Regression, die
  `wp-fp1-smartblock` auf 2026.5.3 festhält, betrifft dieses Gerät also nicht.
  Der Wechsel auf `mipi_spi` wird aber irgendwann fällig, und dann sind
  Farbformat und die Offsets 52/40 neu zu prüfen.
* **Die Diagnose-Entitäten tragen einen Bereichspräfix, die älteren Entitäten
  nicht.** Home Assistant hat die mit V1.0.0 neu entstandenen Diagnose-Entitäten
  als `sensor.attic_ha_mini_display_…` angelegt, weil das Gerät dem Bereich
  «Attic» zugeordnet ist und HA neu erzeugten Entitäten den Bereichsnamen
  voranstellt. Die schon vorher bestehenden Entitäten - die drei Taster und
  «Backlight» - heissen weiterhin `…ha_mini_display_…` ohne Präfix. Von den zehn
  Geräten mit dem Diagnose-Paket sind acht ohne Präfix, dieses mit `attic_` und
  `wp-fp1-smartblock` mit `infrastructure_`. Funktional bedeutungslos, aber
  uneinheitlich; eine Umbenennung in Home Assistant wäre ein reiner
  Registry-Eingriff und würde alle Verweise auf die betroffenen IDs brechen.
* **Die Seitenreihenfolge und alle Koordinaten sind Festwerte.** Die Texte sind
  auf 240x135 und auf die Symbolgrössen abgestimmt; wird ein Symbol getauscht oder
  die Rotation geändert, müssen die Koordinaten in den Lambdas nachgezogen werden.
