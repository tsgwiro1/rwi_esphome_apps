# wp-solar-monitor - Wärmemengenzähler für den Solarkreis

![Version](https://img.shields.io/badge/version-1.1.0-blue)
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
2. **Torbedingung:** Es wird nur weitergerechnet, wenn beide Fühler aktuell
   sind, die Pumpe läuft **und** ΔT über 0.5 K liegt. Damit zählt weder das
   Rauschen zweier Fühler bei stehender Anlage noch ein eingefrorener Messwert
   Energie.
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
* **Dichte und Wärmekapazität** hängen von der Temperatur ab und sind hier je
  ein Festwert über den ganzen Bereich. Das ist unkritischer als es klingt: für
  die Rechnung zählt nur ihr Produkt, und weil die Dichte mit der Temperatur
  fällt während die Wärmekapazität steigt, ändert sich dieses Produkt zwischen
  30 und 80 °C um **weniger als 1 %** (siehe Abschnitt 4). Ein Festwert genügt
  also - er muss nur stimmen.
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

### Fühler-Watchdog

Jeder gültige Messwert stempelt seinen Zeitpunkt in ein Global. Ein
10-Sekunden-Takt vergleicht diesen Stempel mit der Frist von **60 s** - das sind
sechs ausgelassene Meldungen bei einem Melderhythmus von 10 s - und erklärt den
Fühler danach für veraltet. Bewusst zeitgesteuert und nicht an `on_value`
gehängt: ein Fühler, der schlicht aufhört zu melden, löst dort nichts mehr aus.

Ist auch nur einer der beiden Fühler veraltet, geschieht dreierlei:

1. Die Wärmemengenrechnung hält an. Die Leistung geht auf 0, der Tageszähler
   bleibt stehen, statt auf einem eingefrorenen Temperaturwert weiterzuzählen.
2. Das Display zeigt an der Stelle der Temperatur `--.-°C` statt `nan`.
3. Der Binärsensor «1.3 Fuehler Watchdog» (`device_class: problem`) meldet nach
   Home Assistant.

In den ersten 60 s nach einem Neustart meldet der Watchdog grundsätzlich nichts
- bis zur ersten Frist ist das Fehlen von Werten normal und kein Defekt.

Das schliesst nicht jede Lücke: Der gleitende Mittelwert verwirft einzelne
NaN-Werte und liefert selbst nur dann NaN, wenn **alle** Werte im Fenster NaN
sind. Ein Fühler, der bloss sporadisch fehlschlägt, meldet also weiter - er
liefert dann einen Mittelwert aus weniger Stützstellen, was ein echter, aktueller
Messwert bleibt. Der Watchdog greift beim Totalausfall, nicht beim Wackelkontakt.

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

**Display:** ST7789V über `mipi_spi`, 240x280 mit Zeilenversatz 20,
`rotation: 90`, `color_depth: "8"`, `invert_colors: true`, 20 MHz, Neuzeichnung
alle 5 s. Der SPI-Bus hat kein MISO - das Display wird nur beschrieben, nicht
gelesen.

`mipi_spi` kennt dieses Adafruit-Panel nicht als fertiges Modell. Grösse und
Zeilenversatz stehen deshalb von Hand in der YAML; die Werte stammen aus dem
Legacy-Modell `ADAFRUIT_RR_280X240`. `invert_colors: true` bildet nach, dass der
alte Treiber `INVON` fest verdrahtet schickte.

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
| `binary_sensor.infrastructure_wp_solar_monitor_1_3_fuehler_watchdog` | - | meldet einen veralteten Fühler, `device_class: problem` |
| `button.wp_solar_monitor_1_0_reset_counters` | - | Energie und Laufzeit von Hand nullen |

Einstellbare Anlagenparameter, alle neustartfest und in der Kategorie `config`:

| Entität | Bereich | Schritt |
| :--- | :--- | :--- |
| `number.wp_solar_monitor_durchfluss` | 0 - 10 l/min | 0.1 |
| `number.wp_solar_monitor_spez_dichte` | 960 - 1060 kg/m³ | 1 |
| `number.wp_solar_monitor_spez_w_rmekap` | 3.40 - 4.00 kJ/kg°K | 0.01 |

Der Watchdog trägt als einzige Entität das Bereichspräfix `infrastructure_` -
Home Assistant stellt es neu angelegten Entitäten voran. Die übrigen stammen aus
der Zeit davor und behalten ihre kürzere ID.

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

### Anlagenparameter

Der Kreis ist mit **TYFOCOR® LS** gefüllt, einem gebrauchsfertigen
Propylenglykol-Wasser-Gemisch für Vakuumröhren-Kollektoren, Frostschutz bis
−28 °C. Aus der Herstellertabelle (technisches Datenblatt, Thermophysikalische
Eigenschaften):

| T [°C] | Dichte [kg/m³] | c_p [kJ/kg·K] | Produkt [kJ/m³·K] |
| ---: | ---: | ---: | ---: |
| 30 | 1029 | 3.640 | 3746 |
| 40 | 1021 | 3.680 | 3757 |
| 50 | 1015 | 3.720 | 3776 |
| 60 | 1008 | 3.760 | 3790 |
| 70 | 1001 | 3.800 | 3804 |
| 80 | 993 | 3.840 | 3813 |

Eingestellt sind seit dem 2026-09-02 die Werte der 60-°C-Zeile als
repräsentative Kreismitteltemperatur: **Dichte 1008 kg/m³**, **Wärmekapazität
3.76 kJ/kg°K**. Welche Zeile zwischen 30 und 80 °C man nimmt, ändert das
Ergebnis um unter 1 %.

Der **Durchfluss** bleibt bei 8.0 l/min und stammt vom Durchflussanzeiger der
Solarstation - er ist der einzige der drei Werte, der weiterhin auf einer
Ablesung statt auf einem Datenblatt beruht.

Wird der Wärmeträger einmal gewechselt, gehören Dichte und Wärmekapazität aus
dem Datenblatt des neuen Mediums nachgezogen; beide gehen linear in jede
ausgewiesene Wattstunde ein.

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
* **Werte vor dem 2026-09-02 sind um rund 14 % zu niedrig.** Bis dahin standen
  Dichte und Wärmekapazität auf 960 kg/m³ und 3.40 kJ/kg°K - beides der untere
  Anschlag des jeweiligen Eingabefelds und kein Betriebspunkt von TYFOCOR LS
  (960 kg/m³ erreicht das Medium erst bei etwa 120 °C, 3.40 kJ/kg°K erst bei
  −20 °C). Das Produkt lag damit bei 3264 statt 3790 kJ/m³·K. Wer ältere
  Tagesbilanzen mit neueren vergleicht, muss die alten mit **1.16**
  multiplizieren. Die Korrektur brauchte keinen Flash, die Werte liegen im
  NVS.
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
* **Der Watchdog greift beim Totalausfall, nicht beim Wackelkontakt.** Ein
  Fühler, der nur sporadisch fehlschlägt, liefert über den gleitenden Mittelwert
  weiter Werte und gilt damit als gesund. Das ist vertretbar - der gemeldete
  Wert bleibt ein echter, aktueller Messwert -, aber ein Sensor mit
  schlechter Klemme fällt so nicht auf.
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
* **Die Panelgeometrie steht von Hand in der YAML.** Weil `mipi_spi` das
  Adafruit-Panel nicht als Modell kennt, sind 240x280 und der Zeilenversatz 20
  eingetippte Werte. Ein Tippfehler dort verschiebt das ganze Bild, ohne dass
  die Validierung etwas merkt.
* **Kein OTA-Rollback.** Das Gerät meldet beim Start «Bootloader too old for OTA
  rollback and SRAM1 as IRAM (+40KB)». Der Bootloader stammt aus der
  Erstinbetriebnahme und kann nur per USB erneuert werden. Praktische Folge: ein
  fehlerhaftes OTA fällt nicht automatisch auf die vorige Firmware zurück,
  sondern muss über den Fallback-AP oder per Kabel gerettet werden. Ausserdem
  bleiben 40 kB IRAM ungenutzt - bei aktuell 27.9 % RAM-Auslastung kein Problem.
* **Ein Gesamtzähler fehlt.** Es gibt nur den Tageswert; die Jahresbilanz
  entsteht erst in Home Assistant aus der Statistik der Energie-Entität.
