# Changelog - wp-zwe2-controller

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.2.0] - 2026-11-18

* **Betriebsstundenzähler.** Neuer Sensor «Betriebsstunden» (h,
  `total_increasing`, `device_class: duration`): zählt die Zeit, in der «Output
  Power» über 0 % steht. Plattform `integration` über eine interne Kopie von
  «Output Power», neustartfest per `restore`. Meldet nur bei 0.05 h Zuwachs,
  also höchstens alle 3 min.
* **Kein Energiezähler.** Aus der Ansteuerung liesse sich nur die angeforderte
  Energie hochrechnen, nicht die aufgenommene. Der Punkt in README Abschnitt 6
  beschreibt das jetzt als bewusste Entscheidung.

## [1.1.0] - 2026-11-18

### Sensor- und Temperaturmanagement

Die vier schwersten Punkte aus README Abschnitt 6 behoben.

* **Speicherverriegelung startet gesperrt.** Bisher stand der Binärsensor
  «Boiler Temperature» nach dem Boot auf `false` («nicht geladen»), bis eine
  Flanke kam. Jetzt gilt der Speicher als geladen, solange keine gültige
  Temperatur vorliegt - auch dann, wenn nach dem Start nie eine eintrifft.
* **Hysterese übersteht einen Neustart.** Im Totband zwischen «Tmax Boiler»
  minus «Hyst Charge» und «Tmax Boiler» gilt der letzte Zustand, gehalten im
  neustartfesten Global `boiler_charged_mem`. Bisher gab ein Neustart im Totband
  den Heizstab frei (belegt 2026-07-30 und 2026-08-29).
* **Ersatzfühler mit Rangfolge.** `sensor.s1` gilt nur, wenn sein Wert
  numerisch ist und der Fühler-Watchdog von `wp-speicher-monitor` `off`
  meldet. Sonst übernimmt `sensor.wp_temperatur_warmwasser` (luxtronik) minus
  der neuen Zahl «Offset Backup» (Startwert 2.25 K). Fallen beide aus, bleibt
  der Heizstab gesperrt. Die Bewertung liegt zentral im neuen Script
  `eval_boiler`, das bei jedem Fühlerwert und in jeder Runde der Regelschleife
  läuft. Neuer Textsensor «1.1 Speicherfuehler» zeigt die aktive Quelle.
* **Frist auf den Netzwert.** Kommt 300 s (`grid_timeout_s`) kein neuer Wert
  von `sensor.grid_active_power`, geht die Ansteuerung auf 0. Gemessen über 7
  Tage: Mittel 32 s, grösste Lücke 150 s. Deckt auch einen Ausfall von Home
  Assistant ab. Der Override ist ausgenommen.
* **Rückmeldung der Leistungsaufnahme.** Neuer Binärsensor «1.2 Keine
  Leistungsaufnahme» (`problem`): `on`, wenn 300 s (`noflow_delay_s`)
  mindestens die Mindestansteuerung angefordert wird und `sensor.heizstab`
  unter 100 W (`noflow_power_w`) bleibt. Nur Meldung, die Regelung bleibt
  unverändert.

Das Alter der Speichertemperaturen lässt sich am Gerät nicht über die
Ankunftszeit prüfen: Home Assistant schickt nur Änderungen, und bei ruhendem
Speicher kam über 7 Tage bis zu 63 min (S1) bzw. 55 min (Warmwasserfühler)
nichts. Deshalb trägt der Watchdog des Speichermonitors die Alterung, und ein
ausgefallenes Gerät wird über `unavailable` erkannt, das beim Gerät als `NAN`
ankommt.

Geflasht am 2026-11-18 um 09:27, RAM 27.4 %, Flash 50.6 %, Config-Hash
`0x5f3fb4db`. Beim Anlauf ging die Verriegelung zuerst auf gesperrt (Quelle
`keiner`) und 20 ms später mit Quelle `S1` bei 47 °C auf frei. Die drei neuen
Entitäten tragen das Bereichspräfix `infrastructure_`.

## [1.0.2] - 2026-11-18

### Einheiten für die Parameter-Numbers

* **Sieben `number`-Entitäten hatten eine Geräteklasse, aber keine Einheit.**
  Home Assistant meldet das seit 2026.11.2 beim Start als «native unit of
  measurement 'None' which is not a valid unit for the device class» und lehnt
  es ab 2027.5 ab.
* **«T Fan Start», «Tmax Module», «Tmax Boiler»** bekommen «°C», **«Power Solar
  Min», «Power Heater»** bekommen «W».
* **«Hyst Fan», «Hyst Charge»** verlieren `device_class: TEMPERATURE` und
  bekommen «K». Sie sind Temperaturdifferenzen; mit der Geräteklasse würde HA
  «K» als absolute Temperatur nach °C umrechnen.
* Name, `id`, Bereich, Schritt und `restore_value` sind unverändert, die
  Entity-IDs und die im NVS gespeicherten Werte bleiben erhalten. Die Lambdas
  rechnen nur mit `.state` und sind nicht betroffen.

## [1.0.1] - 2026-10-31

### OTA verschlüsselt mit dem API-Schlüssel

* **OTA über `common/ota.yaml`** (common 1.5.0). Der Upload ist mit dem
  API-Schlüssel des Geräts verschlüsselt; das OTA-Passwort und das Secret
  `zwe2controller_ota_key` entfallen. ESPHome warnte seit 2026.9 vor `ota: password`.
* Umgestellt in zwei Uploads, wie in `common/README.md` unter
  «OTA-Verschlüsselung» beschrieben. Flashen setzt jetzt ESPHome ab 2026.10
  voraus.

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

Der Neustart hat die Speicherverriegelung fallen lassen und die Regelung hat
danach 100 % angefordert, obwohl der Speicher unmittelbar davor als geladen
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

Geflossen ist dabei nichts: die Leistungsmessung `sensor.heizstab` stand vor dem
Flash auf 6.5-7.0 W und danach auf 12.5-13.1 W. Die 6 W Sprung sind die
Eigenaufnahme der Modulelektronik bei ausgesteuertem DAC, keine Heizleistung -
der mechanische Thermostat des Heizstabs war offen. S1 ist entsprechend nicht
gestiegen, sondern von 77.5 auf 77.35 °C gefallen.

Die Verriegelung greift also nicht dadurch wieder, dass der Heizstab den
Speicher auf 78 °C bringt. Was bleibt, ist der Verlust der 2-K-Hysterese: nach
einem Neustart im Totband fordert das Gerät sofort wieder an, statt bis 76 °C zu
warten. Als bekannter Punkt in der README aufgenommen, Behebung ist ein Kandidat
für die nächste Version.
