# wp-zwe2-controller - PV-geführter Heizstab im Wärmespeicher

![Version](https://img.shields.io/badge/version-1.0.0-blue)
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
| Kühlkörpertemperatur | DS18B20 am 1-Wire-Bus des Geräts, feste ROM-Adresse |
| Modulspannung vorhanden | Rückmeldekontakt des Leistungsmoduls an GPIO33 |

Drei der fünf Grössen kommen also über die API aus Home Assistant, zwei sind
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

1. **Verriegelungen prüfen.** Ist eine davon aktiv, wird die Ansteuerung auf 0 %
   gesetzt und der Rest übersprungen:

   | Verriegelung | Bedingung |
   | :--- | :--- |
   | Übertemperatur Modul | Kühlkörper ≥ «Tmax Module» |
   | Speicher geladen | S1 ≥ «Tmax Boiler» |
   | Keine Modulspannung | Eingang GPIO33 low |
   | Hauptschalter aus | «Main Power On-Off» off |

2. **Override?** Wenn ja, Ansteuerung 100 %.
3. **Sonst regeln:**
   `pwr = max(Überschuss − «Power Solar Min» − Batterieentladung, 0)`,
   dann `out = min(pwr / «Power Heater», 1.0)`.
4. **Mindestansteuerung:** Liegt `out` unter «Min Heater Output», wird auf 0 %
   gesetzt statt zu schleichen. Ein Leistungsmodul bei 3 % anzusteuern bringt
   nichts Sinnvolles.
5. **Auf die DAC-Kennlinie abbilden** und ausgeben, danach das LED-Board
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

Die Speichertemperatur oben (`sensor.s1`) wird gegen «Tmax Boiler» geprüft, mit
«Hyst Charge» als Rückschaltdifferenz. Ist der Speicher geladen, ist der
Heizstab gesperrt - aktuell also ab 78.0 °C, Freigabe unter 76.0 °C. Der
zugehörige `binary_sensor` «Boiler Temperature» macht diesen Zustand in Home
Assistant sichtbar.

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
| `binary_sensor.wp_zwe2_controller_boiler_temperature` | - | Speicher geladen (`heat`) |
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

Dazu die Diagnose-Entitäten aus `common/diagnostics.yaml` (Kategorien 2.x bis
6.x: WLAN, Netzwerk, System, Versionen, Neustart-Buttons).

### Vom Gerät konsumiert

| Entität | Rolle |
| :--- | :--- |
| `sensor.grid_active_power` | Zählerwirkleistung, die eigentliche Regelgrösse |
| `sensor.charge_discharge_power` | Hausbatterie, nur der Entladeanteil |
| `sensor.s1` | Speichertemperatur oben, von `wp-speicher-monitor` |
| `time.homeassistant` | Zeitquelle und 5-s-Takt der Regelschleife |

Das Gerät hängt damit an **vier** fremden Entitäten, drei davon inhaltlich. Eine
davon kommt aus einem anderen Projekt dieses Repositories - fällt
`wp-speicher-monitor` aus, verliert diese Steuerung ihre Speicherverriegelung
(siehe Abschnitt 6).

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

Vier Einträge müssen in `~/esphome/secrets.yaml` stehen:

```yaml
zwe2controller_api_key: "…"                 # API-Verschlüsselung
zwe2controller_ota_key: "…"                 # OTA-Passwort
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
alle 100 s, die vier Binärsensoren nur bei Flanken.

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
* **Ohne Home Assistant regelt das Gerät mit veralteten Werten weiter.** Der
  5-s-Takt kommt von `time.homeassistant`, läuft aber nach der ersten
  Zeitsynchronisation lokal weiter - die Schleife bleibt also aktiv, während
  Überschuss, Batterie und Speichertemperatur auf ihrem letzten Wert stehen. Die
  lokal verdrahteten Verriegelungen (Übertemperatur, Modulspannung) und der
  Hauptschalter greifen weiter, die Speicherverriegelung friert ein. War sie im
  Moment des Ausfalls nicht aktiv, kann der Heizstab bei stehender Datenlage
  unbegrenzt weiter einspeisen. Nach einem Neustart **ohne** Home Assistant wird
  die Uhr nie gestellt, der Takt feuert nicht und der Heizstab bleibt aus - das
  ist der harmlosere der beiden Fälle.
* **Ein unbrauchbarer Zählerwert führt sauber auf 0 %, ein fehlender
  Batteriewert nicht.** Meldet Home Assistant für die Netzleistung einen
  nichtnumerischen Zustand, rechnet die Kette mit `nan` weiter, die Prüfung
  gegen die Mindestansteuerung schlägt fehl und die Ansteuerung geht auf 0 - der
  gutmütige Fall. Beim Batteriesensor prüft das Lambda nur `x < 0`, was für
  `nan` falsch ist: die Entladung wird dann still als 0 angenommen und der
  Entladeschutz fällt weg, ohne dass es auffällt.
* **Ein Neustart im Totband der Speicherhysterese gibt den Heizstab wieder
  frei.** Der Binärsensor «Boiler Temperature» hat keinen Restore und steht nach
  dem Boot in Home Assistant auf `unknown`. Das Verriegelungs-Lambda liest
  jedoch `.state` und nicht `has_state()` - und ESPHome initialisiert
  `bool state{}` auf `false`, also auf «Speicher nicht geladen». Liegt die
  Speichertemperatur beim Start zwischen «Tmax Boiler» minus «Hyst Charge» und
  «Tmax Boiler», publiziert das Lambda gar nichts (beide Vergleiche sind falsch)
  und der Default bleibt stehen: der Heizstab lädt bei Überschuss sofort bis zur
  oberen Schwelle nach, statt bis zur unteren zu warten. Belegt am 2026-07-30
  beim OTA auf V1.0.0 - S1 stand auf 77.5 °C, der Heizstab ging auf 100 %. Der
  Effekt begrenzt sich an der oberen Schwelle selbst, hebt aber die Hysterese
  aus. Abhilfe wäre, beim ersten eintreffenden Wert einmalig gegen «Tmax Boiler»
  zu initialisieren, statt nur die beiden Flanken zu behandeln.
* **Kein Alterungscheck auf den drei HA-Werten.** Es gibt keine
  Zeitüberwachung. Ein Sensor, der einfach nicht mehr meldet - im Unterschied zu
  einem, der `unavailable` meldet - hält seinen Wert unbegrenzt gültig.
  Besonders relevant bei `sensor.s1`, weil das die Speicherverriegelung trägt
  und aus einem anderen Gerät kommt.
* **Die Übertemperaturerkennung sitzt hinter einem 100-Sekunden-Mittel.** Der
  Kühlkörperfühler wird alle 10 s gelesen, aber erst nach 10 Werten publiziert,
  und die Logik hängt an `on_value`. Zwischen dem tatsächlichen Überschreiten
  von «Tmax Module» und dem Abschalten liegen damit bis zu 100 s, plus die
  Trägheit des gleitenden Mittels selbst - dieses läuft dem echten Wert um rund
  eine halbe Fensterlänge nach. Für die thermische Zeitkonstante eines
  Kühlkörpers mit Lüfter ist das viel. Ein zweiter, ungefilterter Pfad für die
  reine Abschaltschwelle wäre die naheliegende Verbesserung.
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
* **Es gibt keinen Energie- und keinen Betriebsstundenzähler.** Wie viele
  Kilowattstunden der Heizstab über den Tag eingetragen hat, geht aus dem Gerät
  nicht hervor; es liefert nur die momentane Ansteuerung in Prozent. Ein
  `total_increasing`-Zähler analog zu `wp-solar-monitor` fehlt und wäre die
  grösste funktionale Lücke.
* **Kein Hysteresefenster an der Einschaltschwelle.** Pendelt der Überschuss um
  die Grenze von «Min Heater Output», springt die Ansteuerung im 5-s-Takt
  zwischen 0 und 20 %. Die Rückaddition der Eigenaufnahme dämpft das wirksam,
  solange «Power Heater» stimmt - sie ist der einzige Schutz dagegen.
* **Ein ausgefallener Fühler wird nicht gemeldet.** Fällt der DS18B20 aus, ist
  seine Temperatur `nan`, damit sind beide Vergleiche falsch, und Lüfter wie
  Übertemperaturzustand bleiben auf ihrem letzten Stand stehen. Ein Watchdog,
  der das nach Home Assistant meldet, fehlt - der Ausfall sieht von aussen aus
  wie ein kühler Kühlkörper.
* **Die drei Home-Assistant-Sensoren tragen `name: none`.** Zusammen mit
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
