# Changelog - wp-zwe2-controller

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.0.0] - 2026-07-30

### Erstrelease

Aufnahme der bereits im Betrieb stehenden Heizstabsteuerung ins Repository. Der
funktionale Stand entspricht dem, was auf dem Gerät läuft; ergänzt wurden nur
die repo-seitig zwingenden Punkte (siehe unten). An der Regelung selbst ist
nichts geändert.

* **Plattform:** ESP32 auf `board: esp32dev` mit ESP-IDF-Framework, Logger
  aktiv ohne Dämpfung. Verbaut im Heizraum (HA-Bereich «cellar»), erreichbar
  unter 192.168.0.124.
* **Aufgabe:** Der zweite Wärmeerzeuger (ZWE2) der Wärmepumpenanlage - ein
  Heizstab von 4500 W im Wärmespeicher - wird stufenlos dem PV-Überschuss
  nachgefahren. Der Sollwert geht als Spannung über den 8-bit-DAC des ESP32
  (GPIO25) an ein 0-10-V-Leistungsmodul.
* **Überschussrechnung** aus drei Home-Assistant-Sensoren, ereignisgesteuert je
  `on_value`: `sensor.grid_active_power` (Zählerwirkleistung, positiv =
  Einspeisung), `sensor.charge_discharge_power` (Hausbatterie, nur der
  Entladeanteil) und `sensor.s1` (Speichertemperatur oben, kommt vom
  Schwesterprojekt `wp-speicher-monitor`). Die Eigenaufnahme des Heizstabs wird
  auf den Zählerwert zurückaddiert, damit die Regelung ihren eigenen Verbrauch
  nicht als Wegfall des Überschusses liest.
* **Regelschleife:** Das Script `set_Power` läuft alle 5 s, getaktet über eine
  `on_time`-Automation auf `seconds: /5`. Es rechnet
  `Überschuss − Mindestreserve − Batterieentladung`, teilt durch die
  Heizstableistung und begrenzt auf 0-100 %. Unter der eingestellten
  Mindestansteuerung wird auf 0 % gesetzt statt zu schleichen.
* **Vier Verriegelungen** nehmen die Leistung bedingungslos auf 0 %:
  Übertemperatur am Kühlkörper, Speicher geladen, fehlende Modulspannung am
  Eingang GPIO33 und der Hauptschalter «Main Power On-Off».
* **Override-Modus** als Template-Schalter (`ALWAYS_OFF` beim Start) fährt
  Volllast unabhängig vom Überschuss, bleibt aber allen vier Verriegelungen
  unterworfen. Im Override entfällt die Rückaddition der Eigenaufnahme.
* **DAC-Kennlinie über zwei `number`-Entitäten** kalibrierbar: «0% Power» ist
  die Spannung, ab der das Leistungsmodul einsetzt, «100% Power» die für
  Volllast. Der Sollwert wird linear zwischen beide gelegt und auf den
  DAC-Vollausschlag normiert.
* **Kühlkörperfühler:** DS18B20 am 1-Wire-Bus (GPIO32), fest über seine
  ROM-Adresse `0x190218301866ff28` zugeordnet, Auflösung 10 bit, Abfrage alle
  10 s, gleitendes Mittel über 10 Werte mit `send_every: 10`. Aus seinem
  `on_value` laufen Lüftersteuerung und Übertemperaturerkennung, jeweils mit
  Hysterese.
* **Lüfter** am Ausgang GPIO23, ein ab «T Fan Start», aus bei «T Fan Start»
  minus «Hyst Fan».
* **Übertemperatur:** `binary_sensor` «1.0 Over Temperature»
  (`device_class: PROBLEM`) ab «Tmax Module», Freigabe erst bei «Tmax Module»
  minus dem doppelten «Hyst Fan».
* **Speicherladung:** `binary_sensor` «Boiler Temperature»
  (`device_class: HEAT`) ab «Tmax Boiler», Freigabe bei «Tmax Boiler» minus
  «Hyst Charge».
* **LED-Board über PCF8574** (I²C auf 0x38, SDA 21 / SCL 22, alle Ausgänge
  `inverted`): fünfstelliger Leistungsbalken 20/40/60/80/100 %, dazu je eine
  LED für Übertemperatur, fehlende Modulspannung und WLAN-Verbindung. Die
  WLAN-LED hängt am internen `wifi_signal`-Sensor (60 s) und leuchtet ab einem
  Pegel besser als −70 dBm.
* **Zehn Betriebsparameter** als `number`-Entitäten der Kategorie `config`, alle
  neustartfest: «T Fan Start», «Tmax Module», «Tmax Boiler», «Power Solar Min»,
  «Power Heater», «Min Heater Output», «0% Power», «100% Power», «Hyst Fan» und
  «Hyst Charge».
* **Definierter Startzustand:** Der `on_boot`-Block setzt den DAC auf 0 und
  bestimmt Lüfter- und Übertemperaturzustand neu. Solange keine
  Home-Assistant-Werte vorliegen, steht der Überschuss auf 0 und die Regelung
  damit auf 0 % - das Gerät fährt nicht ungeregelt an.
