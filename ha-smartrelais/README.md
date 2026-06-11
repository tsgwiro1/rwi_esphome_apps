# ha-smartrelais - Zeitgesteuertes SSR-Relais mit Schalterbedienung

![Version](https://img.shields.io/badge/version-1.0.0-blue)
[![ESPHome](https://img.shields.io/badge/ESPHome-Ready-03a9f4?logo=esphome&logoColor=white)](https://esphome.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Dieses ESPHome-Projekt schaltet eine 230-V-Last über ein Solid-State-Relais (SSR) für eine einstellbare Dauer ein - ausgelöst über einen physischen Wandschalter nach dem Treppenlicht-Prinzip. Ein auf dem SSR montierter DS18B20 dient als Übertemperaturschutz mit Wiedereinschaltsperre.

---

## Haftungsausschluss (Disclaimer)

⚠️ **WICHTIGER HINWEIS: VERWENDUNG AUF EIGENE GEFAHR!** ⚠️

Dieses Projekt beschreibt ein privates Bastelprojekt zur Optimierung der eigenen Hausautomatisierung. Die Nutzung, der Nachbau sowie das Einspielen des bereitgestellten Codes und der Konfigurationen erfolgen ausdrücklich auf **eigene Gefahr und eigenes Risiko**.

Der Autor übernimmt **keinerlei Haftung, Gewährleistung oder Verantwortung** für:
* **Schäden jeglicher Art** an der angeschlossenen Last, der Elektroinstallation oder anderen Komponenten der Haustechnik.
* **Folgeschäden** durch Fehlfunktionen der Steuerung (z. B. unbeabsichtigtes Ein- oder Ausschalten der Last, Überhitzung).
* **Elektrische Unfälle oder Verletzungen**: Das SSR schaltet Netzspannung. Arbeiten an 230V-Netzspannung sind lebensgefährlich und dürfen ausschließlich von einer **zertifizierten Elektrofachkraft** durchgeführt werden!
* Die Richtigkeit, Aktualität oder Vollständigkeit des bereitgestellten Codes, des Schaltplans oder der Dokumentation.

Mit der Verwendung dieses Codes oder Nachbau der Hardware erklärst du dich damit einverstanden, auf jegliche Schadensersatzansprüche gegenüber dem Autor zu verzichten.

---

## 1. Funktionsprinzip

* **Schalterflanke = Auslöser:** Der angeschlossene Wandschalter ist ein Kippschalter (kein Taster). **Jede stabile Flanke** - egal in welche Richtung - startet den Timer. Die Schalterstellung selbst ist bedeutungslos, nur der Wechsel zählt. Der stark prellende Schalter wird in Software entprellt (50 ms, per Substitution anpassbar).
* **Treppenlicht-Prinzip:** Das SSR zieht an und fällt nach Ablauf der eingestellten **Einschaltdauer** (Default: 30 min) automatisch ab.
* **Nachtriggern:** Eine erneute Flanke während laufender Zeit startet den Timer neu (Default). Über den Konfigschalter **Nachtriggern** kann das Verhalten auf "erneute Flanke schaltet sofort ab" umgestellt werden.
* **Lokale Autonomie:** Schalter, Timer und Schutzlogik funktionieren vollständig ohne WLAN und ohne Home Assistant. Ein WLAN-/API-Ausfall ist **bewusst kein** Abschaltgrund - er wird nur als Diagnose gemeldet.
* **Fail-Safe:** Nach jedem Neustart ist das Relais AUS (`restore_mode: ALWAYS_OFF`). Im Fehlerfall (Übertemperatur, Sensorausfall) wird die Last stromlos geschaltet.

---

## 2. Sicherheitskonzept (Prioritäten-Kaskade)

Die interne Steuerungslogik prüft jede Sekunde eine strikte Hierarchie. Höhere Prioritäten übersteuern niedrigere, Fail-Safe bedeutet immer **Relais AUS**:

1. **Priorität 1: Übertemperaturschutz**
   * *Bedingung:* Die SSR-Temperatur (DS18B20) überschreitet das eingestellte Limit (Default: 70°C).
   * *Aktion:* Relais AUS, Restzeit gelöscht, **Wiedereinschaltsperre** bis die Temperatur wieder unter (Limit − 10 K) gefallen ist. LED blinkt schnell (2 Hz).
2. **Priorität 2: Temperatursensor-Ausfall**
   * *Bedingung:* Der DS18B20 liefert länger als 60 Sekunden keinen gültigen Messwert (NaN oder exakt 85.0°C, der Power-On-Reset-Wert). Ohne Sensor wäre der Schutz blind.
   * *Aktion:* Relais AUS und gesperrt, bis wieder gültige Werte eintreffen. LED blinkt langsam (0.5 Hz).
3. **Priorität 3: Hauptschalter AUS (über HA/Webserver)**
   * *Aktion:* Relais AUS, Schalterflanken werden ignoriert. LED zeigt Doppelblitz alle 3 s.
4. **Priorität 4: Tageslimit erreicht** (falls aktiviert)
   * *Bedingung:* Die kumulierte Einschaltzeit seit Mitternacht überschreitet das eingestellte Tageslimit.
   * *Aktion:* Relais AUS, neue Flanken werden bis Mitternacht ignoriert. LED zeigt Doppelblitz alle 3 s.
5. **Priorität 5: Dauerbetrieb EIN (über HA/Webserver)**
   * *Aktion:* Relais dauerhaft EIN - weiterhin geschützt durch Prio 1, 2 und 4.
6. **Priorität 6: Normalbetrieb (Timer)**
   * *Logik:* Restzeit > 0 → Relais EIN und herunterzählen, sonst Relais AUS.

Zusätzlich läuft eine **Frühwarnung** parallel zur Kaskade: Überschreitet die SSR-Temperatur die Warnschwelle (Default: 60°C), wird der Binärsensor **Temperatur-Warnung** gesetzt und eine Warnung ins Log geschrieben - ohne abzuschalten. So werden schleichende Probleme (Last zu groß, Kühlung verschlechtert) sichtbar, bevor der Schutz greift.

Jeder Zustandswechsel wird als Klartext über den Text-Sensor **Status** an Home Assistant gemeldet (sichtbar im Logbuch) und ins ESPHome-Log geschrieben.

---

## 3. Hardware & Pinout (XIAO ESP32-C6)

Das Projekt basiert auf dem kompakten Seeed Studio XIAO ESP32-C6 Modul, einem AQH3213A PhotoTRIAC-SSR mit RC-Snubber und einem IRM-01-5 Netzteil.

| Peripherie / Funktion | XIAO Board Pin | Interner GPIO | Beschreibung / Besonderheit |
| :--- | :---: | :---: | :--- |
| **Status-LED (J6)** | D0 | `GPIO0` | LED zwischen +3.3V und GPIO (220Ω) → aktiv LOW, invertiert konfiguriert |
| Reserve (J3 Pin 2) | D1 | `GPIO1` | frei, direkt am Stecker |
| Reserve (J3 Pin 3) | D2 | `GPIO2` | frei, direkt am Stecker |
| **SSR (REL)** | D3 | `GPIO21` | via 220Ω auf die LED des AQH3213A, aktiv HIGH |
| I2C SDA (J2 Pin 2) | D4 | `GPIO22` | 4K7 Pull-up bestückt, Reserve für Erweiterungen |
| I2C SCL (J2 Pin 3) | D5 | `GPIO23` | 4K7 Pull-up bestückt, Reserve für Erweiterungen |
| **DS18B20 Temp** | D6 | `GPIO16` | Lokaler Temperatursensor am SSR (Übertemperaturschutz) |
| **Wandschalter (J3 Pin 1)** | D10 | `GPIO18` | Interner Pull-up, invertiert; Schalter gegen GND |

### Steckerbelegung

| Stecker | Pin 1 | Pin 2 | Pin 3 | Pin 4 |
| :--- | :--- | :--- | :--- | :--- |
| J2 (AUX1) | REL | SDA | SCL | 1W |
| J3 (AUX2) | **GPIO18 = Schalter** | GPIO1 (Reserve) | GPIO2 (Reserve) | – |
| J4 (AUX_VCC) | +3.3V | +3.3V | +3.3V | – |
| J5 (AUX_GND) | GND | GND | GND | – |
| J6 (LED) | +3.3V | LED-Netz (220Ω an GPIO0) | – | – |

**Schalteranschluss:** Der Wandschalter wird zwischen **J3 Pin 1 (GPIO18)** und **J5 (GND)** angeschlossen. Es ist kein externes Bauteil nötig - der interne Pull-up und die Software-Entprellung übernehmen alles. Bei sehr langen Leitungen kann optional ein 100nF-Kondensator direkt am Stecker gegen GND bestückt werden.

---

## 4. Status-LED (Blinkmuster)

Die LED an J6 ist die einzige lokale Anzeige. Sie zeigt vor Ort sofort, warum das Gerät ggf. nicht einschaltet:

| LED-Muster | Bedeutung |
| :--- | :--- |
| AUS | Bereit, Relais aus |
| DAUERLICHT | Relais eingeschaltet (Timer läuft oder Dauerbetrieb) |
| SCHNELLES BLINKEN (2 Hz) | Übertemperatur-Sperre aktiv (SSR zu heiß) |
| LANGSAMES BLINKEN (0.5 Hz) | Temperatursensor defekt (Gerät gesperrt) |
| DOPPELBLITZ alle 3 s | Deaktiviert: Hauptschalter AUS oder Tageslimit erreicht |

---

## 5. Home Assistant Integration

Alle Steuerelemente erscheinen als native Entitäten in den Kategorien **Konfiguration** bzw. **Diagnose**. Dank `restore_value: true` bleiben alle Einstellungen auch nach einem Stromausfall erhalten.

### Konfiguration (Bedienbar in HA)
* **Hauptschalter (`switch.hauptschalter`):** Aktiviert oder deaktiviert das gesamte Gerät (Default: ON).
* **Dauerbetrieb (`switch.dauerbetrieb`):** Relais dauerhaft EIN, weiterhin schutzüberwacht (Default: OFF).
* **Nachtriggern (`switch.nachtriggern`):** EIN: Flanke verlängert den Timer / AUS: Flanke schaltet sofort ab (Default: ON).
* **Einschaltdauer (`number.einschaltdauer`):** Slider 1–120 min (Default: 30 min).
* **Übertemperatur Limit (`number.ubertemperatur_limit`):** Slider 40–90°C (Default: 70°C).
* **Frühwarnschwelle (`number.fruhwarnschwelle`):** Slider 30–85°C (Default: 60°C). Wird logisch immer unterhalb des Abschalt-Limits gehalten.
* **Tageslimit (`number.tageslimit`):** Slider 0–12 h, 0 = deaktiviert (Default: 0).

### Steuerung (Aktionen)
* **Manuell starten (`button.manuell_starten`):** Wirkt exakt wie eine Schalterflanke.
* **Sofort stoppen (`button.sofort_stoppen`):** Setzt die Restzeit auf 0 und schaltet ab.

### Status & Diagnose (Read-Only in HA)
* **Status (`sensor.status`):** Klartext-Systemzustand für Logbuch & Dashboard (z.B. `Bereit`, `Aktiv (Timer läuft)`, `FEHLER: Übertemperatur SSR`). Wird nur bei Zustandswechseln aktualisiert.
* **Relais Status (`binary_sensor.relais_status`):** Zeigt an, ob das SSR angezogen ist.
* **Restzeit (`sensor.restzeit`):** Verbleibende Laufzeit in Minuten (0.1-min-Auflösung).
* **SSR Temperatur (`sensor.ssr_temperatur`):** Geglätteter Messwert des DS18B20 (gleitender Mittelwert, 10 Messungen, Update alle 10 s).
* **SSR Spitzentemperatur heute (`sensor.ssr_spitzentemperatur_heute`):** Tagesmaximum, Reset um Mitternacht.
* **Temperatur-Warnung (`binary_sensor.temperatur_warnung`):** EIN sobald die Frühwarnschwelle überschritten ist.
* **Einschaltzeit heute (`sensor.einschaltzeit_heute`):** Relais-Laufzeit seit Mitternacht in Stunden.
* **Betriebsstunden total (`sensor.betriebsstunden_total`):** Kumulierte Relais-Laufzeit, übersteht Neustarts (Flash-Schreibintervall: 10 min).
* **Schaltspiele heute (`sensor.schaltspiele_heute`):** Anzahl Einschaltvorgänge seit Mitternacht.

### Zeitquelle
Die Mitternachts-Resets (Tageszähler, Spitzentemperatur, Tageslimit) benötigen `time: homeassistant`. Ohne HA-Verbindung läuft die Logik normal weiter; der Reset erfolgt dann erst nach Wiederverbindung.

---

## 6. Inbetriebnahme & Webserver

Das Gerät verfügt über einen integrierten **Webserver** auf Port 80. Falls Home Assistant einmal ausfallen sollte, lassen sich Status, Relais und alle Konfigurationen (Schalter/Slider/Buttons) über die IP-Adresse des Geräts in jedem Webbrowser einsehen und bedienen.

Benötigte Secrets: `smartrelais_api_key`, `smartrelais_ota_key`, `smartrelais_fallback_ap_ssid`, `smartrelais_fallback_ap_password` sowie `wifi_ssid`/`wifi_password`.

Die detaillierte Design-Spezifikation liegt in `Plan_ha-smartrelais_V1.0.0.pdf`.
