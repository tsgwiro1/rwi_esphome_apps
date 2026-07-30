# wp-speicher-monitor - Schichtungsanzeige für den Wärmespeicher

![Version](https://img.shields.io/badge/version-1.0.0-blue)
[![ESPHome](https://img.shields.io/badge/ESPHome-Ready-03a9f4?logo=esphome&logoColor=white)](https://esphome.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ein ESP32 im Heizraum, der die Temperaturschichtung im Wärmespeicher sichtbar
macht. Vier DS18B20 über die Speicherhöhe verteilt liefern das Profil; daraus
leitet das Gerät ab, auf welcher Höhe die Sprungschicht zwischen warmem und
kaltem Wasser gerade liegt. Ein 2.4"-Display zeigt die vier Temperaturen als
Farbbalken samt Markierung der Schichtgrenze - ohne Blick in Home Assistant ist
so im Vorbeigehen erkennbar, wie viel nutzbare Wärme noch im Speicher steht.

---

## Haftungsausschluss (Disclaimer)

⚠️ **WICHTIGER HINWEIS: VERWENDUNG AUF EIGENE GEFAHR!** ⚠️

Dieses Projekt beschreibt ein privates Bastelprojekt zur Optimierung der eigenen
Hausautomatisierung. Die Nutzung, der Nachbau sowie das Einspielen des
bereitgestellten Codes und der Konfigurationen erfolgen ausdrücklich auf
**eigene Gefahr und eigenes Risiko**.

Der Autor übernimmt **keinerlei Haftung, Gewährleistung oder Verantwortung**
für:

* **Schäden jeglicher Art** an Elektronik, Speicher, Heizungsanlage oder
  anderen Komponenten der Haustechnik.
* Die Richtigkeit der **gemessenen Werte**. Die Fühler sitzen aussen an der
  Speicherwand bzw. in Tauchhülsen und messen nicht die Wassertemperatur direkt.
  Die angezeigten Werte sind eine Näherung und für keinerlei Abrechnung oder
  sicherheitsrelevante Entscheidung geeignet.
* **Fehlinterpretationen der Schichtungsanzeige.** Die erkannte Schichtgrenze
  ist eine Heuristik über vier Stützstellen (siehe Abschnitt 1) und kein
  physikalisch exaktes Modell.
* Die Richtigkeit, Aktualität oder Vollständigkeit des bereitgestellten Codes
  oder der Dokumentation.

Arbeiten an der Heizungsanlage und an Netzelektrik (230 V) dürfen nur von
ausgebildetem Fachpersonal ausgeführt werden.

---

## 1. Funktionsprinzip

### Vier Stützstellen über die Speicherhöhe

Vier DS18B20 sind von oben nach unten verteilt: **S1** oben (heisstes Wasser),
**S4** unten (kältestes). Alle hängen am selben 1-Wire-Bus und sind über ihre
ROM-Adresse fest zugeordnet - die Reihenfolge bleibt damit auch nach einem
Sensortausch oder Bus-Rescan erhalten.

Die Fühler werden alle 10 s gelesen und über ein gleitendes Mittel von 10 Werten
geglättet. Nach Home Assistant geht damit rund alle 100 s ein Wert. Für einen
Speicher, dessen Temperatur sich über Stunden ändert, ist das reichlich; die
schnellen Rohwerte braucht nur das lokale Display.

### Erkennung der Schichtgrenze

Ein gut geschichteter Speicher zeigt einen deutlichen Temperatursprung zwischen
zwei benachbarten Fühlern. Genau danach sucht der Sensor «Layer Position»:

1. Die Differenz jedes Nachbarpaars (S1/S2, S2/S3, S3/S4) wird gebildet.
2. Nur Differenzen **über 8 K** gelten als Sprungschicht - kleinere Abstände
   sind normaler Gradient und kein Übergang.
3. Von den qualifizierenden Paaren gewinnt das mit der grössten Differenz.
4. Ausgegeben wird, welches Paar gewonnen hat: **25 %** für S1/S2 (oberster
   Übergang), **50 %** für S2/S3, **75 %** für S3/S4 (unterster Übergang). Der
   Wert zählt also von oben nach unten - je kleiner, desto weiter oben steht die
   Sprungschicht und desto weniger nutzbare Wärme ist noch im Speicher.

Findet sich kein Sprung über 8 K, bleibt der Wert **0 %**. Das ist der ehrliche
Fall «keine Schichtung erkennbar» - der Speicher ist entweder durchgehend heiss,
durchgehend kalt oder durchmischt. Die tatsächliche Spreizung steht parallel im
Sensor «Highest Temp Difference», dort ist der Unterschied zwischen
«durchmischt» und «voll geladen» ablesbar.

Mehr als diese drei Stufen geben vier Stützstellen nicht her.

### Anzeige auf dem Display

Das 240x320-Display zeigt vier gestapelte Farbbalken, einen je Fühler, mit der
zugehörigen Temperatur daneben. Die Farbe kommt aus dem Script `calc_color`,
einer stückweise linearen Rampe:

| Temperatur | Farbe |
| :--- | :--- |
| unter 15 °C | Dunkelblau (0, 76, 153) |
| 15 - 23 °C | nach Reinblau (0, 0, 255) |
| 23 - 39 °C | nach Magenta, Rotanteil steigt |
| 39 - 65 °C | nach Reinrot (255, 0, 0) |
| 65 - 80 °C | nach Orange (255, 153, 0) |
| über 80 °C | Orange |

Links neben den Balken markiert ein Pfeil die erkannte Schichtgrenze. In der
Kopfzeile stehen Heizraum-Temperatur und -Feuchte sowie ein WLAN-Symbol, das nur
bei einem Signalpegel besser als −70 dBm erscheint. In der Fusszeile stehen
Datum und Uhrzeit, bezogen von Home Assistant.

### Hintergrundbeleuchtung

Ein LDR am ADC (GPIO34) schaltet die Beleuchtung: unter Rohwert 3900 ein, über
3950 aus. Die 50 Zähler Abstand sind die Hysterese, damit das Display in der
Dämmerung nicht im Sekundentakt blinkt. Der Sensor ist `internal: true` und
erscheint nicht in Home Assistant.

---

## 2. Hardware & Pinout (ESP32 `esp32dev`)

| Pin | Funktion |
| :--- | :--- |
| GPIO25 | 1-Wire-Bus, vier DS18B20 (S1 - S4), Pull-up 4.7 kΩ nach 3.3 V |
| GPIO5 | DHT (Heizraum-Temperatur und -Feuchte) |
| GPIO34 | LDR am ADC, Rohwert, nur Eingang |
| GPIO32 | Hintergrundbeleuchtung Display (GPIO-Output) |
| GPIO18 | SPI CLK |
| GPIO23 | SPI MOSI |
| GPIO19 | SPI MISO |
| GPIO14 | Display CS |
| GPIO27 | Display DC |
| GPIO33 | Display Reset |
| GPIO21 / GPIO22 | I²C SDA / SCL (Bus aktiv mit `scan: true`, aktuell ohne Teilnehmer) |

**Display:** ILI9xxx, Modell «TFT 2.4», 240x320, `rotation: 180`,
`color_palette: 8BIT`, 20 MHz Datenrate.

**Fühleradressen** (fest in der YAML hinterlegt):

| Sensor | Position | ROM-Adresse |
| :--- | :--- | :--- |
| S1 | oben | `0x150000001a1c4028` |
| S2 | | `0x4c00000017901028` |
| S3 | | `0x0c00000017988a28` |
| S4 | unten | `0x9700000018f3f128` |

Wird ein Fühler getauscht, muss die Adresse hier nachgezogen werden - sonst
bleibt der betreffende Sensor ohne Wert.

**Bildmaterial:** Die Icons (`pic/wlan.png`, `pic/hygrometer.png`,
`pic/thermometer.png`, `pic/arrow.png`) liegen wie bei den übrigen
Display-Projekten in `~/esphome/pic/` und sind nicht Teil dieses Repositories.

---

## 3. Home Assistant Integration

### Vom Gerät bereitgestellt

| Entität | Einheit | Bedeutung |
| :--- | :--- | :--- |
| `sensor.s1` … `sensor.s4` | °C | Speichertemperatur oben (S1) bis unten (S4) |
| `sensor.boiler_room_temperature` | °C | Raumtemperatur im Heizraum |
| `sensor.boiler_room_humidity` | % | Luftfeuchte im Heizraum |
| `sensor.layer_position` | % | Höhe der erkannten Schichtgrenze (0 / 25 / 50 / 75) |
| `sensor.highest_temp_difference` | °C | grösste Differenz zweier benachbarter Fühler |

Dazu die Diagnose-Entitäten aus `common/diagnostics.yaml` (Kategorien 2.x bis
6.x: WLAN, Netzwerk, System, Versionen, Neustart-Buttons).

### Vom Gerät konsumiert

* **`time.homeassistant`** - Datum und Uhrzeit für die Fusszeile des Displays.
  Fällt Home Assistant aus, bleibt die Zeitanzeige stehen; alles andere läuft
  unverändert weiter.

---

## 4. Secrets & Inbetriebnahme

Vier Einträge müssen in `~/esphome/secrets.yaml` stehen:

```yaml
speichermonitor_api_key: "…"                 # API-Verschlüsselung
speichermonitor_ota_key: "…"                 # OTA-Passwort
speichermonitor_fallback_ap_ssid: "…"        # Fallback-Hotspot
speichermonitor_fallback_ap_password: "…"
```

Dazu die gemeinsamen Einträge `wifi_ssid`, `wifi_password` sowie die von
`common/diagnostics.yaml` erwarteten `mac_bssid_ug`, `mac_bssid_eg` und
`mac_bssid_dg`.

Gebaut wird in `~/esphome`, wo `secrets.yaml`, `common/` und `pic/` auflösbar
sind:

```bash
PLATFORMIO_CORE_DIR="$HOME/.platformio_esphome" ~/.local/bin/esphome compile wp-speicher-monitor.yaml
```

Fällt das WLAN aus, spannt das Gerät den Fallback-AP mit Captive Portal auf. Der
lokale Webserver (Port 80, ohne OTA) zeigt alle Werte auch dann, wenn Home
Assistant nicht erreichbar ist.

---

## 5. Datenlast gegenüber Home Assistant

Die vier Speicherfühler melden durch das gleitende Mittel über 10 Werte nur alle
rund 100 s, die beiden DHT-Werte alle 60 s. Die zwei Template-Sensoren rechnen
zwar alle 10 s, ihr Ergebnis ist aber grobstufig - «Layer Position» kennt nur
vier mögliche Werte und schreibt deshalb selten eine neue Zeile.

Zu beachten bleibt der Unterschied zwischen Melderate und Datenbanklast: Home
Assistant verwirft unveränderte Wiederholungen im Recorder. Wer die tatsächliche
Zeilenzahl wissen will, misst sie über `total_count` je Entität in der
Recorder-Historie, statt sie aus dem Melde-Intervall zu schätzen.

---

## 6. Bekannte Punkte

* **Vier Stützstellen sind die Grenze der Auflösung.** Die Schichtgrenze lässt
  sich nur einem der drei Fühlerpaare zuordnen, nicht einer Höhe in Zentimetern.
  Wo genau innerhalb des Abschnitts der Übergang sitzt, bleibt offen.
* **Der 8-K-Schwellwert ist fest verdrahtet.** Bei einem Speicher mit flacherem
  Gradient meldet «Layer Position» dann durchgehend 0 %, obwohl eine Schichtung
  besteht. Der Wert steht als Konstante im Lambda und ist nicht aus Home
  Assistant heraus einstellbar.
* **Der I²C-Bus ist aktiv, aber unbenutzt.** `scan: true` auf GPIO21/22 läuft
  bei jedem Start mit, ohne dass ein Teilnehmer angeschlossen ist.
* **Kein Watchdog auf die Fühler.** Fällt ein DS18B20 aus, bleibt sein Wert in
  Home Assistant auf `unavailable`, das Display zeigt `nan`, und die
  Schichterkennung rechnet mit dem letzten in den Globals abgelegten Wert
  weiter.
* **Die Zeitanzeige hängt an Home Assistant.** Es gibt keine RTC und keinen
  SNTP-Fallback.
* **Erste 100 s nach dem Neustart ohne Anzeige.** Die Speicherfühler
  publizieren durch das gleitende Mittel über 10 Werte erst nach dem zehnten
  Messzyklus. Solange sind die Farb-Globals leer: schwarze Balken, `nan` als
  Temperatur, «Layer Position» rechnet auf Nullwerten.
