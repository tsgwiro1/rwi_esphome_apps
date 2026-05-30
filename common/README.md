# 🩺 Common Diagnostics (ESPHome Package)

![Version](https://img.shields.io/badge/version-1.0.0-blue)
[![ESPHome](https://img.shields.io/badge/ESPHome-Ready-03a9f4?logo=esphome&logoColor=white)](https://esphome.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Dieses Paket stellt eine zentralisierte Sammlung von Diagnose- und Überwachungssensoren für alle ESPHome-Projekte bereit. Durch die Auslagerung in ein "Common Package" bleibt der Code in den eigentlichen Projektdateien übersichtlich (DRY-Prinzip: Don't Repeat Yourself).

---

## ⚠️ Haftungsausschluss (Disclaimer)

**WICHTIGER HINWEIS: VERWENDUNG AUF EIGENE GEFAHR!**

Alle in diesem Repository bereitgestellten Inhalte, Codes und Konfigurationen sind rein private Bastelprojekte. Die Nutzung, der Nachbau sowie das Einspielen des bereitgestellten Codes erfolgen ausdrücklich auf **eigene Gefahr und eigenes Risiko**. Es wird keinerlei Haftung für Fehler, Systemabstürze oder andere Schäden übernommen.

---

## 📋 Inhaltsverzeichnis

* [Überblick](#überblick)
* [Verfügbare Sensoren](#verfügbare-sensoren)
* [Einbindung in Projekte](#einbindung-in-projekte)
* [Substitutions (Grenzwerte anpassen)](#substitutions-grenzwerte-anpassen)
* [Versionierung](#versionierung)

---

## 🔭 Überblick

Das `diagnostics.yaml` Package wird beim Kompilieren (Flashen) automatisch in das jeweilige Endgerät eingefügt. Es liefert Home Assistant detaillierte Einblicke in die "Gesundheit" des Mikrocontrollers. So lassen sich Probleme wie schlechter WLAN-Empfang, ständige Neustarts oder ein vollgeschriebener Arbeitsspeicher (Heap) frühzeitig erkennen.

Die Sensoren sind standardmäßig der Kategorie **`diagnostic`** zugeordnet. Sie tauchen in Home Assistant also nicht auf dem Haupt-Dashboard auf, sondern sauber sortiert unter den Gerätediagnosen.

---

## 📊 Verfügbare Sensoren

### 1. Rohdaten (Versteckt / Metriken)
* **WLAN Signalpegel:** Die RSSI-Signalstärke in dBm. Um Schwankungen auszugleichen, wird der Wert über die letzten 3 Messungen geglättet (`sliding_window_moving_average`).
* **Freier Speicher (Bytes):** Der aktuell verfügbare Arbeitsspeicher (Heap).
* **Laufzeit:** Die Uptime des Geräts in Minuten.

### 2. Interpretierte Sensoren (Mit Ampel-System)
Diese Sensoren werten die Rohdaten aus und geben einen leicht verständlichen Text-Status (inkl. Emoji) aus:
* **WLAN Status:**
  * 🟢 Exzellent (Besser als OK-Grenzwert)
  * 🟡 Okay / Roaming (Zwischen OK und Kritisch)
  * 🔴 Kritisch (Schlechter als Kritisch-Grenzwert)
* **System Gesundheit:**
  * 🟢 Stabil (Speicher im grünen Bereich)
  * 🟡 Warnung (Speicher wird knapp)
  * 🔴 Kritisch (Absturzgefahr durch Speichermangel)

### 3. System Informationen
* **IP Adresse & MAC Adresse:** Netzwerkspezifische Identifikation.
* **Verbundene SSID & BSSID:** Zeigt an, mit welchem WLAN und speziell mit welchem Access Point (MAC-Adresse des Routers/Repeaters) das Gerät verbunden ist. Hilft enorm beim Debugging von Roaming-Problemen!
* **ESPHome Version:** Die aktuell geflashte Core-Version.
* **Letzter Neustart Grund:** Einer der wichtigsten Sensoren! Zeigt an, ob das Gerät geplant neugestartet wurde, den Strom verloren hat oder durch einen Hardware-Watchdog (Absturz) neugestartet wurde.

---

## 🚀 Einbindung in Projekte

Das Package wird einfach über die `packages`-Funktion in die Haupt-YAML-Datei des jeweiligen Projekts (z. B. `wp-fp1-smartblock.yaml`) eingebunden.

```yaml
packages:
  diagnostics: !include common/diagnostics.yaml

```

*(Voraussetzung: Die Datei liegt in einem Unterordner namens `common` relativ zur Hauptdatei).*

---

## ⚙️ Substitutions (Grenzwerte anpassen)

Verschiedene Mikrocontroller haben extrem unterschiedliche Mengen an Arbeitsspeicher. Damit die Ampel-Logik ("System Gesundheit") für alle Chips korrekt funktioniert, definiert das Package konservative **Standardwerte** für den ESP8266.

Für leistungsstärkere Chips überschreibst du diese Grenzwerte einfach in der Hauptdatei deines Projekts im `substitutions`-Block (oberhalb des `packages`-Blocks):

### Beispiel-Implementierung in der Projekt-YAML:

```yaml
substitutions:
  # Heap-Werte für ESP32-C6 überschreiben (viel mehr RAM verfügbar)
  diag_min_heap_ok: "100000"
  diag_min_heap_critical: "50000"

packages:
  diagnostics: !include common/diagnostics.yaml

```

### Empfohlene Grenzwerte nach Plattform
Es ist wichtig, zwischen dem physischen Gesamtspeicher (Hardware-SRAM laut Espressif) und dem tatsächlich verfügbaren freien Heap zur Laufzeit zu unterscheiden. ESPHome belegt durch den Netzwerk-Stack, die Home Assistant API und den Webserver direkt einen Großteil des Speichers.

Trage die folgenden Referenzwerte bei neuen Projekten einfach als Substitution in die Projekt-YAML ein (Der ESP8266 dient im Package als Fallback und muss nicht zwingend überschrieben werden).

| Plattform | `diag_min_heap_ok` | `diag_min_heap_critical` | Hardware-SRAM | Typischer freier Heap (ESPHome) |
| :--- | :--- | :--- | :--- | :--- |
| **ESP8266** | `15000` (15 KB) | `8000` (8 KB) | **~80 KB** | **15 KB – 25 KB.** *(Default)* Hat kaum Reserven. Webserver und API lasten den Chip fast vollständig aus. |
| **ESP32 (Classic)** | `80000` (80 KB) | `40000` (40 KB) | **520 KB** | **100 KB – 150 KB.** *Achtung:* Bei aktivem Bluetooth (BLE) fällt der freie Heap drastisch auf ca. 50–70 KB ab! |
| **ESP32-C6** | `80000` (80 KB) | `40000` (40 KB) | **512 KB** | **120 KB – 180 KB.** Die effiziente Architektur (RISC-V) bietet viel freien Heap. *Achtung:* Die Aktivierung der integrierten Zigbee/Thread- oder Bluetooth-Module reduziert diesen spürbar. |
| **ESP32-S3** | `80000` (80 KB) | `40000` (40 KB) | **512 KB** | **120 KB – 200 KB.** *Hinweis:* Viele S3-Boards (z.B. für Displays) besitzen zusätzlichen externen PSRAM (2 MB - 8 MB), der separat ausgewiesen wird. |

*(Die WLAN-Grenzwerte sind standardmäßig auf `-70 dBm` (OK) und `-85 dBm` (Kritisch) eingestellt. Da die physikalischen Antenneneigenschaften maßgeblich sind, gelten diese Werte plattformübergreifend und müssen in der Regel nicht überschrieben werden).*

---

## 🏷️ Versionierung

Da eine Änderung an dieser Datei nicht automatisch alle ESPs im Haus aktualisiert (jeder muss einzeln per OTA neu geflasht werden), enthält das Package einen eigenen Text-Sensor `Common Diagnostics Version`.

Dadurch siehst du in Home Assistant bei jedem Gerät sofort, auf welchem Stand sich das Diagnose-Package befindet und ob ein erneutes Flashen nötig ist, um neue Features aus der `common/diagnostics.yaml` zu erhalten.

```

```