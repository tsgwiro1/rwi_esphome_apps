# wp-fp1-smartblock - Intelligente Heizkreispumpensteuerung

![Version](https://img.shields.io/badge/version-1.0.0-blue)
[![ESPHome](https://img.shields.io/badge/ESPHome-Ready-03a9f4?logo=esphome&logoColor=white)](https://esphome.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Dieses ESPHome-Projekt steuert die Heizkreispumpe (FP1) einer Wärmepumpe in Abhängigkeit von der gemittelten Außentemperatur. Es dient dazu, die Effizienz der Heizungsanlage im Sommerbetrieb zu maximieren, wenn die Wärmepumpe zur PV-Überschussladung verwendet wird.

---

## Haftungsausschluss (Disclaimer)

⚠️ **WICHTIGER HINWEIS: VERWENDUNG AUF EIGENE GEFAHR!** ⚠️

Dieses Projekt beschreibt ein privates Bastelprojekt zur Optimierung der eigenen Hausautomatisierung. Die Nutzung, der Nachbau sowie das Einspielen des bereitgestellten Codes und der Konfigurationen erfolgen ausdrücklich auf **eigene Gefahr und eigenes Risiko**. 

Der Autor übernimmt **keinerlei Haftung, Gewährleistung oder Verantwortung** für:
* **Schäden jeglicher Art** an der Wärmepumpe, den Heizkreispumpen, der Heizungssteuerung oder anderen Komponenten der Haustechnik.
* **Folgeschäden** durch Fehlfunktionen der Steuerung (z. B. unbemerktes Auskühlen des Hauses, Frostschäden, mangelnde Warmwasserversorgung oder Überhitzung).
* **Elektrische Unfälle oder Verletzungen**: Der Anschluss des Relais greift in die Stromversorgung (Netzspannung) der Pumpe ein. Arbeiten an 230V-Netzspannung sind lebensgefährlich und dürfen ausschließlich von einer **zertifizierten Elektrofachkraft** durchgeführt werden!
* Die Richtigkeit, Aktualität oder Vollständigkeit des bereitgestellten Codes, des Schaltplans oder der Dokumentation.

Mit der Verwendung dieses Codes oder Nachbau der Hardware erklärst du dich damit einverstanden, auf jegliche Schadensersatzansprüche gegenüber dem Autor zu verzichten.

---

## 1. Hintergrund & Problemstellung

Um eine Wärmepumpe (WP) im Sommer effizient mit Überschussenergie aus einer Photovoltaikanlage zur Speicherladung zu nutzen, muss die Anlage oft das ganze Jahr über im **Winterbetrieb** verbleiben. 

**Das Problem:** Im Winterbetrieb läuft die Heizkreis-Zirkulationspumpe (FP1) permanent durch. Obwohl das Haus im Sommer nicht geheizt wird (da der Heizkreismischer aufgrund der niedrigen Sollwerte schließt), verbraucht die Pumpe unnötig Strom. 

**Die Lösung:** Der `wp-fp1-smartblock` wird in Serie in die Stromversorgung der Pumpe geschaltet. Sobald die von Home Assistant gelieferte Mitteltemperatur einen definierten Schwellwert überschreitet, trennt der ESP32-C6 den Stromkreis der Pumpe und schaltet sie somit effektiv aus.

---

## 2. Sicherheitskonzept (Fail-Safe Architecture)

Da es sich hierbei um einen Eingriff in die Heizungssteuerung handelt, steht Betriebssicherheit an oberster Stelle. 

### Physische Verdrahtung (NC - Normally Closed)
Das Relais **muss** als **Öffner (Normally Closed / NC)** verdrahtet werden:
* **Relais AUS (stromlos / Failsafe):** Der Stromkreis ist geschlossen. Die originale Heizungssteuerung hat die volle Kontrolle über die Pumpe (wichtig für den Winterbetrieb oder bei Stromausfall des ESP).
* **Relais EIN (aktiviert):** Der ESP unterbricht den Stromkreis aktiv. Die Pumpe wird zwangsweise ausgeschaltet (Sommer-Sparbetrieb).

### Die Prioritäten-Kaskade (Logik-Pyramide)
Die interne Steuerungslogik prüft jede Sekunde eine strikte Hierarchie ab. Höhere Prioritäten oversized niedrigere Zustände immer:

1. **Priorität 1: Überhitzungsschutz (Lokal)**
   * *Bedingung:* Die über den internen DS18B20-Sensor gemessene Gehäusetemperatur überschreitet das eingestellte Limit (Standard: 50°C).
   * *Aktion:* Relais fällt ab (**Pumpe EIN** / Heizungskontrolle). Display zeigt eine rote Überhitzungswarnung (`mdi:thermometer-alert`).
2. **Priorität 2: WLAN-Ausfall (Lokal)**
   * *Bedingung:* Die Verbindung zum lokalen Netzwerk bricht ab.
   * *Aktion:* Relais fällt ab (**Pumpe EIN**). Display zeigt ein rotes WLAN-Aus-Symbol (`mdi:wifi-off`).
3. **Priorität 3: Home Assistant API-Ausfall (> 1 Stunde)**
   * *Bedingung:* Die Verbindung zur Home Assistant API ist für mehr als 3600 Sekunden unterbrochen.
   * *Aktion:* Relais fällt ab (**Pumpe EIN**). Display zeigt ein API-Fehlersymbol (`mdi:api-off`).
4. **Priorität 4: Hauptschalter AUS (Über HA/Webserver)**
   * *Bedingung:* Der virtuelle Hauptschalter steht auf `OFF`.
   * *Aktion:* Relais fällt ab (**Pumpe EIN**). Display zeigt das Power-Symbol (`mdi:power`).
5. **Priorität 5: Übersteuerung EIN (Über HA/Webserver)**
   * *Bedingung:* Der Übersteuerungsschalter steht auf `ON`.
   * *Aktion:* Relais zieht an (**Pumpe zwingend AUS**), um z.B. manuelle Wartungsarbeiten zu ermöglichen. Display zeigt ein großes Pumpen-Aus-Symbol (`mdi:pump-off`).
6. **Priorität 6: Automatikmodus (Normalbetrieb)**
   * *Bedingung:* Alle obigen Prüfungen sind im grünen Bereich.
   * *Logik:*
     * Wenn `Mitteltemperatur` > `Schwellwert` -> Relais EIN (**Pumpe AUS**).
     * Wenn `Mitteltemperatur` < (`Schwellwert` - `Hysterese`) -> Relais OFF (**Pumpe EIN**).

---

## 3. Hardware & Pinout (XIAO ESP32-C6)

Das Projekt basiert auf dem kompakten Seeed Studio XIAO ESP32-C6 Modul und einem ST7735 TFT-Display (80x160 Pixel).

| Peripherie / Funktion | XIAO Board Pin | Interner GPIO | Beschreibung / Besonderheit |
| :--- | :---: | :---: | :--- |
| **LDR (ADC)** | D0 | `GPIO2` | Misst die Umgebungshelligkeit zur Displaysteuerung |
| **Backlight Control** | D1 | `GPIO3` | Schaltet die Hintergrundbeleuchtung des LCDs (An/Aus) |
| **LCD Reset** | D2 | `GPIO4` | Display Reset Pin |
| **LCD D/C** | D3 | `GPIO5` | Display Data/Command Pin |
| **DS18B20 Temp** | D6 | `GPIO21` | Lokaler Temperatursensor auf der Platine (Überhitzungsschutz) |
| **Relais** | D7 | `GPIO22` | Schaltet das physische Leistungsrelais (NC verdrahtet) |
| **SPI SCK** | D8 | `GPIO19` | Serial Clock für das TFT-Display |
| **SPI MOSI** | D10 | `GPIO18` | Master Out Slave In für das TFT-Display |
| **Dummy CS** | — | `GPIO23` | **Wichtig:** Da der physische CS-Pin des Displays per Jumper (JP1) fest auf GND liegt, verwendet ESPHome diesen freien, nicht herausgeführten GPIO als Software-Dummy, um Konfigurationsfehler zu vermeiden. I2C (D4/D5) bleibt dadurch frei. |

---

## 4. Display-Design & User Experience (UX)

Das ST7735 Display nutzt eine klare visuelle Hierarchie basierend auf Symbolen, Schriftgrößen und Helligkeitsstufen.

### Vollbild-Fehlermeldungen (Zentrierte Groß-Icons)
Wenn ein kritischer Zustand oder eine manuelle Übersteuerung aktiv ist, wird der normale Bildschirm ausgeblendet und durch ein einzelnes, unmissverständliches Icon ersetzt:
* `mdi:thermometer-alert` (Rot): Gehäuse zu heiß!
* `mdi:wifi-off` (Rot): Kein WLAN-Empfang.
* `mdi:api-off` (Orange): Keine Verbindung zu Home Assistant.
* `mdi:power` (Grau): System über Hauptschalter deaktiviert.
* `mdi:pump-off` (Orange): Manuelle Übersteuerung aktiv (Pumpe dauerhaft aus).

### Normalbetrieb Layout
Im regulären Automatikbetrieb ist das Display in 5 klar strukturierte Zonen unterteilt:

1. **Zone 1 (Oben):** Aktueller Modus als Icon. `mdi:white-balance-sunny` (Gelb) bei Sommerbetrieb/Pumpe aus oder `mdi:snowflake` (Hellblau) bei Winterbetrieb/Pumpe ein.
2. **Zone 2 (Mitte-Oben):** Die aktuelle **Mitteltemperatur** (Groß & Leuchtend Hellgrün) – die wichtigste Information des Systems.
3. **Zone 3 (Mitte-Unten):** Der eingestellte **Schwellwert** (Mittelgroß & Hellgrau, z.B. `S: 15°C`).
4. **Zone 4 (Unten):** Der reale **Pumpenstatus** als Icon (`mdi:pump` für läuft, `mdi:pump-off` für gestoppt).
5. **Zone 5 (Ganz unten):** Die lokale **Gehäusetemperatur** (Sehr klein & Dunkelgrau, z.B. `G: 34.2°C`), um den unauffälligen Betrieb des Überhitzungsschutzes zu kontrollieren.

### Lokale LDR-Hintergrundbeleuchtung
Um das Display zu schonen und im Heizungskeller keinen unnötigen Lichtschein zu erzeugen, filtert der ESP die ADC-Werte des LDR über einen gleitenden Mittelwert (`sliding_window_moving_average`). 
* Wird es im Raum dunkel (Spannung < 0.4V), schaltet der ESP das Backlight komplett aus.
* Wird das Raumlicht eingeschaltet (Spannung > 0.6V), erwacht das Display sofort wieder zum Leben.

---

## 5. Home Assistant Integration

Der Smartblock deklariert seine Steuerelemente direkt als native Entitäten, wodurch sie in Home Assistant automatisch in der Kategorie **Konfiguration** bzw. **Diagnose** auftauchen. Dank `restore_value: true` bleiben alle Einstellungen auch nach einem Stromausfall direkt auf dem ESP gespeichert.

### Konfiguration (Bedienbar in HA)
* **Hauptschalter (`switch.hauptschalter`):** Aktiviert oder deaktiviert das gesamte Automatiksystem (Default: ON).
* **Übersteuerung (`switch.ubersteuerung`):** Erzwingt das sofortige Ausschalten der Pumpe (Default: OFF).
* **Schwellwert (`number.schwellwert`):** Slider (0–40°C, Schrittweite 1°C) zur Festlegung der sommerlichen Ausschalttemperatur (Default: 15°C).
* **Hysterese (`number.hysterese`):** Slider (0–10°C, Schrittweite 1°C) zur Vermeidung von ständigem Schalten um den Gefrierpunkt (Default: 2°C).
* **Überhitzung Limit (`number.uberhitzung_limit`):** Slider (30–80°C, Schrittweite 1°C) für den lokalen Hardwareschutz (Default: 50°C).

### Diagnose & Status (Read-Only in HA)
* **Relais Status (`binary_sensor.relais_status`):** Zeigt an, ob das Relais angezogen (Stromkreis offen / Pumpe aus) ist.
* **Backlight Status (`binary_sensor.backlight_status`):** Gibt Rückmeldung, ob das Display-Backlight gerade aktiv ist.
* **Gehäuse Temperatur (`sensor.gehause_temperatur`):** Der aktuelle Temperaturwert des DS18B20 auf der Platine.

### Erforderliche HA-Entitäten (Importiert)
* `sensor.wp_mitteltemperatur`: Liefert den berechneten Mittelwert der Außentemperatur an den ESP.

---

## 6. Inbetriebnahme & Webserver

Der Smartblock verfügt über einen integrierten **Webserver** auf Port 80. Falls Home Assistant einmal ausfallen sollte, lässt sich die Steuerung, der Status des Relais und alle Konfigurationen (Schalter/Slider) ganz einfach über die IP-Adresse des Geräts in jedem Webbrowser einsehen und bedienen.
