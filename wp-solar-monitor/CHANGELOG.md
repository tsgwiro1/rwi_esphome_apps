# Changelog - wp-solar-monitor

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.0.0] - 2026-07-30

### Erstrelease

Aufnahme des bereits im Betrieb stehenden Solarthermie-Monitors ins Repository.
Der funktionale Stand entspricht dem, was auf dem Gerät läuft; ergänzt wurden
die repo-seitig zwingenden Punkte und eine Korrektur am Power-Sensor (siehe
unten).

* **Plattform:** ESP32 auf `board: esp32dev` mit ESP-IDF-Framework. Logger
  aktiv, der Tag `component` auf `ERROR` gedämpft.
* **Zwei Fühler am Solarkreis:** DS18B20 am 1-Wire-Bus (GPIO25), fest über ihre
  ROM-Adresse zugeordnet - «Vorlauf» (`0x8d00000019d27c28`) und «Ruecklauf»
  (`0x43000000196fe828`). Auflösung 10 bit, Abfrage alle 5 s, gleitendes Mittel
  über 2 Werte, meldet also alle 10 s.
* **Pumpenerkennung:** `binary_sensor` an GPIO5 mit internem Pulldown,
  `device_class: RUNNING`, Name «Pumpe». Der Kontakt der Solarpumpe ist die
  Freigabe für die ganze Wärmemengenrechnung.
* **Wärmemengenzähler:** Das Script `calculate_energy` läuft alle 5 s, getaktet
  über eine `on_time`-Automation auf `seconds: /5`. Es bildet
  ΔT = Vorlauf − Rücklauf (negativ auf 0 begrenzt) und rechnet nur weiter, wenn
  die Pumpe läuft **und** ΔT über 0.5 K liegt. Die Masse des in 5 s
  umgewälzten Wassers ergibt sich aus dem eingestellten Durchfluss und der
  Dichte, daraus mit der spezifischen Wärmekapazität die Energie der Zeitscheibe
  in kJ, umgerechnet nach Wh mit dem Faktor 0.277778.
* **Zwei abgeleitete Entitäten:** «Energy today» (Wh, `total_increasing`)
  summiert die Zeitscheiben über den Tag, «Power» (W) ist die letzte Zeitscheibe
  auf eine Stunde hochgerechnet. Beide publizieren alle 10 s aus einem Global.
  Ein NaN-Schutz setzt den Tageszähler auf 0 zurück, falls der aus dem NVS
  gelesene Wert unbrauchbar ist.
* **Betriebsstunden:** `duty_time`-Sensor «1.1 Pump runtime today» zählt die
  Laufzeit der Pumpe, neustartfest (`restore: true`), dazu «1.2 Pump last
  turn-on» als Zeitstempel der letzten Einschaltung.
* **Anlagenparameter aus Home Assistant einstellbar** als drei
  `number`-Entitäten der Kategorie `config`, alle neustartfest: «spez.
  Wärmekap.» (3.40 - 4.00 kJ/kg°K), «spez. Dichte» (960 - 1060 kg/m³) und
  «Durchfluss» (0 - 10 l/min).
* **Tagesreset:** Um 00:00:00 werden Energiezähler und Pumpenlaufzeit
  zurückgesetzt. Derselbe Reset liegt auf dem Button «1.0 Reset Counters»
  (Kategorie `diagnostic`) für den Eingriff von Hand.
* **Display:** ST7789V «Adafruit RR 280x240» über SPI (CLK GPIO18, MOSI GPIO23,
  CS 14, DC 27, Reset 33), `rotation: 90`, `eightbitcolor`. Zeigt Titelzeile
  «SOLAR» mit WLAN-Symbol ab einem Pegel besser als −70 dBm, das Anlagenschema
  als Hintergrundbild, ein farbiges Pumpensymbol nach Zustand, Vorlauf in Rot
  und Rücklauf in Blau, den Pumpenstatus als ON/OFF, Tagesenergie und Leistung
  jeweils mit automatischem Wechsel auf kWh bzw. kW ab 1000, sowie die
  Pumpenlaufzeit als `hh:mm:ss`.
* **Automatische Hintergrundbeleuchtung:** Ein LDR am ADC (GPIO34, Rohwert)
  schaltet den Backlight-Ausgang GPIO32 unter Rohwert 3900 ein und über 3950
  wieder aus. Die 50 Zähler Abstand wirken als Hysterese gegen Flackern. Der
  Sensor ist `internal: true`, erzeugt in HA also keine Entität.
* **Lokaler Webserver** (`web_server` v3, Port 80, ohne OTA) als Zugang bei
  einem HA-Ausfall, dazu Fallback-AP mit Captive Portal.
* Gemeinsames Diagnose-Paket `common/diagnostics.yaml` eingebunden, mit
  angehobenen Heap-Grenzen für den ESP32 (80 kB / 40 kB statt 15 kB / 8 kB).

