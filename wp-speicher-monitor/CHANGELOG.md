# Changelog - wp-speicher-monitor

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.0.0] - 2026-07-30

### Erstrelease

Aufnahme des bereits im Betrieb stehenden Schichtungsmonitors am Wärmespeicher
ins Repository. Der funktionale Stand entspricht dem, was auf dem Gerät läuft;
ergänzt wurden nur die repo-seitig zwingenden Punkte (siehe unten).

* **Plattform:** ESP32 auf `board: esp32dev` mit ESP-IDF-Framework,
  `minimum_chip_revision: "3.0"`.
* **Vier Speicherfühler:** DS18B20 am 1-Wire-Bus (GPIO25), fest über ihre
  ROM-Adresse zugeordnet, damit S1…S4 nach einem Sensortausch nicht
  durcheinandergeraten. S1 sitzt oben, S4 unten. Auflösung 10 bit, Abfrage alle
  10 s, geglättet über ein gleitendes Mittel von 10 Werten (meldet also
  ungefähr alle 100 s).
* **Heizraumklima:** DHT an GPIO5 liefert «Boiler Room Temperature» und «Boiler
  Room Humidity», Abfrage alle 10 s, gleitendes Mittel über 6 Werte.
* **Schichtgrenze:** Der Template-Sensor «Layer Position» (%) vergleicht die
  drei Nachbarpaare S1/S2, S2/S3 und S3/S4. Das Paar mit der grössten Differenz
  über 8 K bestimmt die Sprungstelle, ausgegeben als 25 % (S1/S2), 50 % (S2/S3)
  oder 75 % (S3/S4), gezählt von oben. Findet sich kein Sprung über 8 K, bleibt
  der Wert 0 - der Speicher gilt dann als durchmischt.
* **Spreizung:** «Highest Temp Difference» (°C) gibt die grösste gefundene
  Nachbardifferenz aus. Beide Template-Sensoren rechnen alle 10 s auf den in
  Globals abgelegten Temperaturen.
* **Display:** ILI9xxx «TFT 2.4» (240x320) über SPI, um 180° gedreht,
  Farbpalette 8BIT, 20 MHz. Zeigt Kopfzeile mit WLAN-Symbol, Heizraum-Temperatur
  und -Feuchte, vier farbige Schichtbalken mit den zugehörigen Temperaturen,
  einen Pfeil an der erkannten Schichtgrenze sowie Datum und Uhrzeit aus Home
  Assistant.
* **Temperatur-Farbrampe:** Das Script `calc_color` bildet einen Messwert auf
  RGB ab - unter 15 °C blau (0,76,153), bis 23 °C nach Reinblau, bis 39 °C nach
  Magenta/Rot, bis 65 °C nach Rot, darüber in Richtung Orange (255,153,0). Jeder
  Fühler legt sein Ergebnis in einem eigenen Global ab, aus dem das Display den
  Balken füllt.
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
  `speichermonitor_api_key`, `speichermonitor_ota_key`,
  `speichermonitor_fallback_ap_ssid` und `speichermonitor_fallback_ap_password`.
  Die Werte sind unverändert übernommen, es wurde nichts rotiert.
* **`fw_version`-Substitution und `project:`-Block ergänzt**, damit der
  Firmwarestand am Gerät ablesbar ist und die Versionierung des Repos greift.

Beide Punkte sind nicht funktional, brauchen aber einen Flash, damit Gerät und
Repo denselben Stand tragen.

### Geflashter Stand

Per OTA eingespielt und geprüft am 2026-07-30 (192.168.0.172). Der Flash hat
zwei weitere Stände mitgezogen, die nicht zu dieser Version gehören, sondern nur
zum Zeitpunkt:

* **ESPHome 2026.6.2 → 2026.7.3**, entsprechend der lokal installierten CLI.
  Das Display initialisiert unverändert (ILI9xxx, 240x320, 8bit-332, BGR,
  Mirror-X, 20 MHz) - die `mipi_spi`-Regression, die `wp-fp1-smartblock` auf
  2026.5.3 festhält, betrifft dieses Gerät nicht.
* **`common/diagnostics.yaml` 1.2.1 → 1.3.0.**

Nach dem Neustart gefunden und gemeldet: alle vier DS18B20 am Bus mit ihren
erwarteten Adressen, «Boiler Room Temperature» 34.1 °C, «Boiler Room Humidity»
36 %, «Highest Temp Difference» 14.0 °C, «Layer Position» 25 %. Freier Heap
150 kB, WLAN −51 dBm, System Gesundheit 🟢 Stabil. Der Konfig-Hash steht auf
`0x36aad586`, das `project`-Feld meldet `tsgwiro1.wp-speicher-monitor` 1.0.0.
Keine Fehler im Log; die beiden Meldungen «Bootloader supports SRAM1 as IRAM»
und «safe_mode took a long time (78 ms)» sind Hinweise ohne Auswirkung.

### Beobachtung für später

Die vier Speicherfühler publizieren erst nach dem zehnten Messzyklus, also rund
100 s nach dem Start. Bis dahin sind die Farb-Globals und `s_temps` noch leer:
Die Balken auf dem Display bleiben schwarz, die Temperaturtexte zeigen `nan`,
und «Layer Position» rechnet auf Nullwerten. Das ist bestehendes Verhalten und
betrifft nur die erste Minute nach einem Neustart - eine Vorbelegung der Globals
aus dem Rohwert wäre eine Verbesserung für eine spätere Version.
