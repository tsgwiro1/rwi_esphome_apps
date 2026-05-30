# Changelog - wp-fp1-smartblock

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert. Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/) und diese Versionierung folgt dem [Semantic Versioning](https://semver.org/lang/de/).

---

## [1.0.0] - 2026-05-29

### Hinzugefügt
- **Initialer Release:** Vollständige Inbetriebnahme des Projekts für das Seeed Studio XIAO ESP32-C6 Modul zur intelligenten, PV-optimierten Steuerung der Heizkreispumpe (FP1).
- **Prioritäten-Kaskade:** Implementierung eines sekündlich prüfenden Sicherheits-Baums im ESP32-Core (`Überhitzung -> WLAN -> API-Ausfall -> Hauptschalter -> Übersteuerung -> Automatik`).
- **Hardware-Schutz:** Integration des DS18B20-Temperatursensors (`GPIO21`) als lokaler Überhitzungsschutz mit konfigurierbarem Schwellwert (Default: 50°C).
- **Intelligentes Backlight:** Automatische Abschaltung der Display-Hintergrundbeleuchtung (`GPIO3`) bei Dunkelheit via LDR (`GPIO2`), stabilisiert durch einen gleitenden Mittelwert-Filter (`sliding_window_moving_average` über 5 Messungen).
- **Dummy-CS-Pin:** Belegung eines virtuellen, nicht herausgeführten Pins (`GPIO23`) als SPI-Chip-Select für das ST7735-Display. Dadurch bleibt der I2C-Bus (`D4`/`D5`) für zukünftige Hardware-Erweiterungen vollständig frei.
- **Home Assistant native Entities:** Bereitstellung von Slidern (`number`) für Schwellwert, Hysterese und Überhitzungslimit sowie Schaltern (`switch`) für Hauptschalter und Übersteuerung direkt vom ESP aus. Alle Entitäten sind als `config` kategorisiert.
- **Zustandsspeicherung:** Aktivierung von `restore_value: true` und passenden `restore_mode`-Optionen, damit der ESP alle Einstellungen bei einem Stromausfall lokal behält und autark startet.
- **Lokaler Webserver:** Aktivierung des `web_server`-Moduls auf Port 80, um Statuswerte und Steuerungsmöglichkeiten auch bei komplettem HA-Ausfall im Browser bereitzustellen.
- **Erweiterte UI-Zustände:** Vollbild-Fehlermeldungen und zentrierte Groß-Icons für alle blockierenden Systemzustände (`mdi:thermometer-alert`, `mdi:wifi-off`, `mdi:api-off`, `mdi:power`, `mdi:pump-off`).
- **Read-Only Status-Sensoren:** Binärsensoren für den exakten Relais-Zustand und den Backlight-Status zur sauberen Visualisierung in Home Assistant.

### Geändert
- **Versions-Anpassung:** Projektversion im `esphome`-Konfigurationsblock offiziell auf `1.0.0` angehoben.
- **Entkopplung der Hardware-Ebene:** Das physische Relais (`GPIO22`) und der Backlight-Ausgang wurden auf `internal: true` gesetzt. Sie können von Home Assistant nicht mehr direkt manipuliert werden, um Fehlbedienungen auszuschließen. Die Steuerung erfolgt ausschließlich über das interne Regelwerk.

### Sicherheit
- **Fail-Safe-Verdrahtung:** Das Relais agiert als Öffner (Normally Closed). Bei jeglicher logischer Störung (Überhitzung, WLAN weg, API für > 1h getrennt) fällt das Relais ab. Dadurch wird der Stromkreis geschlossen und die Hoheit augenblicklich und zu 100% an die originale Heizungssteuerung zurückgegeben.
