# ha-mini-display - Rotierender Statusmonitor auf dem TTGO T-Display

![Version](https://img.shields.io/badge/version-1.1.0-blue)
[![ESPHome](https://img.shields.io/badge/ESPHome-Ready-03a9f4?logo=esphome&logoColor=white)](https://esphome.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ein TTGO T-Display (ESP32 mit 1.14"-Farbdisplay) als kleiner Statusmonitor auf
dem Schreibtisch. Das Gerät holt sich fünfzehn Entitäten aus Home Assistant und
blättert sie im 5-Sekunden-Takt über sechs Seiten: Uhrzeit, Fahrzeug, Wallbox,
PV-Leistung, Hausbatterie und Wetter. Die beiden Taster des Boards erlauben
Blättern von Hand, Anhalten der Rotation und Dimmen der Beleuchtung.

Wichtig zum Verständnis: **das Gerät steuert nichts und misst nichts.** Es ist
ein Anzeigegerät ohne eigene Logik - alle Werte kommen aus Home Assistant, und
ohne Home Assistant zeigt es nichts an (siehe [OFFENE-PUNKTE.md](OFFENE-PUNKTE.md)).

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
  (siehe [OFFENE-PUNKTE.md](OFFENE-PUNKTE.md)).
* **Fehlinterpretationen der Anzeige.**
* Die Richtigkeit, Aktualität oder Vollständigkeit des bereitgestellten Codes
  oder der Dokumentation.

---

## 1. Funktionsprinzip

### Die sechs Seiten

Die Seiten werden in dieser Reihenfolge durchlaufen:

| # | ID | Titel | Inhalt |
| :--- | :--- | :--- | :--- |
| 1 | `showtime` | - | Datum und Uhrzeit, letztere in 50 px |
| 2 | `showvehicle` | GRIGIO / Gast | Fahrzeugsymbol, Ladestand in Farbstufen, Restreichweite - oder Gastfahrzeug (siehe unten) |
| 3 | `showcharger` | WALLBOX | Wallbox-Symbol, grün beim Laden, «CHARGING» mit Ladeleistung oder «READY». Fällt ohne Fahrzeug aus der Rotation |
| 4 | `shownettopower` | SOLAR POWER | Solarpanel-Symbol, Wechselrichter-Eingangsleistung in W |
| 5 | `showbattery` | BATTERY | Batteriesymbol in fünf Stufen, SoC in %, Lade-/Entladeleistung |
| 6 | `show_weather` | - | Wetterlagensymbol, Zustandstext, Aussentemperatur, Regenstatus |

Der Ladestand des Fahrzeugs und der Füllstand der Hausbatterie sind die einzigen
Werte mit eigener Farb- bzw. Symbollogik:

Die **Hausbatterie** auf Seite 5 hat elf Symbolstufen in Zehnerschritten, von
`battery-outline` unter 10 % bis `battery` bei 100 %, und das Symbol trägt dazu
eine Farbe. Der Wert wird vorher auf 0 bis 100 begrenzt.

| Füllung | Glyph | Farbe |
| :--- | :--- | :--- |
| 100 % | `battery` | grün |
| 90 - 99 % | `battery-90` | grün |
| 80 - 89 % | `battery-80` | grün |
| 70 - 79 % | `battery-70` | hellgrün |
| 60 - 69 % | `battery-60` | hellgrün |
| 50 - 59 % | `battery-50` | gelb |
| 40 - 49 % | `battery-40` | gelb |
| 30 - 39 % | `battery-30` | orange |
| 20 - 29 % | `battery-20` | orange |
| 10 - 19 % | `battery-10` | hellrot |
| unter 10 % | `battery-outline` | hellrot |

Das **Fahrzeug** auf Seite 2 färbt seinen Ladestand gröber, ohne Gelb: ab 60 %
grün, ab 40 % hellgrün, ab 20 % orange, darunter hellrot.

Die Batterieleistung ist grün bei Ladung und rot bei Entladung, dort als
Absolutwert - das Vorzeichen steckt also in der Farbe, nicht in der Zahl.

### Die Fahrzeugseite

Am Kabel muss nicht Grigio hängen. Die Seite kennt darum vier Lagen, und die
**Reihenfolge der Abfragen ist entscheidend**:

| Lage | Anzeige |
| :--- | :--- |
| noch nichts bekannt | «VEHICLE», Symbol weiss, «LOADING...» |
| nichts angesteckt | «VEHICLE», Symbol grau, «NOT CONNECTED» |
| Erkennung läuft | «VEHICLE» grau, Symbol grau, «DETECTING ...» |
| Grigio erkannt | «GRIGIO» weiss, Ladestand in Farbstufen, Reichweite |
| fremdes Auto | Titel aus evcc in Orange, «GUEST», «no data» |

Die Unterscheidung läuft über `sensor.evcc_vehicle_name`: evcc kennt Grigio als
`db:1`, jeder andere Wert bedeutet ein fremdes Auto. Solange
`binary_sensor.evcc_vehicle_detection` läuft, ist der Name aber noch leer - würde
die Gastabfrage vorher greifen, stünde während jeder Erkennung fälschlich
«Gastfahrzeug» da. Für ein fremdes Auto liefert evcc weder Ladestand noch
Reichweite, deshalb «no data» statt einer Null.

**Hängt nichts am Kabel und läuft keine Erkennung, überspringt die Rotation diese
Seite und die Wallbox-Seite gleich mit.** Beide melden dann nur «NOT CONNECTED»,
das ist zweimal dieselbe Nichtaussage hintereinander. Über die Taster bleiben sie
erreichbar - wer nachsehen will, ob wirklich nichts angesteckt ist, kommt hin.

Zwei Feinheiten der Umsetzung im `interval`-Lambda: Es überspringt in einer
**Schleife**, weil die beiden Seiten nebeneinander liegen und ein einzelner
Extraschritt auf der zweiten stehenbliebe. Und die Bedingung verlangt
ausdrücklich `has_state()` - **«noch unbekannt» ist nicht «nichts angesteckt»**,
nach einem Neustart ohne Home Assistant bleiben also beide Seiten in der Rotation
und zeigen «LOADING...».

Jede Seite prüft ihre Leitgrösse mit `has_state()` und zeigt vor dem ersten Wert
«LOADING...». Seit V1.1.0 haben auch die Nebenwerte je eine eigene Prüfung und
zeigen sonst einen Platzhalter (`-- km`, `-- W`, `--.- °C`); die Uhrzeitseite
zeigt «NO TIME», solange Home Assistant noch keine Zeit geliefert hat.

### Die Wetterseite

Sie deckt alle fünfzehn Zustände ab, die `weather.egnach` liefern kann. Der
Vergleich läuft auf dem Originalzustand in Kleinbuchstaben; jeder Zustand bringt
ein Symbol, eine ein- oder zweizeilige Beschriftung und eine Farbe mit:

| Farbe | Zustände |
| :--- | :--- |
| gelb | `sunny`, `lightning`, `lightning-rainy` |
| blau | `rainy`, `pouring`, `snowy`, `snowy-rainy`, `hail` |
| grau | `cloudy`, `partlycloudy`, `clear-night`, `fog`, `windy`, `windy-variant` |
| orange | `exceptional` |

Vier Zustände werden zweizeilig gesetzt, weil der Text sonst nicht auf die Breite
passt: «PARTLY / CLOUDY», «SNOWY / RAIN», «CLEAR / NIGHT» und
«LIGHTNING / RAINY». Ab acht Zeichen wechselt die Beschriftung von `latoblack`
auf den schmaleren `latobold`, sonst stünde sie über den Rand hinaus.

Darunter die Aussentemperatur mit Thermometersymbol sowie «WET» mit der
Sensorfrequenz oder «DRY» aus der Regenerkennung der Wetterstation.

### Rotation und Bedienung

Ein `interval` von 5 s blättert eine Seite weiter, sofern das Global `rotate`
gesetzt ist. Ein voller Durchlauf dauert damit 30 Sekunden, ohne angestecktes
Fahrzeug 20 Sekunden - dann fallen Fahrzeug- und Wallbox-Seite aus der Rotation.

Das Global ist **bewusst nicht neustartfest**: Wer die Rotation per Langdruck
anhält, tut das für den Moment. Nach einem Neustart oder OTA läuft sie wieder -
wer das Gerät neu startet, will den Normalbetrieb.

Die beiden Taster des Boards liegen auf GPIO0 und GPIO35 und tragen je zwei
Funktionen, unterschieden über die Betätigungsdauer:

| Taster | Dauer | Funktion | Ereignis |
| :--- | :--- | :--- | :--- |
| links (GPIO0) | 1 - 1000 ms | eine Seite zurück | `press` |
| links (GPIO0) | 1001 - 5000 ms | Beleuchtung umschalten | `long_press` |
| rechts (GPIO35) | 1 - 1000 ms | eine Seite vor | `press` |
| rechts (GPIO35) | 1001 - 5000 ms | Rotation an/aus | `long_press` |

Technisch ist jede der vier Funktionen ein eigener, geräteinterner
`binary_sensor` auf demselben Pin, unterschieden über `min_length`/`max_length`
im `on_click`. Deshalb steht bei beiden Pins `allow_other_uses: true`. Jeder
Druck löst zusätzlich das passende Ereignis auf der zugehörigen `event`-Entität
aus. Eine Betätigung über 5 s löst nichts aus.

Das Display wird sekündlich neu gezeichnet (`update_interval: 1s`), zusätzlich
sofort bei jedem Blättern.

---

## 2. Hardware & Pinout (TTGO T-Display, ESP32 `esp32dev`)

| Pin | Funktion |
| :--- | :--- |
| GPIO18 | SPI CLK |
| GPIO19 | SPI MOSI |
| GPIO5 | Display CS |
| GPIO16 | Display DC |
| GPIO23 | Display Reset |
| GPIO4 | Hintergrundbeleuchtung, `ledc`-Ausgang (alleinige Belegung seit V1.1.0) |
| GPIO0 | Taster links, invertiert, interner Pull-up |
| GPIO35 | Taster rechts, invertiert (nur Eingang, Pull-up extern auf dem Board) |

**Display:** ST7789V, Modell `TTGO_TDISPLAY_135x240`, `rotation: 270°`. Panel
135x240 mit Offset 52/40, im Betrieb also 240x135 im Querformat. Der SPI-Bus hat
kein MISO - das Display wird nur beschrieben, nicht gelesen.

**Zum Bootloader:** Das Gerät wurde am 2026-08-23 einmal über Kabel geflasht
(`--device /dev/cu.usbserial-…`). ESPHome schreibt dabei das Factory-Image ab
Offset 0x0, also samt Bootloader; die NVS-Partition liegt laut Partitionstabelle
hinter beiden App-Partitionen und bleibt unberührt. Seither läuft ein aktueller
Bootloader (ESP-IDF v5.5.5), die frühere Startwarnung ist weg, und
`sram1_as_iram: true` gibt die vorher brachliegenden 40 kB IRAM frei. OTA
funktioniert danach unverändert.

**Zur Beleuchtung:** Das Modell bringt GPIO4 als `backlight_pin` selbst mit. Die
Konfiguration setzt deshalb `backlight_pin: false` - der Parameter nimmt laut
Schema auch einen Boolean -, damit der `ledc`-Ausgang den Pin allein besitzt und
die Dimmung wirkt. Weil das Display den Pin dadurch nicht mehr beim Start
einschaltet, trägt das Licht `restore_mode: RESTORE_DEFAULT_ON`. **Wer diese
Zeile entfernt, bekommt nach dem nächsten Flash einen dunklen Schirm.**

### Symbole und Schriften

**Das Gerät braucht keine Bilddateien.** Seit V1.1.0 sind alle Symbole Glyphen
aus `fonts/materialdesignicons-webfont.ttf`, die neben der YAML im Repo liegt
(Stand v7.4.47, Apache 2.0, Lizenztext in `fonts/LICENSE-materialdesignicons.txt`).
Die Konfiguration ist damit ohne weiteres Zutun baubar und hängt nicht mehr am
gemeinsamen Ordner `~/esphome/pic/`.

| Schrift | Grösse | `bpp` | Glyphen |
| :--- | :--- | :--- | :--- |
| `mdi80` | 80 | 4 | 3 Seitensymbole + 11 Batteriestufen + 15 Wetterlagen |
| `mdi30` | 30 | 4 | Thermometer, Nass, Trocken |

FreeType rendert direkt auf die Zielgrösse, es wird also nichts skaliert, und die
Farbe entsteht beim Zeichnen statt in der Datei. Der Preis ist, dass **ein Glyph
genau eine Farbe trägt** - bei Symbolen dieser Art fällt das nicht ins Gewicht.

**Schriften für Text:** vier Schnitte der Google-Font Lato (400 in 20 px, 700 in
24 px, 900 in 30 px und 50 px). Der 50-px-Schnitt `latoblackheading1` trägt die
Uhrzeit auf Seite 1.

---

## 3. Home Assistant Integration

### Vom Gerät bereitgestellt

| Entität | Bedeutung |
| :--- | :--- |
| `event.attic_ha_mini_display_button_left` | Taster links, Typen `press` und `long_press` |
| `event.attic_ha_mini_display_button_right` | Taster rechts, Typen `press` und `long_press` |
| `light.ha_mini_display_backlight` | dimmbare Hintergrundbeleuchtung |

Dazu die Diagnose-Entitäten aus `common/diagnostics.yaml` (Kategorien 2.x bis
6.x: WLAN, Netzwerk, System, Versionen, Neustart-Buttons). Sie tragen wie die
Ereignisse den Bereichspräfix `attic_` (siehe [OFFENE-PUNKTE.md](OFFENE-PUNKTE.md)).

### Vom Gerät konsumiert

Fünfzehn Entitäten, alle als `platform: homeassistant`:

| Entität | Verwendung |
| :--- | :--- |
| `sensor.evcc_vehicle_name` | Seite 2, Grigio (`db:1`) oder Gastfahrzeug |
| `sensor.evcc_vehicle_title` | Seite 2, Name des Gastfahrzeugs |
| `binary_sensor.evcc_vehicle_detection` | Seite 2, «DETECTING ...» und Rotationsentscheid |
| `sensor.evcc_vehicle_soc` | Seite 2, Ladestand Fahrzeug |
| `sensor.evcc_vehicle_range` | Seite 2, Restreichweite |
| `binary_sensor.evcc_loadpoint_connected` | Seite 2 und 3, Torbedingung «verbunden» |
| `binary_sensor.evcc_loadpoint_charging` | Seite 3, «CHARGING» oder «READY» |
| `sensor.evcc_charge_power_w` | Seite 3, Ladeleistung |
| `sensor.input_power` | Seite 4, Wechselrichter-Eingangsleistung |
| `sensor.battery_state_of_capacity` | Seite 5, Ladestand Hausbatterie |
| `sensor.charge_discharge_power` | Seite 5, Lade-/Entladeleistung |
| `weather.egnach` | Seite 6, Wetterzustand |
| `sensor.outdoor_temperature` | Seite 6, Aussentemperatur |
| `binary_sensor.raining` | Seite 6, WET/DRY |
| `sensor.weather_station_frequency` | Seite 6, Sensorfrequenz bei Nässe |

Dazu `time.homeassistant` als Zeitquelle für Seite 1. Es gibt keine RTC und
keinen SNTP-Fallback.

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

Gebaut wird in `~/esphome`, wo `secrets.yaml` und `common/` auflösbar sind:

```bash
PLATFORMIO_CORE_DIR="$HOME/.platformio_esphome" ~/.local/bin/esphome compile ha-mini-display.yaml
```

Geflasht wird über den mDNS-Namen statt über die Adresse, weil das Gerät keine
DHCP-Reservierung hat und schon einmal gewandert ist (siehe [OFFENE-PUNKTE.md](OFFENE-PUNKTE.md)):

```bash
PLATFORMIO_CORE_DIR="$HOME/.platformio_esphome" ~/.local/bin/esphome upload ha-mini-display.yaml --device ha-mini-display.local
```

Nach dem Flash ist nichts einzustellen - das Gerät bezieht alles aus Home
Assistant und beginnt mit der Rotation. Fällt das WLAN aus, spannt es den
Fallback-AP mit Captive Portal auf. Einen lokalen Webserver hat dieses Gerät
nicht.

---

## 5. Datenlast gegenüber Home Assistant

Die Richtung ist hier umgekehrt zu den übrigen Projekten: das Gerät ist
überwiegend Abonnent, nicht Melder. Es liest fünfzehn Entitäten und schreibt selbst
fast nichts.

Eigene Zeilen entstehen nur durch die beiden Ereignis-Entitäten - je Betätigung
eine statt der zwei Zustandswechsel, die die früheren Binärsensoren erzeugten -
sowie durch das Licht «Backlight» und die Diagnose-Entitäten aus
`common/diagnostics.yaml`. Diese melden dank ihrer Lambda-Filter nur bei echter
Änderung.

Für die Datenbank zählt ohnehin nur, was sich ändert: Home Assistant verwirft
unveränderte Wiederholungen im Recorder. Wer die tatsächliche Zeilenzahl wissen
will, misst sie über `total_count` je Entität in der Recorder-Historie, statt sie
aus dem Melde-Intervall zu schätzen.

Die sekündliche Neuzeichnung des Displays erzeugt **keine** Last in Home
Assistant - sie liest nur den lokal zwischengespeicherten Stand der abonnierten
Entitäten.

---

## 6. Offene Punkte

Was an diesem Gerät bekannt, aber nicht erledigt ist, steht in einem eigenen
Dokument: **[OFFENE-PUNKTE.md](OFFENE-PUNKTE.md)**. Dort ist zu jedem Punkt
festgehalten, worum es geht, was er praktisch bedeutet und was ihn schliessen
würde.

Die drei, die beim Lesen dieser README am ehesten stören:

* **Wie die Glyphen tatsächlich sitzen, ist nicht nachgemessen** - die
  Koordinaten stammen unverändert von den früheren Bildern (Punkt 1.1).
* **Ohne Home Assistant zeigt das Gerät nichts** und friert auf dem letzten Stand
  ein, ohne das kenntlich zu machen (Punkt 2.1).
* **Das Gerät hat keine DHCP-Reservierung** und ist schon einmal gewandert;
  deshalb wird über den mDNS-Namen geflasht (Punkt 3.1).