* **Lokaler Webserver** (`web_server` v3, Port 80, ohne OTA) als Zugang bei
  einem HA-Ausfall, dazu Fallback-AP mit Captive Portal.
* Gemeinsames Diagnose-Paket `common/diagnostics.yaml` eingebunden, mit
  angehobenen Heap-Grenzen für den ESP32 (80 kB / 40 kB statt 15 kB / 8 kB).

### Für die Repo-Aufnahme geändert

* **Zugangsdaten über `!secret` ausgelagert.** API-Key, OTA-Passwort und die
  Zugangsdaten des Fallback-AP standen im Klartext in der YAML. Neu:
  `zwe2controller_api_key`, `zwe2controller_ota_key`,
  `zwe2controller_fallback_ap_ssid` und `zwe2controller_fallback_ap_password`.
  Die Werte sind unverändert übernommen, es wurde nichts rotiert.
* **`fw_version`-Substitution und `project:`-Block ergänzt**, damit der
  Firmwarestand am Gerät ablesbar ist und die Versionierung des Repos greift.

Beide Punkte sind nicht funktional, brauchen aber einen Flash, damit Gerät und
Repo denselben Stand tragen.

### Betriebsparameter bei der Aufnahme

Stand 2026-07-30, aus Home Assistant gelesen - die Werte liegen im NVS des
Geräts, nicht in der YAML, und sind deshalb hier festgehalten:

| Parameter | Wert |
| :--- | :--- |
| T Fan Start | 45.0 °C |
| Tmax Module | 85.0 °C |
| Tmax Boiler | 78.0 °C |
| Power Solar Min | 250 W |
| Power Heater | 4500 W |
| Min Heater Output | 20 % |
| 0% Power | 2.00 V |
| 100% Power | 8.95 V |
| Hyst Fan | 4.5 K |
| Hyst Charge | 2.0 K |

### Geflashter Stand

Per OTA eingespielt und geprüft am 2026-07-30 um 14:40 (192.168.0.124). RAM
27.7 %, Flash 52.5 %. Der Flash hat zwei weitere Stände mitgezogen, die nicht zu
dieser Version gehören, sondern nur zum Zeitpunkt:

* **ESPHome 2026.6.2 → 2026.7.3**, entsprechend der lokal installierten CLI.
  Keine Deprecation-Meldung zu einer der hier verwendeten Plattformen.
* **`common/diagnostics.yaml` 1.2.1 → 1.4.0.**

Nach dem Neustart gefunden und gemeldet: der DS18B20 mit seiner erwarteten
Adresse `0x190218301866ff28`, der PCF8574 auf `0x38`. Kühlkörper 42.3 °C,
Lüfter aus, keine Übertemperatur, Modulspannung vorhanden. Freier Heap 240 kB,
WLAN −53 dBm, System Gesundheit 🟢 Stabil. Der Konfig-Hash steht auf
`0xa00cfc5e`, das `project`-Feld meldet `tsgwiro1.wp-zwe2-controller` 1.0.0.

Keine Fehler im Log. Zwei Hinweise ohne Auswirkung auf diese Version:

* **«Bootloader too old for OTA rollback and SRAM1 as IRAM (+40KB)»** - der
  Bootloader stammt aus der Erstinbetriebnahme. Das Gerät hat damit kein
  automatisches Rollback auf die vorige Firmware und verzichtet auf 40 kB IRAM.
  Erneuern geht nur per USB; solange die RAM-Auslastung bei 27.7 % liegt, ist es
  keine Dringlichkeit.
* **«api took a long time for an operation (55 ms)»**, einmalig beim Verbinden
  eines API-Clients.

### Beim Flashen beobachtet

Der Neustart hat die Speicherverriegelung fallen lassen und der Heizstab ist
danach auf Volllast gegangen, obwohl der Speicher unmittelbar davor als geladen
galt. Das ist **kein Effekt dieser Version**, sondern das Verhalten der
Konfiguration bei jedem Neustart - hier zum ersten Mal belegt, deshalb
festgehalten:

Vor dem Flash stand S1 auf 77.5 °C und «Boiler Temperature» auf `on`. Der
Template-Binärsensor hat keinen Restore, steht nach dem Boot in Home Assistant
also auf `unknown`. Das Verriegelungs-Lambda liest aber `.state` und nicht
`has_state()`, und ESPHome initialisiert `bool state{}` auf `false` - für die
Regelung heisst das «Speicher nicht geladen». S1 mit 77.5 °C liegt zudem genau
im Totband der Hysterese (`x >= 78` falsch, `x < 76` ebenfalls), es wird also
nichts publiziert und der Default bleibt stehen. Bei 4.6 kW echter Einspeisung
hat die Regelung daraufhin folgerichtig 100 % gefahren.

Der Effekt begrenzt sich selbst: bei 78.0 °C greift die Verriegelung wieder. Was
verloren geht, ist die Wirkung der 2-K-Hysterese - nach einem Neustart im
Totband lädt das Gerät sofort nach, statt bis 76 °C zu warten. Als bekannter
Punkt in der README aufgenommen, Behebung ist ein Kandidat für die nächste
Version.