### Für die Repo-Aufnahme geändert

* **Zugangsdaten über `!secret` ausgelagert.** API-Key, OTA-Passwort und die
  Zugangsdaten des Fallback-AP standen bisher im Klartext in der YAML. Neu:
  `solarmonitor_api_key`, `solarmonitor_ota_key`,
  `solarmonitor_fallback_ap_ssid` und `solarmonitor_fallback_ap_password`. Die
  Werte sind unverändert übernommen, es wurde nichts rotiert.
* **`fw_version`-Substitution und `project:`-Block ergänzt**, damit der
  Firmwarestand am Gerät ablesbar ist und die Versionierung des Repos greift.

### Korrigiert

* **Power-Sensor als Statistikquelle brauchbar gemacht.** Dem Sensor fehlte die
  `state_class`. Ohne sie führt Home Assistant keine Langzeitstatistik: der Wert
  war nur in der Kurzzeit-Historie sichtbar und nach Ablauf der
  `recorder`-Aufbewahrung weg, Mittel- und Maximalwerte über Monate gab es
  nicht. Neu `state_class: measurement`.

  Die `device_class` stand zwar als `Power` mit grossem P, das war aber
  wirkungslos - ESPHome schreibt sie bei der Validierung ohnehin klein, in Home
  Assistant kommt seit je `power` an. Die Schreibweise ist trotzdem angepasst,
  damit die YAML nicht anders aussieht als sie wirkt.

  Die Statistik beginnt mit dem Flash bei null - die Vergangenheit lässt sich
  nicht nachtragen, weil HA Langzeitstatistiken nur ab dem Zeitpunkt bildet, ab
  dem eine Entität sie deklariert.

Die ersten beiden Blöcke sind nicht funktional, der dritte ändert nur Metadaten.
Alle drei brauchen aber einen Flash, damit Gerät und Repo denselben Stand tragen.

### Geflashter Stand

Per OTA eingespielt und geprüft am 2026-07-30 um 14:01 (192.168.0.127). Der
Flash hat zwei weitere Stände mitgezogen, die nicht zu dieser Version gehören,
sondern nur zum Zeitpunkt:

* **ESPHome 2026.6.2 → 2026.7.3**, entsprechend der lokal installierten CLI. Die
  Display-Plattform `st7789v` ist dort als deprecated markiert, aber noch der
  eigenständige Legacy-Treiber - sie initialisiert unverändert (ST7789V,
  `ADAFRUIT_RR_280X240`, 280x240, Rotation 90°, Height Offset 20). Die
  `mipi_spi`-Regression, die `wp-fp1-smartblock` auf 2026.5.3 festhält, betrifft
  dieses Gerät nicht.
* **`common/diagnostics.yaml` 1.2.1 → 1.3.0.**

Nach dem Neustart gefunden und gemeldet: beide DS18B20 am Bus mit ihren
erwarteten Adressen (`0x43000000196fe828`, `0x8d00000019d27c28`), Vorlauf
73.8 °C, Rücklauf 67.5 °C. Die Anlage lief während des Flashs; die
Energierechnung setzte mit 6.2 K Spreizung und 2720 W direkt fort, der
Tageszähler kam mit 10 763 Wh unbeschädigt aus dem NVS zurück und die
Pumpenlaufzeit mit 15 910 s. Freier Heap 168 kB, WLAN −53 dBm, System Gesundheit
🟢 Stabil. Der Konfig-Hash steht auf `0x09da4f1e`, das `project`-Feld meldet
`tsgwiro1.wp-solar-monitor` 1.0.0. Der Power-Sensor trägt in Home Assistant
jetzt `state_class: measurement`.

Keine Fehler im Log. Zwei Hinweise ohne Auswirkung auf diese Version:

* **«Bootloader too old for OTA rollback and SRAM1 as IRAM (+40KB)»** - der
  Bootloader stammt aus der Erstinbetriebnahme. Das Gerät hat damit kein
  automatisches Rollback auf die vorige Firmware und verzichtet auf 40 kB IRAM.
  Erneuern geht nur per USB; solange die RAM-Auslastung bei 27.9 % liegt, ist es
  keine Dringlichkeit.
* **Die Ampel «4.0 System Gesundheit» stand nach dem Boot 56 s auf 🔴
  Kritisch**, obwohl 168 kB Heap frei waren, und sprang dann auf 🟢 Stabil. Das
  ist ein Startverhalten von `common/diagnostics.yaml`, nicht dieses Geräts: das
  Lambda liest `raw_heap_free.state`, der beim ersten Durchlauf noch `nan` ist,
  und `nan` fällt durch beide Schwellwertvergleiche in den kritischen Ast. Gehört
  in `common` behandelt, nicht hier.
