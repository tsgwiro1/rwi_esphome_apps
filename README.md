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
| [**`wp-fp1-smartblock`**](./wp-fp1-smartblock) | Intelligente, PV-optimierte Steuerung für die Heizkreispumpe (FP1) auf Basis eines XIAO ESP32-C6. Beinhaltet eine ausfallsichere Logik (NC-Verdrahtung) mit 7-stufiger Prioritäten-Kaskade, Sensor-Watchdog, lokale LDR-Displaysteuerung (ST7735) und einen DS18B20-Überhitzungsschutz. | v1.0.3 (Aktiv) |
| [**`ha-smartrelais`**](./ha-smartrelais) | Zeitgesteuertes SSR-Relais (ESP32-C6) nach dem Treppenlicht-Prinzip: Wandschalter startet eine einstellbare Einschaltdauer. Mit DS18B20-Übertemperaturschutz inkl. Wiedereinschaltsperre, Status-LED, Tageslimit und Betriebsstundenzählern. | v1.0.1 (Aktiv) |
| [**`ha-irrigation`**](./ha-irrigation) | Vollautomatische ESP8266 (D1 Mini) Bewässerungssteuerung für bis zu 4 Zonen. Beinhaltet regenabhängige (48h) Laufzeitberechnung, Temperatur-Checks, eine ausfallsichere State-Machine mit Resume-Fähigkeit nach Reboots sowie umfangreiche Sicherheitsmechanismen (Not-Aus, Auto-Timeouts). | v1.1.2 (Aktiv) |
| [**`ha-weather-station`**](./ha-weather-station) | ESP32-Wetterstation mit Temperatur, Luftfeuchte, Luftdruck und Taupunkt (AM2315, SHT31, BMP280). Frequenzbasierte Regenerkennung mit selbstlernender Trockenfrequenz und Hysterese, PID-geregelte Sensorheizung über Taupunkt sowie ein Anti-Kondensations-Zyklus für den SHT31. | v1.0.1 (Aktiv) |
| [**`ha-frontroom-info-display`**](./ha-frontroom-info-display) | Wandmontiertes 2.8"-Touchdisplay (ESP32-2432S028R) mit fünf Seiten: Übersicht, Wallbox-Detail, Ladeplan-Eingabe, Hausbatterie mit 24-h-Graph und animiertes Energieflussbild. Steuert den evcc-Lademodus und den SoC-Ladeplan direkt per REST, zusätzlich über zwei Hardware-Taster mit Status-LEDs und zwei Template-Schalter in HA. | v1.3.1 (Aktiv) |
| [**`ha-flowmeter`**](./ha-flowmeter) | Impulszähler für Wasser auf einem D1 Mini. Liest den Reedkontakt eines Wasserzählers und bildet daraus Durchflussrate (L/min) und einen neustartfesten Gesamtzähler in Litern. Die Impulse pro Liter sind aus Home Assistant heraus einstellbar, der Zählerstand dort rücksetzbar; eine LED am Gerät blitzt bei jedem Impuls. | v1.0.0 (Aktiv) |
| [**`wp-speicher-monitor`**](./wp-speicher-monitor) | ESP32-Schichtungsanzeige für den Wärmespeicher. Vier fest adressierte DS18B20 über die Speicherhöhe liefern das Temperaturprofil, daraus wird die Höhe der Sprungschicht und die grösste Nachbardifferenz abgeleitet. Ein 2.4"-ILI9xxx-Display zeigt die Schichten als Farbbalken mit Markierung der Schichtgrenze, dazu Heizraumklima per DHT; die Beleuchtung schaltet ein LDR mit Hysterese. | v1.0.0 (Aktiv) |
| [**`wp-solar-monitor`**](./wp-solar-monitor) | ESP32-Wärmemengenzähler für den Solarkreis. Aus Vorlauf-, Rücklauftemperatur (DS18B20) und dem Kontakt der Solarpumpe wird alle 5 s eine Energie-Zeitscheibe gebildet und zu Tagesenergie und Momentanleistung verrechnet; Durchfluss, Dichte und Wärmekapazität sind aus Home Assistant einstellbar. Ein 280x240-ST7789V-Display zeigt das Anlagenschema mit Temperaturen, Leistung, Tagesertrag und Pumpenlaufzeit, die Beleuchtung schaltet ein LDR mit Hysterese. | v1.0.0 (Aktiv) |
| [**`wp-zwe2-controller`**](./wp-zwe2-controller) | ESP32-Steuerung für den zweiten Wärmeerzeuger (Heizstab 4.5 kW) im Wärmespeicher. Aus Zählerwirkleistung, Batterieentladung und einer Mindestreserve wird alle 5 s der PV-Überschuss gerechnet und als Sollwert von 0 bis 100 % über den DAC auf ein 0-10-V-Leistungsmodul gegeben, mit kalibrierbarer Spannungskennlinie und Mindestansteuerung. Vier Verriegelungen (Modulübertemperatur, Speicher geladen, fehlende Modulspannung, Hauptschalter) nehmen die Leistung auf 0, ein Override fährt Volllast. Kühlkörperlüfter mit Hysterese, dazu ein LED-Board über PCF8574 mit Leistungsbalken, Übertemperatur-, Modul- und WLAN-Anzeige. | v1.0.0 (Aktiv) |
| [**`ha-mini-display`**](./ha-mini-display) | TTGO T-Display (ESP32, 1.14"-ST7789V) als Statusmonitor ohne eigene Logik. Blättert im 5-Sekunden-Takt durch fünf Seiten – Fahrzeug, Wallbox, PV-Leistung, Hausbatterie und Wetter – und speist sie aus zwölf Home-Assistant-Entitäten. Ladestände erscheinen in Farb- und Symbolstufen, das Wetter als animiertes GIF, dessen Zustandstext alle fünfzehn HA-Wetterzustände abdeckt. Die zwei Taster des Boards blättern von Hand, halten die Rotation an und schalten die Beleuchtung. | v1.0.1 (Aktiv) |
| [**`common`**](./common) | Wiederverwendbare Code-Bausteine (Packages), aktuell das Diagnose-Paket `diagnostics.yaml` mit WLAN-, Netzwerk- und System-Sensoren für alle Projekte. | v1.4.1 |

---

## Allgemeine Hinweise zur Verwendung

**Geheimnisse schützen:** Passwörter, WLAN-SSIDs und API-Keys sind in den jeweiligen Projekt-YAMLs über `!secret` ausgelagert. Vor dem Flashen muss eine entsprechende `secrets.yaml` im Verzeichnis existieren.
