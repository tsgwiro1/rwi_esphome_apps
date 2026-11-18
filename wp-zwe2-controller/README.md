# wp-zwe2-controller - PV-geführter Heizstab im Wärmespeicher

![Version](https://img.shields.io/badge/version-1.2.0-blue)
[![ESPHome](https://img.shields.io/badge/ESPHome-Ready-03a9f4?logo=esphome&logoColor=white)](https://esphome.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ein ESP32, der den zweiten Wärmeerzeuger der Wärmepumpenanlage - einen Heizstab
von 4.5 kW im Wärmespeicher - stufenlos dem PV-Überschuss nachfährt. Alle
5 Sekunden wird aus Zählerwirkleistung, Batterieentladung und einer
Mindestreserve der verfügbare Überschuss gerechnet und als Sollwert von 0 bis
100 % über den DAC des ESP32 an ein 0-10-V-Leistungsmodul gegeben. Vier
Verriegelungen nehmen die Leistung bedingungslos auf 0, ein Override fährt
Volllast. Ein LED-Board im Schaltschrank zeigt Leistungsbalken, Übertemperatur,
Modulspannung und WLAN-Status, sodass der Betriebszustand ohne Home Assistant
ablesbar ist.

Der Zweck ist nicht Wärme, sondern **Eigenverbrauch**: Strom, der sonst zu
Einspeisetarifen ins Netz ginge, wird stattdessen in den Speicher gelegt.
Entsprechend gibt der Heizstab immer nur so viel Leistung, wie gerade wirklich
übrig ist.

---

## Haftungsausschluss (Disclaimer)

⚠️ **WICHTIGER HINWEIS: VERWENDUNG AUF EIGENE GEFAHR!** ⚠️

Dieses Projekt beschreibt ein privates Bastelprojekt zur Optimierung der eigenen
Hausautomatisierung. Die Nutzung, der Nachbau sowie das Einspielen des
bereitgestellten Codes und der Konfigurationen erfolgen ausdrücklich auf
**eigene Gefahr und eigenes Risiko**.

Der Autor übernimmt **keinerlei Haftung, Gewährleistung oder Verantwortung**
für:

* **Schäden jeglicher Art** an Elektronik, Heizstab, Wärmespeicher,
  Leistungsmodul oder anderen Komponenten der Haustechnik.
* **Überhitzung des Speichers oder des Leistungsmoduls.** Die hier
  beschriebenen Verriegelungen sind Komfort- und Betriebsfunktionen einer
  Bastelsteuerung, **kein Sicherheitssystem**. Ein Heizstab braucht einen
  eigenen, von dieser Steuerung unabhängigen mechanischen
  Sicherheitstemperaturbegrenzer (STB) und eine korrekte Absicherung. Siehe
  Abschnitt 6.
* **Fehlinterpretationen der Anzeige** am LED-Board oder in Home Assistant.
* Die Richtigkeit, Aktualität oder Vollständigkeit des bereitgestellten Codes
  oder der Dokumentation.

Arbeiten an der Heizungsanlage und an Netzelektrik (230 V / 400 V) dürfen nur
von ausgebildetem Fachpersonal ausgeführt werden. Ein Heizstab von 4.5 kW ist
kein Kleinverbraucher.

---

## 1. Funktionsprinzip

### Die Eingangsgrössen

| Grösse | Herkunft |
| :--- | :--- |
| Netzwirkleistung | `sensor.grid_active_power` aus Home Assistant, positiv = Einspeisung |
| Batterieentladung | `sensor.charge_discharge_power`, es zählt nur der negative Anteil |
| Speichertemperatur oben | `sensor.s1`, kommt vom Schwesterprojekt `wp-speicher-monitor` |
| Gültigkeit von S1 | Fühler-Watchdog von `wp-speicher-monitor` |
| Ersatz-Speichertemperatur | `sensor.wp_temperatur_warmwasser` aus der `luxtronik`-Integration |
| Tatsächliche Heizstableistung | `sensor.heizstab`, nur für die Rückmeldung |
| Kühlkörpertemperatur | DS18B20 am 1-Wire-Bus des Geräts, feste ROM-Adresse |
| Modulspannung vorhanden | Rückmeldekontakt des Leistungsmoduls an GPIO33 |

Sechs der acht Grössen kommen also über die API aus Home Assistant, zwei sind
lokal verdrahtet. Das ist die zentrale Eigenschaft dieser Steuerung: **die
Regelgrösse ist nicht messbar am Gerät**, sie muss aus dem Hausnetz kommen.

### Die Überschussrechnung

Jeder eintreffende Zählerwert wird in einem Global abgelegt, und dabei passiert
der wichtigste Trick dieser Konfiguration:

```
solar_power = Zählerwert + (aktuelle Ansteuerung × Heizstableistung)
```

Die Eigenaufnahme des Heizstabs wird also **zurückaddiert**. Ohne das würde die
Regelung sich selbst aussteuern: Heizstab an → Einspeisung sinkt → Überschuss
scheinbar weg → Heizstab aus → Einspeisung steigt → wieder an. Mit der
Rückaddition rechnet das Gerät mit dem Überschuss, der *ohne* den Heizstab
anliegen würde, und findet damit einen stabilen Arbeitspunkt. Im Override-Modus
entfällt die Rückaddition, weil dort ohnehin nicht geregelt wird.

Von der Batterie zählt nur die Entladung. Sie wird abgezogen, damit der Heizstab
nicht den Hausspeicher leer zieht. Das Laden der Batterie wird nicht behandelt
und muss es auch nicht: was in die Batterie geht, steht im Zählerwert schon
nicht mehr als Einspeisung. **Die Batterieladung hat damit implizit Vorrang vor
dem Heizstab.**

### Die Regelschleife

Das Script `set_Power` läuft alle 5 s, getaktet von einer `on_time`-Automation
auf `seconds: /5`. Es arbeitet in dieser Reihenfolge:

1. **Speicherverriegelung neu bewerten** (Script `eval_boiler`, siehe
   «Speicherladung»).
2. **Verriegelungen prüfen.** Ist eine davon aktiv, wird die Ansteuerung auf 0 %
   gesetzt und der Rest übersprungen:

   | Verriegelung | Bedingung |
   | :--- | :--- |
   | Übertemperatur Modul | Kühlkörper ≥ «Tmax Module» |
   | Speicher geladen | siehe «Speicherladung», auch ohne gültige Temperatur |
   | Keine Modulspannung | Eingang GPIO33 low |
   | Hauptschalter aus | «Main Power On-Off» off |

3. **Override?** Wenn ja, Ansteuerung 100 %.
4. **Netzwert zu alt?** Ist seit 300 s (`grid_timeout_s`) kein neuer Zählerwert
   eingetroffen, Ansteuerung 0 % mit Warnung im Log. Der Zähler meldet im
   Mittel alle 32 s, die grösste Lücke in 7 Tagen waren 150 s. Bleibt Home
   Assistant ganz weg, greift dieselbe Frist, weil dann auch der Zählerwert
   stehen bleibt. Der Override ist davon ausgenommen, er nutzt den Überschuss
   nicht.
5. **Sonst regeln:**
   `pwr = max(Überschuss − «Power Solar Min» − Batterieentladung, 0)`,
   dann `out = min(pwr / «Power Heater», 1.0)`.
6. **Mindestansteuerung:** Liegt `out` unter «Min Heater Output», wird auf 0 %
   gesetzt statt zu schleichen. Ein Leistungsmodul bei 3 % anzusteuern bringt
   nichts Sinnvolles.
7. **Rückmeldung prüfen** (siehe «Rückmeldung der Leistungsaufnahme»).
8. **Auf die DAC-Kennlinie abbilden** und ausgeben, danach das LED-Board
   nachziehen.

Mit den Werten von Abschnitt 3 (Reserve 250 W, Heizstab 4500 W,
Mindestansteuerung 20 %) heisst das: **der Heizstab setzt erst ab rund 1150 W
Einspeisung ein** (250 W Reserve plus 900 W für die 20 %) und ist ab 4750 W auf
Volllast.

### Die DAC-Kennlinie

Der ESP32 hat einen 8-bit-DAC (GPIO25, 0-3.3 V), dessen Spannung auf den
0-10-V-Eingang des Leistungsmoduls verstärkt wird. Zwei `number`-Entitäten
kalibrieren die Kennlinie:

| Entität | Bedeutung |
| :--- | :--- |
| «0% Power» | Spannung, bei der das Modul gerade einsetzt (Totzone darunter) |
| «100% Power» | Spannung für Volllast, gleichzeitig Bezug für den DAC-Vollausschlag |

Gerechnet wird
`U = «0% Power» + («100% Power» − «0% Power») × out`, und daraus der DAC-Pegel
als `U / «100% Power»`, begrenzt auf 0…1. Der DAC-Vollausschlag entspricht
also per Definition «100% Power». Mit den aktuellen Werten (2.00 V / 8.95 V)
liegen 0-100 % Leistung auf 2.00-8.95 V, das sind rund 78 % des DAC-Bereichs
und damit etwa 200 der 256 Stufen - eine Auflösung von gut 0.5 Prozentpunkten.

Bei 0 % Ansteuerung wird der DAC auf 0 gesetzt, nicht auf «0% Power»: aus ist
aus.

### Kühlkörper, Lüfter und Übertemperatur

Ein DS18B20 am 1-Wire-Bus misst die Kühlkörpertemperatur des Leistungsmoduls.
Er wird alle 10 s gelesen, über 10 Werte gemittelt und mit `send_every: 10`
publiziert - **es geht also alle 100 s ein Wert weiter, und nur dann laufen
Lüfter- und Übertemperaturlogik.** Beides mit Hysterese:

| Funktion | Ein | Aus |
| :--- | :--- | :--- |
| Lüfter (GPIO23) | ≥ «T Fan Start» | < «T Fan Start» − «Hyst Fan» |
| Übertemperatur | ≥ «Tmax Module» | < «Tmax Module» − 2 × «Hyst Fan» |

Die Freigabe der Übertemperatur nutzt die doppelte Lüfterhysterese - ein eigener
Parameter dafür existiert nicht. Mit den aktuellen Werten: Lüfter ein ab
45.0 °C, aus unter 40.5 °C; Übertemperatur ab 85.0 °C, Freigabe erst unter
76.0 °C.

### Speicherladung

Die Speicherverriegelung bewertet das Script `eval_boiler`, bei jedem neuen
Wert eines der beiden Speicherfühler und zusätzlich in jeder Runde der
Regelschleife. Es wählt zuerst die Quelle, in dieser Rangfolge:

| Rang | Quelle | gilt, wenn |
| :--- | :--- | :--- |
| 1 | `sensor.s1` | Wert numerisch **und** Fühler-Watchdog des Speichermonitors gemeldet und `off` |
| 2 | `sensor.wp_temperatur_warmwasser` − «Offset Backup» | Wert numerisch |
| - | keine | sonst: **Speicher gilt als geladen, Heizstab gesperrt** |

Die aktive Quelle zeigt der Textsensor «1.1 Speicherfuehler» (`S1`,
`Backup WW` oder `keiner`).

Der Ersatzfühler kommt von der Wärmepumpensteuerung, also über eine andere
Integration und einen anderen Ausfallpfad als S1. Er sitzt im selben Speicher
auf leicht anderer Höhe und liest im Bereich ab 70 °C im Median 2.25 K höher
(σ 0.36 K, gemessen über 24 h am 2026-09-01). «Offset Backup» zieht diesen
Unterschied ab, damit «Tmax Boiler» für beide Fühler gilt.

Die gewählte Temperatur wird gegen «Tmax Boiler» mit «Hyst Charge» als
Rückschaltdifferenz geprüft - aktuell gesperrt ab 78.0 °C, Freigabe unter
76.0 °C. **Im Totband dazwischen gilt der letzte Zustand**, den das Gerät in
einem neustartfesten Global (`boiler_charged_mem`) hält. Ein Neustart bei 77 °C
übernimmt also, ob der Speicher gerade am Laden war oder schon voll, statt die
Hysterese zu verlieren. Geschrieben wird nur bei einem Wechsel, ein paar Mal am
Tag. Ist noch nie ein Zustand gespeichert worden, gilt «geladen».

Der `binary_sensor` «Boiler Temperature» zeigt das Ergebnis - `on` heisst
gesperrt, ob wegen voller Ladung oder weil keine gültige Temperatur vorliegt.

Ein Alter der Speichertemperaturen lässt sich am Gerät nicht über die
Ankunftszeit prüfen: Home Assistant schickt nur Änderungen, und bei ruhendem
Speicher kommt bis zu einer Stunde lang nichts (gemessen: S1 bis 63 min,
Warmwasserfühler bis 55 min). Deshalb trägt der Watchdog des Speichermonitors
die Alterung von S1, und ein ausgefallenes Gerät erkennt diese Steuerung daran,
dass Home Assistant den Wert auf `unavailable` setzt - beim Gerät kommt das als
`NAN` an.

### Rückmeldung der Leistungsaufnahme

Der Heizstab hat einen eigenen mechanischen Thermostat, der am oberen Ende des
Temperaturbereichs öffnet. Dann fordert die Regelung Leistung an, ohne dass
welche fliesst. Der `binary_sensor` «1.2 Keine Leistungsaufnahme» (`problem`)
meldet das: er geht auf `on`, wenn 300 s lang (`noflow_delay_s`) mindestens die
Mindestansteuerung angefordert wird und `sensor.heizstab` dabei unter 100 W
(`noflow_power_w`) bleibt. Die Modulelektronik allein nimmt rund 10 W auf. Die
5 min decken die grösste gemessene Meldelücke von `sensor.heizstab` (247 s) ab.

Die Meldung ändert an der Regelung nichts. Physisch schadet die
Fehlanforderung nicht, und bei 0 % Ansteuerung könnte das Gerät nicht mehr
sehen, wann der Thermostat wieder schliesst. Sie deckt zugleich einen defekten
Heizstab oder ein ausgefallenes Modul ab.

### Betriebsstunden

«Betriebsstunden» zählt die Zeit, in der das Gerät Leistung anfordert
(«Output Power» über 0 %), als `total_increasing` in Stunden. Der Zähler läuft
im Gerät, übersteht Neustart und OTA und wird nie zurückgesetzt. Tages- und
Monatswerte bildet Home Assistant aus der Langzeitstatistik.

Gezählt wird die Anforderung, nicht der Stromfluss: Hat der Thermostat des
Heizstabs geöffnet, läuft der Zähler weiter. Wie oft das vorkommt, zeigt «1.2
Keine Leistungsaufnahme».

### Anzeige am LED-Board

Ein PCF8574 auf der I²C-Adresse 0x38 treibt acht LEDs, alle Ausgänge
`inverted` (aktiv low):

| Anzeige | Leuchtet |
| :--- | :--- |
| Balken 20 % | Ansteuerung > 20 % |
| Balken 40 % | Ansteuerung > 40 % |
| Balken 60 % | Ansteuerung > 60 % |
| Balken 80 % | Ansteuerung > 80 % |
| Balken 100 % | Ansteuerung ≥ 100 % |
| Übertemperatur | Verriegelung Übertemperatur aktiv |
| Modulspannung | bei **fehlender** Modulspannung, also als Störungsanzeige |
| WLAN | Signalpegel besser als −70 dBm |

Der Balken ist kumulativ und wird bei jedem Durchlauf von `set_Power`
nachgezogen, also alle 5 s. Die WLAN-LED hängt am internen
`wifi_signal`-Sensor mit 60 s Abfrageintervall.

### Startverhalten

Der `on_boot`-Block setzt zuerst den DAC auf 0 und bestimmt danach Lüfter- und
Übertemperaturzustand neu. Solange keine Home-Assistant-Werte eingetroffen sind,
steht der Überschuss auf 0, die Rechnung ergibt 0 % und der Heizstab bleibt aus.
Die Speicherverriegelung steht bis zum ersten gültigen Temperaturwert auf
«gesperrt».
Das Gerät fährt also nach einem Neustart nie ungeregelt an, sondern wartet auf
Daten.

---

## 2. Hardware & Pinout (ESP32 `esp32dev`)

| Pin | Funktion |
| :--- | :--- |
| GPIO25 | DAC-Ausgang, Sollwert für das 0-10-V-Leistungsmodul (`esp32_dac`) |
| GPIO23 | Lüfter Kühlkörper (GPIO-Output) |
| GPIO33 | Rückmeldung Modulspannung, Eingang mit internem Pulldown |
| GPIO32 | 1-Wire-Bus, ein DS18B20 am Kühlkörper, Pull-up 4.7 kΩ nach 3.3 V |
| GPIO21 | I²C SDA (PCF8574 LED-Board) |
| GPIO22 | I²C SCL (PCF8574 LED-Board) |

**Portexpander:** PCF8574 (nicht 8575) auf 0x38, `scan: true` am Bus.

| Portpin | LED |
| :--- | :--- |
| P0 | Balken 80 % |
| P1 | Balken 60 % |
| P2 | Balken 40 % |
| P3 | Balken 20 % |
| P4 | Balken 100 % |
| P5 | Übertemperatur |
| P6 | Modulspannung fehlt |
| P7 | WLAN |

Die Reihenfolge der Balken-LEDs auf den Portpins ist nicht monoton - P4 trägt
die 100 %, P0 bis P3 zählen abwärts. Das folgt der Leiterbahnführung des Boards,
nicht der Logik.

**Fühleradresse** (fest in der YAML hinterlegt):

| Sensor | Position | ROM-Adresse |
| :--- | :--- | :--- |
| `zwe2_heatsink_temp` | Kühlkörper Leistungsmodul | `0x190218301866ff28` |

Wird der Fühler getauscht, muss die Adresse hier nachgezogen werden - sonst
bleibt der Sensor ohne Wert (siehe Abschnitt 6).

**Nicht am Gerät:** Der Heizstab selbst hängt am Leistungsmodul, nicht am ESP32.
Das Gerät gibt ausschliesslich einen Kleinspannungs-Sollwert aus und liest einen
Rückmeldekontakt; es schaltet keine Last.

---

## 3. Home Assistant Integration

### Vom Gerät bereitgestellt

| Entität | Einheit | Bedeutung |
| :--- | :--- | :--- |
| `sensor.wp_zwe2_controller_output_power` | % | aktuelle Ansteuerung, alle 2 s |
| `sensor.wp_zwe2_controller_heatsink_temperature` | °C | Kühlkörper, alle 100 s |
| `binary_sensor.wp_zwe2_controller_1_0_over_temperature` | - | Verriegelung Übertemperatur (`problem`) |
| `sensor.infrastructure_wp_zwe2_controller_1_1_speicherfuehler` | - | aktive Quelle der Speicherverriegelung: `S1`, `Backup WW`, `keiner` |
| `binary_sensor.infrastructure_wp_zwe2_controller_1_2_keine_leistungsaufnahme` | - | angefordert, aber keine Leistung gemessen (`problem`) |
| `sensor.infrastructure_wp_zwe2_controller_betriebsstunden` | h | Zeit mit Ansteuerung über 0 %, `total_increasing`, neustartfest |
| `binary_sensor.wp_zwe2_controller_boiler_temperature` | - | Speicher geladen oder ohne gültige Temperatur gesperrt (`heat`) |
| `binary_sensor.wp_zwe2_controller_fan` | - | Lüfter läuft (`running`) |
| `binary_sensor.wp_zwe2_controller_module_power` | - | Modulspannung vorhanden (`power`) |
| `switch.wp_zwe2_controller_main_power_on_off` | - | Hauptfreigabe, `RESTORE_DEFAULT_ON` |
| `switch.wp_zwe2_controller_override_mode` | - | Volllast erzwingen, beim Start immer aus |

Einstellbare Parameter, alle neustartfest und in der Kategorie `config`:

| Entität | Bereich | Schritt | Stand 2026-07-30 |
| :--- | :--- | :--- | :--- |
| `number.wp_zwe2_controller_t_fan_start` | 0 - 100 °C | 0.1 | 45.0 |
| `number.wp_zwe2_controller_tmax_module` | 0 - 100 °C | 0.1 | 85.0 |
| `number.wp_zwe2_controller_tmax_boiler` | 0 - 110 °C | 0.1 | 78.0 |
| `number.wp_zwe2_controller_power_solar_min` | 0 - 10000 W | 100 | 250 |
| `number.wp_zwe2_controller_power_heater` | 0 - 10000 W | 100 | 4500 |
| `number.wp_zwe2_controller_min_heater_output` | 0 - 100 % | 0.1 | 20.0 |
| `number.wp_zwe2_controller_0_power_2` | 0 - 10 V | 0.01 | 2.00 |
| `number.wp_zwe2_controller_100_power_2` | 0 - 10 V | 0.01 | 8.95 |
| `number.wp_zwe2_controller_hyst_fan` | 0 - 25 K | 0.1 | 4.5 |
| `number.wp_zwe2_controller_hyst_charge` | 0 - 25 K | 0.1 | 2.0 |
| `number.infrastructure_wp_zwe2_controller_offset_backup` | −10 - 10 K | 0.05 | 2.25 (seit 2026-11-18) |

Die seit V1.1.0 neuen Entitäten tragen den Bereich `infrastructure` im
Namen, weil Home Assistant neuen Entitäten den Bereich des Geräts voranstellt.

Die drei Temperaturen tragen `device_class: temperature` mit «°C», die beiden
Leistungen `power` mit «W». Die beiden Hysteresen und «Offset Backup» sind
Temperaturdifferenzen und haben **keine** Geräteklasse, nur die Einheit «K»: mit
`device_class: temperature` würde Home Assistant «K» als absolute Temperatur
lesen und 4.5 K als −268.65 °C anzeigen.

Dazu die Diagnose-Entitäten aus `common/diagnostics.yaml` (Kategorien 2.x bis
6.x: WLAN, Netzwerk, System, Versionen, Neustart-Buttons).

### Vom Gerät konsumiert

| Entität | Rolle |
| :--- | :--- |
| `sensor.grid_active_power` | Zählerwirkleistung, die eigentliche Regelgrösse |
| `sensor.charge_discharge_power` | Hausbatterie, nur der Entladeanteil |
| `sensor.s1` | Speichertemperatur oben, von `wp-speicher-monitor` |
| `binary_sensor.infrastructure_wp_speicher_monitor_1_0_fuehler_watchdog` | Gültigkeit von S1, von `wp-speicher-monitor` |
| `sensor.wp_temperatur_warmwasser` | Ersatzfühler, `luxtronik` |
| `sensor.heizstab` | gemessene Heizstableistung, nur für «1.2 Keine Leistungsaufnahme» |
| `time.homeassistant` | Zeitquelle und 5-s-Takt der Regelschleife |

Das Gerät hängt damit an **sieben** fremden Entitäten. Fällt
`wp-speicher-monitor` aus, übernimmt der Warmwasserfühler der Wärmepumpe; fallen
beide aus, bleibt der Heizstab gesperrt.

### Vorrangschaltung gegenüber der Wallbox

Die Priorität zwischen Elektroauto und Heizstab wird **nicht** auf dem Gerät
entschieden, sondern in Home Assistant. Die Automation «ZW2 and Wallbox Prio
Cascade» schaltet `switch.wp_zwe2_controller_main_power_on_off` aus, sobald ein
Fahrzeug an der Wallbox angesteckt ist (10 s entprellt), und wieder ein, sobald
es abgesteckt oder vollgeladen ist. Das Auto hat damit Vorrang, der Heizstab
nimmt den Rest.

Wer den Heizstab in der Historie stillstehend findet, sollte deshalb zuerst
diesen Schalter und die Wallbox ansehen, nicht die Regelung.

---

## 4. Secrets & Inbetriebnahme

Drei Einträge müssen in `~/esphome/secrets.yaml` stehen:

```yaml
zwe2controller_api_key: "…"                 # API- und OTA-Verschlüsselung
zwe2controller_fallback_ap_ssid: "…"        # Fallback-Hotspot
zwe2controller_fallback_ap_password: "…"
```

Dazu die gemeinsamen Einträge `wifi_ssid`, `wifi_password` sowie die von
`common/diagnostics.yaml` erwarteten `mac_bssid_ug`, `mac_bssid_eg` und
`mac_bssid_dg`.

Gebaut wird in `~/esphome`, wo `secrets.yaml` und `common/` auflösbar sind:

```bash
PLATFORMIO_CORE_DIR="$HOME/.platformio_esphome" ~/.local/bin/esphome compile wp-zwe2-controller.yaml
```

**Vor dem ersten Betrieb sind die beiden Spannungswerte zu kalibrieren**, sonst
stimmt die Leistungskennlinie nicht: «0% Power» auf die Spannung, bei der das
Leistungsmodul gerade einsetzt, «100% Power» auf die Spannung bei
DAC-Vollausschlag, gemessen am Moduleingang. «Power Heater» muss die
Nennleistung des Heizstabs tragen, sonst geht die Rückaddition der Eigenaufnahme
falsch ein und die Regelung pendelt.

Fällt das WLAN aus, spannt das Gerät den Fallback-AP mit Captive Portal auf. Der
lokale Webserver (Port 80, ohne OTA) zeigt Ansteuerung, Temperaturen und
Schalterzustände auch dann, wenn Home Assistant nicht erreichbar ist.

---

## 5. Datenlast gegenüber Home Assistant

Der Sensor «Output Power» meldet alle 2 s, das sind 1800 Meldungen pro Stunde
und die mit Abstand grösste Melderate dieses Geräts. Der Kühlkörperfühler meldet
alle 100 s, die fünf Binärsensoren und «1.1 Speicherfuehler» nur bei einem
Wechsel. «Betriebsstunden» meldet während der Anforderung alle 3 min (Filter
`delta: 0.05` h), sonst gar nicht.

Für die Datenbank zählt aber nur, was sich ändert: Home Assistant verwirft
unveränderte Wiederholungen im Recorder. Nachts, bei gesperrtem Heizstab oder
bei ausgeschaltetem Hauptschalter steht «Output Power» konstant auf 0 - dann
entsteht trotz 2-s-Takt keine Zeile. Während der Modulation ändert sich der Wert
dagegen fast bei jeder Meldung, das sind bis zu 1800 Zeilen pro Stunde für diese
eine Entität.

Wer die tatsächliche Zeilenzahl wissen will, misst sie über `total_count` je
Entität in der Recorder-Historie, statt sie aus dem Melde-Intervall zu schätzen.
Falls sie zum Problem wird, ist die naheliegende Stelle das
`update_interval: 2s` dieses einen Template-Sensors - die Regelung selbst läuft
mit 5 s und wäre davon nicht betroffen.

---

## 6. Bekannte Punkte

* **Die Verriegelungen sind keine Sicherheitseinrichtung.** Sie laufen in
  Software auf einem Bastel-Mikrocontroller und hängen zum Teil an Werten aus
  dem Netzwerk. Der Schutz des Heizstabs und des Speichers gegen Überhitzung
  muss mechanisch und unabhängig von diesem Gerät vorhanden sein.

### Sensor- und Temperaturmanagement

Das war die grösste Schwäche dieser Konfiguration. **Mit V1.1.0 sind die vier
schwersten Punkte behoben:** die Speicherverriegelung startet gesperrt statt
frei, hält ihren Zustand im Totband über einen Neustart, fällt bei einem
ungültigen oder vom Watchdog verworfenen S1 auf den Warmwasserfühler der
Wärmepumpe zurück und sperrt erst, wenn auch der ausfällt. Ein stehender
Netzwert setzt die Ansteuerung nach 300 s auf 0, und «1.2 Keine
Leistungsaufnahme» meldet, wenn angeforderte Leistung nicht ankommt. Details in
Abschnitt 1 unter «Speicherladung» und «Rückmeldung der Leistungsaufnahme».

**Zur Entwarnung:** Heizelemente bringen ihren eigenen mechanischen Thermostat
und eine Übertemperatursicherung mit, unabhängig von jeder Elektronik. Das ist
kein theoretisches Argument, sondern am 2026-07-30 direkt beobachtet: die
Regelung forderte 100 % an, `sensor.heizstab` zeigte 12.8 W statt 4500 W - der
Thermostat des Heizstabs hatte am oberen Ende des Temperaturbereichs bereits
angesprochen. Der Speicher kann über diesen Weg also nicht überhitzt werden,
auch wenn die Software-Verriegelung versagt.

Was bleibt:

* **Der Fühler-Watchdog ist kollektiv.** Er wird wahr, sobald *irgendeiner*
  der vier Fühler des Speichermonitors stale ist, und sagt nicht welcher. Hängt
  nur S3, wechselt diese Steuerung trotzdem auf den Ersatzfühler. Das ist
  unschädlich, aber unscharf.
* **Der Ersatzfühler hat keinen eigenen Watchdog.** Er fällt nur aus der
  Rangfolge, wenn Home Assistant ihn `unavailable` setzt. Hängt die
  `luxtronik`-Integration, ohne das zu tun, hält er seinen letzten Wert. Das
  betrifft nur den Fall, dass S1 gleichzeitig ausgefallen ist.
* **Die Rückaddition rechnet weiter mit dem Sollwert**, nicht mit
  `sensor.heizstab`. Bei offenem Thermostat überschätzt das Gerät seinen
  Überschuss um die angeforderte Leistung. Folgenlos, solange nichts fliesst;
  schliesst der Thermostat wieder, zieht der Heizstab bis zum nächsten
  Zählerwert mehr als den echten Überschuss. Bewusst so gelassen: zwei
  Messquellen mit 32 s und 37 s Meldetakt in der Regelung zu verrechnen, lädt
  zum Pendeln ein.
* **Ein ausgefallener Fühler wird nicht gemeldet.** Fällt der DS18B20 aus, ist
  seine Temperatur `nan`, damit sind beide Vergleiche falsch, und Lüfter wie
  Übertemperaturzustand bleiben auf ihrem letzten Stand stehen. Ein Watchdog,
  der das nach Home Assistant meldet, fehlt - der Ausfall sieht von aussen aus
  wie ein kühler Kühlkörper.
* **Die Übertemperaturerkennung sitzt hinter einem 100-Sekunden-Mittel.** Der
  Kühlkörperfühler wird alle 10 s gelesen, aber erst nach 10 Werten publiziert,
  und die Logik hängt an `on_value`. Zwischen dem tatsächlichen Überschreiten
  von «Tmax Module» und dem Abschalten liegen damit bis zu 100 s, plus die
  Trägheit des gleitenden Mittels selbst - dieses läuft dem echten Wert um rund
  eine halbe Fensterlänge nach. Für die thermische Zeitkonstante eines
  Kühlkörpers mit Lüfter ist das viel. Ein zweiter, ungefilterter Pfad für die
  reine Abschaltschwelle wäre die naheliegende Verbesserung.
* **Ein unbrauchbarer Zählerwert führt sauber auf 0 %, ein fehlender
  Batteriewert nicht.** Meldet Home Assistant für die Netzleistung einen
  nichtnumerischen Zustand, rechnet die Kette mit `nan` weiter, die Prüfung
  gegen die Mindestansteuerung schlägt fehl und die Ansteuerung geht auf 0 - der
  gutmütige Fall. Beim Batteriesensor prüft das Lambda nur `x < 0`, was für
  `nan` falsch ist: die Entladung wird dann still als 0 angenommen und der
  Entladeschutz fällt weg, ohne dass es auffällt.
* **Fällt Home Assistant aus, regelt das Gerät noch bis zu 300 s mit den letzten
  Werten**, dann greift die Frist auf den Netzwert und die Ansteuerung geht auf
  0. Der 5-s-Takt kommt von `time.homeassistant`, läuft nach der ersten
  Zeitsynchronisation aber lokal weiter. Nach einem Neustart **ohne** Home
  Assistant wird die Uhr nie gestellt, der Takt feuert nicht und der Heizstab
  bleibt aus.

### Weitere Punkte

* **«Hyst Fan» ist doppelt belegt.** Der Parameter bestimmt die
  Lüfterhysterese und - verdoppelt - die Freigabeschwelle der Übertemperatur.
  Wer die Lüfterhysterese anpasst, verschiebt ungewollt auch die
  Wiedereinschaltsperre des Heizstabs.
* **Zwei Divisionen ohne Nullprüfung.** «Power Heater» und «100% Power» stehen
  beide im Nenner und lassen beide den Wert 0 zu. «Power Heater» auf 0 führt
  über `min(inf, 1.0)` auf **Volllast**, «100% Power» auf 0 auf ein `nan` im
  DAC-Sollwert, das die anschliessende Begrenzung nicht abfängt. Beides sind
  Fehleingaben, aber die Folge ist unnötig unfreundlich - eine untere Grenze im
  `min_value` der beiden Entitäten wäre die einfache Abhilfe.
* **Der Kühlkörpersensor publiziert am Ende seines eigenen `on_value` seinen
  eigenen Zustand.** Das schiebt den bereits gemittelten Wert erneut in die
  eigene Filterkette und verfälscht das gleitende Mittel. Die Zeile hat keinen
  erkennbaren Zweck.
* **`get_component_state()` im `on_boot` ist wirkungslos.** Der Aufruf sieht aus
  wie ein Anstossen des Speicherfühlers, ist aber ein reiner Getter, dessen
  Rückgabewert verworfen wird.
* **«Output Power» hat keine `state_class`.** Home Assistant führt darüber keine
  Langzeitstatistik: der Verlauf ist nur in der Kurzzeit-Historie sichtbar und
  nach Ablauf der `recorder`-Aufbewahrung weg. `measurement` wäre nachzutragen -
  die Statistik beginnt dann allerdings beim Flash bei null, Vergangenheit lässt
  sich nicht nachtragen.
* **Kein Energiezähler, bewusst.** Aus der Ansteuerung liesse sich nur die
  angeforderte Energie hochrechnen, nicht die aufgenommene - bei offenem
  Thermostat liegen beide weit auseinander. Das Gerät zählt deshalb nur
  Betriebsstunden.
* **Kein Hysteresefenster an der Einschaltschwelle.** Pendelt der Überschuss um
  die Grenze von «Min Heater Output», springt die Ansteuerung im 5-s-Takt
  zwischen 0 und 20 %. Die Rückaddition der Eigenaufnahme dämpft das, solange
  «Power Heater» stimmt **und** der Heizstab tatsächlich Leistung aufnimmt (siehe
  «Die Rückaddition rechnet weiter mit dem Sollwert» oben) - sie ist der einzige
  Schutz dagegen.
* **Die fünf importierten Home-Assistant-Sensoren tragen `name: none`.** Zusammen mit
  `internal: True` entsteht ohnehin keine Entität, der Name ist also
  wirkungslos - er sieht in der YAML aber aus wie einer.
* **Die Entity-IDs der beiden Spannungsparameter tragen ein `_2`**
  (`number.wp_zwe2_controller_0_power_2`,
  `number.wp_zwe2_controller_100_power_2`). Das ist ein Altlast-Suffix aus der
  Home-Assistant-Registry, nicht aus der YAML. Wer darauf verweist, muss die
  IDs mit Suffix nehmen; ein Aufräumen würde bestehende Verweise brechen.
* **Die Namensgebung folgt nicht dem Nummernschema** der übrigen Projekte: nur
  «1.0 Over Temperature» trägt ein Präfix, alle anderen Entitäten des Geräts
  nicht. Eine Umbenennung würde die Entity-IDs in Home Assistant ändern und
  damit die Wallbox-Kaskade und die Dashboards brechen, deshalb bleibt es so.
