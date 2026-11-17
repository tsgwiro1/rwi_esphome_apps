# Changelog - ha-samsung-klima

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [0.1.0] - 2026-11-17

### Vorbereitung im Erkennungsbetrieb

* **Plattform:** M5Stack ATOM Lite auf der Atomic RS485 Base,
  `board: m5stack-atom`, ESP-IDF mit `sram1_as_iram` (Bootloader vom
  Erstflash per USB).
* **Bus:** `uart` an GPIO19 (TX) und GPIO22 (RX), 9600 Baud, Parität EVEN.
* **Komponente `samsung_ac`** von omerfaruk-aran/esphome_samsung_hvac_bus,
  gepinnt auf Commit `53b0773` (Stand 2026-11-06).
* **Erkennungsbetrieb:** leere Liste `devices`, die Komponente meldet die
  Busadressen ins Log. `debug_log_messages_on_change` ist für die
  Inbetriebnahme eingeschaltet.
* **Status-LED** (SK6812 an GPIO27): rot blinkend ohne WLAN oder HA, blau
  blinkend ohne Busdaten, grüner Blitz bei Busdaten, weiss vor dem Neustart.
  Den Empfang meldet ein Debug-Haken am UART. In HA abschaltbar über
  «Status-LED».
* **Taste** (GPIO39): kurz drücken löst das Ereignis `press` an «Taste» aus,
  ab 3 s gehalten startet das Gerät beim Loslassen neu.
* **Packages** `common/diagnostics.yaml` mit den ESP32-Heapgrenzen
  (80 kB / 40 kB) und `common/ota.yaml`, dazu Fallback-Hotspot und Webserver
  auf Port 80 ohne OTA.
