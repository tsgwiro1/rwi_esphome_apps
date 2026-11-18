# ha-mini-display - Rotierender Statusmonitor auf dem TTGO T-Display

![Version](https://img.shields.io/badge/version-1.1.1-blue)
[![ESPHome](https://img.shields.io/badge/ESPHome-Ready-03a9f4?logo=esphome&logoColor=white)](https://esphome.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ein TTGO T-Display (ESP32 mit 1.14"-Farbdisplay) als kleiner Statusmonitor auf
dem Schreibtisch. Das Gerät holt sich fünfzehn Entitäten aus Home Assistant und
blättert sie im 5-Sekunden-Takt über sechs Seiten: Uhrzeit, Fahrzeug, Wallbox,
PV-Leistung, Hausbatterie und Wetter. Die beiden Taster des Boards erlauben
Blättern von Hand, Anhalten der Rotation und Dimmen der Beleuchtung.

Wichtig zum Verständnis: **das Gerät steuert nichts und misst nichts.** Es ist
ein Anzeigegerät ohne eigene Logik - alle Werte kommen aus Home Assistant, und
ohne Home Assistant zeigt es nichts an.

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
  eingefrorene Anzeige ist von einem stehenden Istwert nicht zu unterscheiden.
* **Fehlinterpretationen der Anzeige.**
* Die Richtigkeit, Aktualität oder Vollständigkeit des bereitgestellten Codes
  oder der Dokumentation.

---

## 1. Funktionsprinzip

### Die sechs Seiten

| # | Titel | Inhalt |
| :--- | :--- | :--- |
| 1 | - | Datum und Uhrzeit |
| 2 | GRIGIO / Gast | Ladestand in Farbstufen und Restreichweite, oder Gastfahrzeug |
| 3 | WALLBOX | Symbol grün beim Laden, «CHARGING» mit Ladeleistung oder «READY» |
| 4 | SOLAR POWER | Wechselrichter-Eingangsleistung in W |
| 5 | BATTERY | Batteriesymbol in elf Stufen, SoC in %, Lade-/Entladeleistung |
| 6 | - | Wetterlage, Aussentemperatur, Regenstatus |

**Hausbatterie:** Das Symbol füllt sich in Zehnerschritten und wechselt die
Farbe: ab 80 % grün, ab 60 % hellgrün, ab 40 % gelb, ab 20 % orange, darunter
hellrot. Die Leistung ist grün beim Laden und rot beim Entladen.

**Fahrzeug:** Der Ladestand ist ab 60 % grün, ab 40 % hellgrün, ab 20 % orange,
darunter hellrot.

### Die Fahrzeugseite

| Lage | Anzeige |
| :--- | :--- |
| noch nichts bekannt | «VEHICLE», «LOADING...» |
| nichts angesteckt | «VEHICLE», «NOT CONNECTED» |
| Erkennung läuft | «VEHICLE», «DETECTING ...» |
| Grigio erkannt | «GRIGIO», Ladestand und Reichweite |
| fremdes Auto | Titel aus evcc oder «GUEST VEHICLE» in Orange, «no data» |

Grigio wird über `sensor.evcc_vehicle_name` = `db:1` erkannt, jeder andere Wert
gilt als fremdes Auto. **Hängt nichts am Kabel, überspringt die Rotation die
Fahrzeug- und die Wallbox-Seite**; über die Taster bleiben beide erreichbar.

### Die Wetterseite

Alle fünfzehn Zustände von `weather.egnach` haben Symbol, Text und Farbe:

| Farbe | Zustände |
| :--- | :--- |
| gelb | `sunny`, `lightning`, `lightning-rainy` |
| blau | `rainy`, `pouring`, `snowy`, `snowy-rainy`, `hail` |
| grau | `cloudy`, `partlycloudy`, `clear-night`, `fog`, `windy`, `windy-variant` |
| orange | `exceptional` |

Darunter die Aussentemperatur sowie «WET» mit der Sensorfrequenz oder «DRY» aus
der Regenerkennung der Wetterstation.

### Rotation und Bedienung

Alle 5 s wird eine Seite weitergeblättert. Nach einem Neustart läuft die
Rotation immer, auch wenn sie vorher angehalten war.

| Taster | Dauer | Funktion | Ereignis |
| :--- | :--- | :--- | :--- |
| links (GPIO0) | bis 1 s | eine Seite zurück | `press` |
| links (GPIO0) | 1 - 5 s | Beleuchtung umschalten | `long_press` |
| rechts (GPIO35) | bis 1 s | eine Seite vor | `press` |
| rechts (GPIO35) | 1 - 5 s | Rotation an/aus | `long_press` |

---

## 2. Hardware & Pinout (TTGO T-Display, ESP32 `esp32dev`)

| Pin | Funktion |
| :--- | :--- |
| GPIO18 | SPI CLK |
| GPIO19 | SPI MOSI |
| GPIO5 | Display CS |
| GPIO16 | Display DC |
| GPIO23 | Display Reset |
| GPIO4 | Hintergrundbeleuchtung, dimmbar (`ledc`) |
| GPIO0 | Taster links |
| GPIO35 | Taster rechts |

**Display:** ST7789V, Modell `TTGO_TDISPLAY_135x240`, `rotation: 270°`, im
Betrieb 240x135 im Querformat.

**Beleuchtung:** Das Licht trägt `restore_mode: RESTORE_DEFAULT_ON`. **Wer diese
Zeile entfernt, bekommt nach dem nächsten Flash einen dunklen Schirm.**

**Symbole:** Alle Symbole sind Glyphen aus `fonts/materialdesignicons-webfont.ttf`
(Apache 2.0, Lizenz daneben). Das Gerät braucht keine Bilddateien. Text in der
Google-Font Lato.

---

## 3. Home Assistant Integration

### Vom Gerät bereitgestellt

| Entität | Bedeutung |
| :--- | :--- |
| `event.attic_ha_mini_display_button_left` | Taster links, Typen `press` und `long_press` |
| `event.attic_ha_mini_display_button_right` | Taster rechts, Typen `press` und `long_press` |
| `light.ha_mini_display_backlight` | dimmbare Hintergrundbeleuchtung |

Dazu die Diagnose-Entitäten aus `common/diagnostics.yaml`.

### Vom Gerät konsumiert

| Entität | Verwendung |
| :--- | :--- |
| `sensor.evcc_vehicle_name` | Seite 2, Grigio (`db:1`) oder Gastfahrzeug |
| `sensor.evcc_vehicle_title` | Seite 2, Name des Gastfahrzeugs |
| `binary_sensor.evcc_vehicle_detection` | Seite 2, «DETECTING ...» und Rotation |
| `sensor.evcc_vehicle_soc` | Seite 2, Ladestand Fahrzeug |
| `sensor.evcc_vehicle_range` | Seite 2, Restreichweite |
| `binary_sensor.evcc_loadpoint_connected` | Seite 2 und 3, Fahrzeug angesteckt |
| `binary_sensor.evcc_loadpoint_charging` | Seite 3, «CHARGING» oder «READY» |
| `sensor.evcc_charge_power_w` | Seite 3, Ladeleistung |
| `sensor.input_power` | Seite 4, Wechselrichter-Eingangsleistung |
| `sensor.battery_state_of_capacity` | Seite 5, Ladestand Hausbatterie |
| `sensor.charge_discharge_power` | Seite 5, Lade-/Entladeleistung |
| `weather.egnach` | Seite 6, Wetterzustand |
| `sensor.outdoor_temperature` | Seite 6, Aussentemperatur |
| `binary_sensor.raining` | Seite 6, WET/DRY |
| `sensor.weather_station_frequency` | Seite 6, Sensorfrequenz bei Nässe |

Die Uhrzeit kommt von `time.homeassistant`.

---

## 4. Secrets & Inbetriebnahme

Drei Einträge müssen in `~/esphome/secrets.yaml` stehen:

```yaml
minidisplay_api_key: "…"                 # API- und OTA-Verschlüsselung
minidisplay_fallback_ap_ssid: "…"        # Fallback-Hotspot
minidisplay_fallback_ap_password: "…"
```

Dazu die gemeinsamen Einträge `wifi_ssid`, `wifi_password` sowie die von
`common/diagnostics.yaml` erwarteten `mac_bssid_ug`, `mac_bssid_eg` und
`mac_bssid_dg`.

Gebaut wird in `~/esphome`, geflasht über den mDNS-Namen, weil das Gerät keine
feste Adresse hat:

```bash
PLATFORMIO_CORE_DIR="$HOME/.platformio_esphome" ~/.local/bin/esphome compile ha-mini-display.yaml
```

```bash
PLATFORMIO_CORE_DIR="$HOME/.platformio_esphome" ~/.local/bin/esphome upload ha-mini-display.yaml --device ha-mini-display.local
```

Nach dem Flash ist nichts einzustellen.

---

## 5. Datenlast gegenüber Home Assistant

Das Gerät liest fast nur. Selbst meldet es Tastendrücke, das Licht und die
Diagnose-Entitäten.

---

## 6. Offene Punkte

* **Die Display-Plattform `st7789v` ist seit ESPHome 2026.7 deprecated** und
  verweist auf `mipi_spi`. Heute läuft sie unverändert. Fällt der Treiber weg,
  sind beim Wechsel Farbformat, die Offsets 52/40 und `backlight_pin: false`
  neu zu prüfen - an Letzterem hängt die dimmbare Beleuchtung.
