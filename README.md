# Smart Home & ESPHome Projekte

[![ESPHome](https://img.shields.io/badge/ESPHome-Ready-03a9f4?logo=esphome&logoColor=white)](https://esphome.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Willkommen in meinem zentralen Repository für alle ESPHome-basierten Smart-Home-Projekte. Hier verwalte und sichere ich die Konfigurationen für meine selbstgebauten Mikrocontroller-Steuerungen auf ESP32- und ESP8266-Basis.

---

## ⚠️ Haftungsausschluss (Disclaimer)

Alle in diesem Repository bereitgestellten Inhalte, Codes und Pläne sind rein private Bastelprojekte. Die Verwendung erfolgt ausdrücklich **auf eigene Gefahr**. Es wird keinerlei Haftung für Schäden an Geräten, Haustechnik oder für Unfälle übernommen. Arbeiten an Netzelektrik (230V) dürfen nur von ausgebildetem Fachpersonal durchgeführt werden.

---

## Repository-Struktur

Um die Wartung so einfach wie möglich zu halten, ist dieses Repository als Monorepo strukturiert. Jedes eigenständige Projekt besitzt seinen eigenen Unterordner inklusive lokaler Dokumentation.

| Ordner / Projekt | Kurzbeschreibung | Status / Version |
| :--- | :--- | :--- |
| [**`wp-fp1-smartblock`**](./wp-fp1-smartblock) | Intelligente, PV-optimierte Steuerung für die Heizkreispumpe (FP1) auf Basis eines XIAO ESP32-C6. Beinhaltet eine ausfallsichere Logik (NC-Verdrahtung) mit 7-stufiger Prioritäten-Kaskade, Sensor-Watchdog, lokale LDR-Displaysteuerung (ST7735) und einen DS18B20-Überhitzungsschutz. | v1.0.2 (Aktiv) |
| [**`ha-smartrelais`**](./ha-smartrelais) | Zeitgesteuertes SSR-Relais (ESP32-C6) nach dem Treppenlicht-Prinzip: Wandschalter startet eine einstellbare Einschaltdauer. Mit DS18B20-Übertemperaturschutz inkl. Wiedereinschaltsperre, Status-LED, Tageslimit und Betriebsstundenzählern. | v1.0.0 (Aktiv) |
| [**`ha-irrigation`**](./ha-irrigation) | Vollautomatische ESP8266 (D1 Mini) Bewässerungssteuerung für bis zu 4 Zonen. Beinhaltet regenabhängige (48h) Laufzeitberechnung, Temperatur-Checks, eine ausfallsichere State-Machine mit Resume-Fähigkeit nach Reboots sowie umfangreiche Sicherheitsmechanismen (Not-Aus, Auto-Timeouts). | v1.1.0 (Aktiv) |
| [**`common`**](./common) | Wiederverwendbare Code-Bausteine (Packages), aktuell das Diagnose-Paket `diagnostics.yaml` mit WLAN-, Netzwerk- und System-Sensoren für alle Projekte. | v1.2.1 |

---

## Allgemeine Hinweise zur Verwendung

**Geheimnisse schützen:** Passwörter, WLAN-SSIDs und API-Keys sind in den jeweiligen Projekt-YAMLs über `!secret` ausgelagert. Vor dem Flashen muss eine entsprechende `secrets.yaml` im Verzeichnis existieren.
