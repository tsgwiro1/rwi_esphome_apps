# Changelog - ha-flowmeter

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.0.0] - 2026-07-30

### Erstrelease

Aufnahme des bereits im Betrieb stehenden Wasserzählers ins Repository. Der
funktionale Stand entspricht dem, was auf dem Gerät läuft; ergänzt wurden nur
die repo-seitig zwingenden Punkte (siehe unten).

* **Plattform:** ESP8266 auf einem Wemos D1 Mini (`board: d1_mini`).
* **Impulszählung** über `pulse_meter` an GPIO5 (D1). `internal_filter: 100ms`
  entprellt den Reedkontakt, `timeout: 60s` setzt die Durchflussrate auf 0,
  wenn eine Minute lang kein Impuls kommt.
* **Durchflussrate** «Wasser Durchflussrate» in L/min. Ein Lambda-Filter teilt
  die Impulse pro Minute durch die eingestellte Impulszahl pro Liter und liefert
  0, wenn der Kalibrierwert nicht positiv ist.
* **Kalibrierung aus Home Assistant** über die `number`-Entität «Konfig:
  Impulse pro Liter» (0.1…1000 imp/L, Schrittweite 0.1, `mode: box`,
  `entity_category: config`). Der Wert liegt in einem neustartfesten Global,
  Vorgabe 1.0 imp/L.
* **Neustartfester Gesamtzähler:** Jeder Impuls erhöht das Global
  `total_water_liters` um `1 / imp_pro_liter`. Der sichtbare Template-Sensor
  «Wasser Gesamtmenge» (L, `state_class: total_increasing`) gibt diesen Wert
  aus und wird bei jedem Impuls sofort aktualisiert.
* **Reset-Knopf** «Reset Gesamtzähler» (`entity_category: config`) für den
  Saisonstart: setzt den Zählerstand auf 0 und aktualisiert den Sensor
  unmittelbar.
* **Aktivitätsanzeige:** Die LED an GPIO2 (D4) blitzt bei jedem Impuls 100 ms
  auf 100 % und blendet danach über 0.5 s weich aus. Das Light ist
  `internal: true`, also nur lokale Anzeige ohne HA-Entität.
* **Status-LED** an GPIO0 (D3, invertiert) über `status_led` für den
  Verbindungszustand.
* **Ungenutzte LEDs** an GPIO12 (D6) und GPIO13 (D7) werden im
  `on_boot`-Block mit Priorität −100 gezielt ausgeschaltet.
* **Lokaler Webserver** (`web_server` v3, Port 80, ohne OTA) als Zugang bei
  einem HA-Ausfall, dazu Fallback-AP mit Captive Portal.
* Gemeinsames Diagnose-Paket `common/diagnostics.yaml` eingebunden, mit den
  ESP8266-Vorgabewerten für die Heap-Grenzen (15 kB / 8 kB).

### Für die Repo-Aufnahme geändert

* **Zugangsdaten über `!secret` ausgelagert.** API-Key, OTA-Passwort und die
  Zugangsdaten des Fallback-AP standen bisher im Klartext in der YAML. Neu:
  `flowmeter_api_key`, `flowmeter_ota_key`, `flowmeter_fallback_ap_ssid` und
  `flowmeter_fallback_ap_password`. Die Werte sind unverändert übernommen, es
  wurde nichts rotiert.
* **`fw_version`-Substitution und `project:`-Block ergänzt**, damit der
  Firmwarestand am Gerät ablesbar ist und die Versionierung des Repos greift.
* **`friendly_name: ha-flowmeter` gesetzt**, entsprechend der Konvention der
  übrigen Geräte.

Diese drei Punkte sind nicht funktional, brauchen aber einen Flash, damit
Gerät und Repo denselben Stand tragen.

### Geflashter Stand

Per OTA eingespielt und geprüft am 2026-07-30. Der Flash hat zwei weitere
Stände nachgezogen, die nicht Teil dieser Änderung sind:

* **ESPHome 2026.6.2 → 2026.7.3** (Stand der lokalen Toolchain).
* **`common/diagnostics.yaml` 1.2.1 → 1.3.0**, damit auch die Dedup-Filter der
  interpretierenden Text-Sensoren.

Der Zählerstand hat den OTA erwartungsgemäss überlebt (14622 L vorher,
unmittelbar danach 14623 L bei laufendem Verbrauch), ebenso der Kalibrierwert
von 1.0 imp/L.
