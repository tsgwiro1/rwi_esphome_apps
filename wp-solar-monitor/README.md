# wp-solar-monitor - Wärmemengenzähler für den Solarkreis

![Version](https://img.shields.io/badge/version-1.0.0-blue)
[![ESPHome](https://img.shields.io/badge/ESPHome-Ready-03a9f4?logo=esphome&logoColor=white)](https://esphome.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ein ESP32 am Solarkreis, der aus zwei Temperaturfühlern und dem Kontakt der
Solarpumpe die eingetragene Wärmemenge rechnet. Vorlauf und Rücklauf ergeben die
Spreizung, der Pumpenkontakt sagt, ob überhaupt Wasser fliesst - daraus wird
alle 5 Sekunden eine Energie-Zeitscheibe gebildet und über den Tag summiert. Ein
2.8"-Display zeigt das Anlagenschema mit den aktuellen Temperaturen, der
Momentanleistung, der Tagesenergie und der Pumpenlaufzeit, sodass der Ertrag im
Vorbeigehen ablesbar ist.

Wichtig zum Verständnis: **der Durchfluss wird nicht gemessen, sondern von Hand
eingestellt.** Das Gerät ist ein Ertrags-Indikator, kein Messgerät.

---

## Haftungsausschluss (Disclaimer)

⚠️ **WICHTIGER HINWEIS: VERWENDUNG AUF EIGENE GEFAHR!** ⚠️

Dieses Projekt beschreibt ein privates Bastelprojekt zur Optimierung der eigenen
Hausautomatisierung. Die Nutzung, der Nachbau sowie das Einspielen des
bereitgestellten Codes und der Konfigurationen erfolgen ausdrücklich auf
**eigene Gefahr und eigenes Risiko**.

Der Autor übernimmt **keinerlei Haftung, Gewährleistung oder Verantwortung**
für:

* **Schäden jeglicher Art** an Elektronik, Solarkreis, Heizungsanlage oder
  anderen Komponenten der Haustechnik.
* Die Richtigkeit der **ausgewiesenen Wärmemenge und Leistung.** Der Durchfluss
  ist ein von Hand eingegebener Festwert, die Fühler sitzen an der Rohrwand und
  nicht im Medium. Die Werte sind eine Näherung und für **keinerlei Abrechnung,
  Förderungsnachweis oder Ertragsgarantie** geeignet (siehe Abschnitt 1 und 6).
* **Fehlinterpretationen der Anzeige.** Eine hohe angezeigte Leistung ist kein
  Nachweis, dass die Anlage korrekt arbeitet.
* Die Richtigkeit, Aktualität oder Vollständigkeit des bereitgestellten Codes
  oder der Dokumentation.

Arbeiten an der Heizungsanlage und an Netzelektrik (230 V) dürfen nur von
ausgebildetem Fachpersonal ausgeführt werden.

---

## 1. Funktionsprinzip

### Die drei Eingangsgrössen

| Grösse | Herkunft |
| :--- | :--- |
| Vorlauftemperatur | DS18B20 am 1-Wire-Bus, feste ROM-Adresse |
| Rücklauftemperatur | DS18B20 am selben Bus, feste ROM-Adresse |
| «fliesst Wasser?» | Kontakt der Solarpumpe an GPIO5 |

Die Fühler werden alle 5 s gelesen und über ein gleitendes Mittel von zwei
Werten geglättet, nach Home Assistant geht damit alle 10 s ein Wert. Die
Zuordnung über die ROM-Adresse hält die Reihenfolge auch nach einem Bus-Rescan
oder Sensortausch stabil.

### Die Wärmemengenrechnung

Das Script `calculate_energy` läuft alle 5 s, getaktet von einer
`on_time`-Automation auf `seconds: /5`. Es rechnet in vier Schritten:

1. **Spreizung:** ΔT = Vorlauf − Rücklauf, negative Werte auf 0 begrenzt.
2. **Torbedingung:** Es wird nur weitergerechnet, wenn die Pumpe läuft **und**
   ΔT über 0.5 K liegt. Damit zählt das Rauschen zweier Fühler bei stehender
   Anlage keine Energie.
3. **Masse der Zeitscheibe:** Aus dem eingestellten Durchfluss (l/min) wird die
   in 5 s umgewälzte Menge und über die eingestellte Dichte deren Masse in kg.
4. **Energie:** Masse × ΔT × spezifische Wärmekapazität ergibt kJ, umgerechnet
   nach Wh mit dem Faktor 0.277778.

Das Ergebnis wird auf den Tageszähler addiert; parallel wird die Zeitscheibe auf
eine Stunde hochgerechnet und ergibt die Momentanleistung. Liegt die
Torbedingung nicht an, ist die Leistung 0 und der Tageszähler bleibt stehen.

Der Tageszähler liegt in einem neustartfesten Global mit NaN-Schutz: liest das
Gerät beim Start einen unbrauchbaren Wert aus dem NVS, beginnt es bei 0 statt mit
`nan` weiterzurechnen.

### Was diese Rechnung wert ist

Drei der vier Faktoren sind Annahmen, keine Messwerte:

* **Der Durchfluss ist ein Handeingabewert.** Er stammt aus dem Datenblatt der
  Pumpe bzw. vom Durchflussanzeiger der Solarstation, nicht von einem Sensor am
  Bus. Ändert die Pumpe ihre Stufe oder verschlammt der Kreis, rechnet das Gerät
  unverändert mit dem alten Wert weiter. Die ausgewiesene Energie skaliert
  **linear** mit dieser Zahl.
* **Dichte und Wärmekapazität** hängen von der Glykolkonzentration und der
  Temperatur ab und sind hier je ein Festwert über den ganzen Temperaturbereich.
  Auch sie gehen linear ein.
* **Die Temperaturen** werden an der Rohrwand gemessen, nicht im Medium.

Ein Fehler von 10 % beim Durchfluss ist damit direkt ein Fehler von 10 % beim
Tagesertrag. Für die Frage «läuft die Anlage, und ist heute mehr oder weniger
zusammengekommen als gestern» reicht das gut; als Messgerät taugt es nicht.

### Anzeige auf dem Display

Das 280x240-Display zeigt eine Titelzeile «SOLAR» mit WLAN-Symbol - dieses
erscheint nur bei einem Signalpegel besser als −70 dBm - und darunter das
Anlagenschema als Hintergrundbild. Darüber liegen:

| Anzeige | Inhalt |
| :--- | :--- |
| Pumpensymbol | grün bei laufender, grau bei stehender Pumpe |
| rote Zahl | Vorlauftemperatur |
| blaue Zahl | Rücklauftemperatur |
| ON / OFF | Zustand des Pumpenkontakts |
| grün, oben rechts | Tagesenergie, ab 1000 automatisch in kWh |
| grün, links | Momentanleistung, ab 1000 automatisch in kW |
| unten | Pumpenlaufzeit des Tages als `hh:mm:ss` |

Die Positionen sind auf das Hintergrundbild abgestimmte Festkoordinaten. Wird
das Schemabild getauscht, müssen die Koordinaten im Display-Lambda nachgezogen
werden.

### Hintergrundbeleuchtung

Ein LDR am ADC (GPIO34) schaltet die Beleuchtung: unter Rohwert 3900 ein, über
3950 aus. Die 50 Zähler Abstand sind die Hysterese, damit das Display in der
Dämmerung nicht im Sekundentakt blinkt. Der Sensor ist `internal: true` und
erscheint nicht in Home Assistant.

### Tagesreset

Um 00:00:00 werden Energiezähler und Pumpenlaufzeit auf 0 gesetzt. Beide
Entitäten sind damit Tageswerte. Derselbe Reset liegt auf dem Button «1.0 Reset
Counters» für den Eingriff von Hand.

---

## 2. Hardware & Pinout (ESP32 `esp32dev`)

| Pin | Funktion |
| :--- | :--- |
| GPIO25 | 1-Wire-Bus, zwei DS18B20 (Vorlauf, Rücklauf), Pull-up 4.7 kΩ nach 3.3 V |
| GPIO5 | Kontakt Solarpumpe, Eingang mit internem Pulldown |
| GPIO34 | LDR am ADC, Rohwert, nur Eingang |
| GPIO32 | Hintergrundbeleuchtung Display (GPIO-Output) |
| GPIO18 | SPI CLK |
| GPIO23 | SPI MOSI |
| GPIO14 | Display CS |
| GPIO27 | Display DC |
| GPIO33 | Display Reset |

**Display:** ST7789V, Modell «Adafruit RR 280x240», `rotation: 90`,
`eightbitcolor: true`. Der SPI-Bus hat kein MISO - das Display wird nur
beschrieben, nicht gelesen.

**Fühleradressen** (fest in der YAML hinterlegt):

| Sensor | Position | ROM-Adresse |
| :--- | :--- | :--- |
| `vl` | Vorlauf (Kollektor → Speicher) | `0x8d00000019d27c28` |
| `rl` | Rücklauf (Speicher → Kollektor) | `0x43000000196fe828` |

Wird ein Fühler getauscht, muss die Adresse hier nachgezogen werden - sonst
bleibt der betreffende Sensor ohne Wert und die Energierechnung steht still
(siehe Abschnitt 6).

**Bildmaterial:** Die Grafiken (`pic/wlan.png`, `pic/solar_schema_no_pump3.png`,
`pic/pump_green.png`, `pic/pump_gray.png`) liegen wie bei den übrigen
Display-Projekten in `~/esphome/pic/` und sind nicht Teil dieses Repositories.

---

## 3. Home Assistant Integration

### Vom Gerät bereitgestellt

| Entität | Einheit | Bedeutung |
| :--- | :--- | :--- |
| `sensor.wp_solar_monitor_vorlauf` | °C | Vorlauftemperatur |
| `sensor.wp_solar_monitor_ruecklauf` | °C | Rücklauftemperatur |
| `sensor.wp_solar_monitor_power` | W | Momentanleistung (`measurement`) |
| `sensor.wp_solar_monitor_energy_today` | Wh | Tagesenergie (`total_increasing`) |
| `sensor.wp_solar_monitor_1_1_pump_runtime_today` | s | Pumpenlaufzeit des Tages |
| `sensor.wp_solar_monitor_1_2_pump_last_turn_on` | s | letzte Einschaltung der Pumpe |
| `binary_sensor.wp_solar_monitor_pumpe` | - | Pumpenkontakt, `device_class: running` |
| `button.wp_solar_monitor_1_0_reset_counters` | - | Energie und Laufzeit von Hand nullen |

Einstellbare Anlagenparameter, alle neustartfest und in der Kategorie `config`:

| Entität | Bereich | Schritt |
| :--- | :--- | :--- |
| `number.wp_solar_monitor_durchfluss` | 0 - 10 l/min | 0.1 |
| `number.wp_solar_monitor_spez_dichte` | 960 - 1060 kg/m³ | 1 |
| `number.wp_solar_monitor_spez_w_rmekap` | 3.40 - 4.00 kJ/kg°K | 0.01 |

Dazu die Diagnose-Entitäten aus `common/diagnostics.yaml` (Kategorien 2.x bis
6.x: WLAN, Netzwerk, System, Versionen, Neustart-Buttons).

### Vom Gerät konsumiert

* **`time.homeassistant`** - dreifach eingebunden: als Zeitquelle, als 5-s-Takt
  für die Energierechnung und für den Mitternachtsreset. Das ist die einzige
  echte Abhängigkeit, und sie ist hart: **ohne Home Assistant zählt das Gerät
  keine Energie** (siehe Abschnitt 6).

---

## 4. Secrets & Inbetriebnahme

Vier Einträge müssen in `~/esphome/secrets.yaml` stehen:

```yaml
solarmonitor_api_key: "…"                 # API-Verschlüsselung
solarmonitor_ota_key: "…"                 # OTA-Passwort
solarmonitor_fallback_ap_ssid: "…"        # Fallback-Hotspot
solarmonitor_fallback_ap_password: "…"
```

Dazu die gemeinsamen Einträge `wifi_ssid`, `wifi_password` sowie die von
`common/diagnostics.yaml` erwarteten `mac_bssid_ug`, `mac_bssid_eg` und
`mac_bssid_dg`.

Gebaut wird in `~/esphome`, wo `secrets.yaml`, `common/` und `pic/` auflösbar
sind:

```bash
PLATFORMIO_CORE_DIR="$HOME/.platformio_esphome" ~/.local/bin/esphome compile wp-solar-monitor.yaml
```

Nach der Montage sind die drei `number`-Entitäten einzustellen, bevor die
Energiewerte etwas bedeuten: Durchfluss laut Durchflussanzeiger der
Solarstation, Dichte und Wärmekapazität passend zur Glykolkonzentration des
Kreises.

Fällt das WLAN aus, spannt das Gerät den Fallback-AP mit Captive Portal auf. Der
lokale Webserver (Port 80, ohne OTA) zeigt die Temperaturen und den Pumpenstatus
auch dann, wenn Home Assistant nicht erreichbar ist - die Energiewerte stehen
dort allerdings still.

---

## 5. Datenlast gegenüber Home Assistant

Die beiden Temperaturfühler melden durch das gleitende Mittel alle 10 s, die
beiden Template-Sensoren «Power» und «Energy today» ebenfalls alle 10 s. Der
Pumpen-Binärsensor meldet nur bei Flanken, also zweimal pro Sonnenphase.

Für die Datenbank zählt davon aber nur, was sich ändert: Home Assistant verwirft
unveränderte Wiederholungen im Recorder. Bei stehender Pumpe steht «Power»
konstant auf 0 und «Energy today» auf dem letzten Wert - dann entsteht trotz
10-s-Takt keine Zeile. Läuft die Pumpe, ändern sich beide fast bei jeder Meldung,
das sind rund 360 Zeilen pro Stunde und Entität.

Wer die tatsächliche Zeilenzahl wissen will, misst sie über `total_count` je
Entität in der Recorder-Historie, statt sie aus dem Melde-Intervall zu schätzen.

---

## 6. Bekannte Punkte

* **Der Durchfluss ist der grösste Unsicherheitsfaktor.** Ein Handeingabewert
  geht linear in jede ausgewiesene Wattstunde ein. Ein Volumenstromsensor im
  Solarkreis wäre der eine Umbau, der aus dem Indikator ein Messgerät machen
  würde.
* **Zwei der drei Parameter stehen am unteren Anschlag ihres Bereichs**
  (Stand 2026-07-30: Dichte 960 kg/m³ bei einem Bereich ab 960, Wärmekapazität
  3.40 kJ/kg°K bei einem Bereich ab 3.40, Durchfluss 8.0 l/min). Ob das gewollt
  ist oder ein nie angepasster Startwert, ist aus der Konfiguration nicht
  ersichtlich - beide Werte gehören gegen die tatsächliche Glykolmischung
  geprüft.
* **Ohne Home Assistant zählt das Gerät keine Energie.** Alle drei
  Zeit-Instanzen sind `platform: homeassistant`. Ist HA nicht erreichbar, feuert
  der 5-s-Takt nicht: Leistung und Tagesenergie bleiben stehen, und der
  Mitternachtsreset fällt aus. Temperaturen, Pumpenstatus und Display laufen
  weiter. Es gibt keine RTC und keinen SNTP-Fallback.
* **Der 5-Sekunden-Takt steht an drei Stellen in der YAML** - im `on_time` und
  zweimal als Konstante im Lambda (Massenberechnung und Hochrechnung auf die
  Leistung). Wer den Takt ändert und das Lambda nicht nachzieht, bekommt still
  falsche Zahlen statt einer Fehlermeldung.
* **Der Schwellwert von 0.5 K ist fest verdrahtet.** Ertrag bei kleinerer
  Spreizung - typisch am frühen Morgen und späten Abend - wird nicht gezählt.
  Das ist der Preis dafür, dass Fühlerrauschen keine Phantomenergie erzeugt.
* **Ein ausgefallener Fühler stoppt die Zählung, statt zu lügen.** Fällt ein
  DS18B20 aus, ist die Spreizung `nan`, die Torbedingung damit nie erfüllt: die
  Leistung geht auf 0 und der Tageszähler bleibt stehen. Das Display zeigt
  `nan`. Ein Watchdog, der diesen Zustand nach HA meldet, fehlt - der Ausfall
  sieht von aussen aus wie eine stehende Anlage.
* **Der Tageszähler schreibt regelmässig ins NVS.** Als neustartfestes Global
  wird er sekündlich auf Änderung geprüft und bei Änderung gespeichert, während
  Pumpenlauf also etwa alle 5 s - rund 720 Schreibvorgänge je Betriebsstunde,
  dazu die Sicherung des `duty_time`-Zählers. Das NVS verteilt die Zugriffe über
  Wear-Levelling; ein Problem ist bisher nicht aufgetreten, aber es ist die
  einzige Stelle dieser Konfiguration mit nennenswerter Flash-Last.
* **Die Sensornamen folgen nicht dem Nummernschema** der übrigen Projekte:
  «Vorlauf», «Ruecklauf», «Energy today» und «Power» stehen ohne `1.x`-Präfix
  neben «1.1 Pump runtime today». Eine Umbenennung würde die Entity-IDs in Home
  Assistant ändern und alle Verweise darauf brechen, deshalb bleibt es so.
* **Die Schriftart `robo12` ist definiert, aber im Display-Lambda unbenutzt.**
  Sie belegt nur Flash.
* **Die Display-Plattform `st7789v` ist ab ESPHome 2026.7 als deprecated
  markiert** und verweist auf `mipi_spi`. Sie ist dort noch der eigenständige
  Legacy-Treiber und funktioniert unverändert - die `mipi_spi`-Regression, die
  `wp-fp1-smartblock` auf 2026.5.3 festhält, betrifft dieses Gerät also nicht.
  Der Wechsel auf `mipi_spi` wird aber irgendwann fällig, und dann sind
  Farbformat und Offsets neu zu prüfen.
* **Kein OTA-Rollback.** Das Gerät meldet beim Start «Bootloader too old for OTA
  rollback and SRAM1 as IRAM (+40KB)». Der Bootloader stammt aus der
  Erstinbetriebnahme und kann nur per USB erneuert werden. Praktische Folge: ein
  fehlerhaftes OTA fällt nicht automatisch auf die vorige Firmware zurück,
  sondern muss über den Fallback-AP oder per Kabel gerettet werden. Ausserdem
  bleiben 40 kB IRAM ungenutzt - bei aktuell 27.9 % RAM-Auslastung kein Problem.
* **Ein Gesamtzähler fehlt.** Es gibt nur den Tageswert; die Jahresbilanz
  entsteht erst in Home Assistant aus der Statistik der Energie-Entität.
