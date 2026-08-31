# Changelog - wp-speicher-monitor

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.1.0] - 2026-08-31

### Neu: Fühler-Watchdog

Bisher konnte ein Fühler aufhören zu melden, ohne dass es auffiel: Sein letzter
Wert blieb in den internen Globals stehen, und Schichterkennung wie Display
rechneten unbegrenzt damit weiter.

* **Alterungsprüfung je Fühler.** Jede gültige Meldung schreibt einen
  Zeitstempel in das neue Global `s_last_ok`. Ein Intervall prüft alle 10 s, ob
  dieser länger als `sensor_timeout_ms` (neu, 300000 ms) zurückliegt - das
  entspricht drei ausgelassenen Meldungen bei einem 100-s-Takt.
* **Verworfene Werte werden nicht mehr weiterverwendet.** Ein als veraltet
  erkannter Fühler bekommt `NAN` in `s_temps` und einen schwarzen Farbbalken.
* **«Layer Position» und «Highest Temp Difference» melden `NAN`**, sobald auch
  nur ein Fühler fehlt. In Home Assistant stehen sie damit auf `unknown`, statt
  eine Schichtung aus veralteten Zahlen zu behaupten.
* **Neuer Binärsensor «1.0 Fuehler Watchdog»** (`device_class: problem`,
  `entity_category: diagnostic`). Bis zum ersten Ablauf der Frist nach einem
  Neustart meldet er bewusst kein Problem.
* **Das Display behauptet keine Zahl mehr, die nicht mehr gilt** - ein
  veralteter Fühler wird als `--.-°C` angezeigt.
* **NAN-Werte kommen nicht mehr in die Globals.** Die `on_value`-Lambdas der
  vier Fühler steigen bei `NAN` sofort aus.

Die Prüfung ist bewusst zeitgesteuert und hängt **nicht** an `on_value` - dort
löst ein Fühler, der aufgehört hat zu melden, definitionsgemäss nichts mehr aus.
Die Differenz zweier `uint32_t` trägt den `millis()`-Überlauf nach 49 Tagen.

### Korrektur an der Dokumentation zu V1.0.0

Der Punkt «Erste 100 s nach dem Neustart ohne Anzeige» **war falsch** und ist
entfernt. `sliding_window_moving_average` hat `send_first_at: 1` als Vorgabe und
reicht den ersten Messwert sofort durch; erst danach greift `send_every: 10`.
Anzeige und abgeleitete Werte stehen also schon nach der ersten Messung. Die
ursprüngliche Aussage stammte aus einem Logmitschnitt, der erst nach dem Boot
begann und die erste Meldung deshalb nicht enthielt.

### Geprüfter Ausfallpfad

Der Watchdog ist nicht nur eingebaut, sondern ausgelöst worden. Dafür lief am
2026-08-31 vorübergehend ein Build mit `sensor_timeout_ms: 15000` auf dem Gerät:

| Zeit | Ereignis |
| :--- | :--- |
| 16:42:28 | S1-S4 nach 19.6-21.1 s ohne Wert verworfen, vier `[W][watchdog]`-Zeilen |
| 16:42:29 | «Layer Position» meldet `nan` |
| 16:42:36 | «Highest Temp Difference» meldet `nan` |
| - | In HA: Binärsensor `on`, beide Sensoren `unknown`, `sensor.s1` unverändert 77.5 °C |
| 16:43:48 | frischer S1-Wert |
| 16:43:49 | «Layer Position» wieder 25 % - Erholung ohne Zutun |

Danach wurde die Frist auf 300000 ms zurückgesetzt und neu gebaut und geflasht.

### Geflashter Stand

Per OTA eingespielt und geprüft am 2026-08-31, ESPHome 2026.8.2,
Config-Hash `0x2066078d`, `project` 1.1.0. Nach dem Neustart alle vier Fühler am
Bus, S1 77.5 / S2 66.0 / S3 66.6 / S4 64.4 °C, Layer Position 25 %, Watchdog
`off`. Keine Fehler im Log; die beiden bekannten Meldungen «Bootloader supports
SRAM1 as IRAM» und «safe_mode took a long time» sind folgenlos.

**Was der Watchdog nicht leistet:** `sensor.s1` behält bei einem Ausfall seinen
letzten Wert. Der `wp-zwe2-controller` nutzt genau diesen Sensor als
Speicherverriegelung für einen 4.5-kW-Heizstab und prüft ihn nicht auf Alter.
Diese Lücke bleibt offen und ist dort zu schliessen, nicht hier.

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

> **Nachtrag zu V1.1.0: Dieser Abschnitt war falsch.** `send_first_at: 1` reicht
> den ersten Messwert sofort durch. Siehe die Korrektur unter [1.1.0].

Die vier Speicherfühler publizieren erst nach dem zehnten Messzyklus, also rund
100 s nach dem Start. Bis dahin sind die Farb-Globals und `s_temps` noch leer:
Die Balken auf dem Display bleiben schwarz, die Temperaturtexte zeigen `nan`,
und «Layer Position» rechnet auf Nullwerten. Das ist bestehendes Verhalten und
betrifft nur die erste Minute nach einem Neustart - eine Vorbelegung der Globals
aus dem Rohwert wäre eine Verbesserung für eine spätere Version.
