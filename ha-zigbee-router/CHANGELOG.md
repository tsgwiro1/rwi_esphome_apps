# Changelog - ha-zigbee-router

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.0.0] - 2026-11-12

### Erstrelease

* **Zigbee-Router** auf dem XIAO ESP32-C6 mit der ESPHome-eigenen
  Zigbee-Komponente (`router: true`), ESP-IDF.
* **Baustein und Instanzen:** `ha-zigbee-router.yaml` enthält die ganze Logik,
  je Router eine Instanzdatei mit Name, Antenne und API-Schlüssel. Erste
  Instanz `ha-zigbee-router-01`.
* **Antennenwahl** per Substitution `antenne: extern|intern` über GPIO3/GPIO14.
* **WLAN nur in Fenstern:** `enable_on_boot: false`. Schalter «1.0 WLAN
  Wartung» öffnet ein Wartungsfenster von 15 min für OTA, nach jedem Start
  öffnet ein Notfenster von 3 min. `reboot_timeout: 0s` für WLAN und API,
  weil im Normalbetrieb keine Verbindung besteht.
* **OTA** verschlüsselt über `common/ota.yaml`.
* **Statistik über Zigbee:** Laufzeit, Chiptemperatur, freier Speicher und
  Anzahl Zigbee-Kinder als Zigbee-Endpunkte, über Zigbee2MQTT in HA.
* **Status-LED** an GPIO15: an bei offenem WLAN-Fenster, blinkt ohne
  Zigbee-Netz, sonst aus.

### Geflashter Stand

`ha-zigbee-router-01` am 2026-11-12 per USB geflasht und geprüft, ESPHome
2026.10.1 und Zigbee2MQTT 2.14.3. Anmeldung, Notfenster, Wartungsfenster und
verschlüsselter OTA funktionieren; nach dem OTA-Neustart tritt der Router ohne
«Permit join» wieder bei. Zigbee2MQTT arbeitet mit einer selbst erzeugten
Definition.
