# ha-zigbee-router - Zigbee-Router auf ESP32-C6 mit WLAN nur für Wartung

![Version](https://img.shields.io/badge/version-1.0.0-blue)
[![ESPHome](https://img.shields.io/badge/ESPHome-Ready-03a9f4?logo=esphome&logoColor=white)](https://esphome.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ein XIAO ESP32-C6 im Gehäuse, sonst nichts: Er erweitert das Zigbee-Netz von
Zigbee2MQTT als Router. Im Betrieb spricht er nur Zigbee, auch seine Statistik
geht über Zigbee2MQTT nach Home Assistant. Das WLAN schaltet er nur für ein
Wartungsfenster ein, damit sich per OTA eine neue Firmware einspielen lässt.

Ein gemeinsamer Baustein trägt die ganze Logik, je Router gibt es eine kurze
Instanzdatei. Alle Router haben dieselbe Firmware-Version.

---

## Haftungsausschluss (Disclaimer)

⚠️ **WICHTIGER HINWEIS: VERWENDUNG AUF EIGENE GEFAHR!** ⚠️

Dieses Projekt beschreibt ein privates Bastelprojekt zur Optimierung der eigenen
Hausautomatisierung. Die Nutzung, der Nachbau sowie das Einspielen des
bereitgestellten Codes und der Konfigurationen erfolgen ausdrücklich auf
**eigene Gefahr und eigenes Risiko**.

Der Autor übernimmt **keinerlei Haftung, Gewährleistung oder Verantwortung**
für Schäden jeglicher Art, für die Stabilität des Zigbee-Netzes oder für die
Richtigkeit, Aktualität oder Vollständigkeit des Codes und der Dokumentation.
Der Zigbee-Router-Modus von ESPHome ist jung.

Mit der Verwendung dieses Codes oder Nachbau der Hardware erklärst du dich damit
einverstanden, auf jegliche Schadensersatzansprüche gegenüber dem Autor zu
verzichten.

---

## 1. Funktionsprinzip

* **Zigbee-Router über ESPHome.** `zigbee: router: true` der ESPHome-eigenen
  Zigbee-Komponente, keine Fremdfirmware.
* **WLAN im Normalbetrieb aus.** ESP32-C6 teilt das Funkteil zwischen WLAN und
  Zigbee; ein Router mit aktivem WLAN verpasst Pakete. Das WLAN startet darum
  nicht mit (`enable_on_boot: false`) und läuft nur in zwei Fenstern:
  * **Wartungsfenster:** Schalter «1.0 WLAN Wartung», Dauer `wlan_fenster_min`
    (15 min). Danach schaltet das Gerät das WLAN selbst wieder ab.
  * **Notfenster:** nach jedem Start für `notfenster_min` (3 min). Holt einen
    Router zurück, dessen Firmware Zigbee unbrauchbar gemacht hat: Stecker
    ziehen, einstecken, innert 3 min per OTA flashen.
* **Kein Hotspot.** Neben Zigbee lässt ESPHome keinen WLAN-Hotspot zu, es gibt
  also kein Fallback-AP und kein Captive Portal.
* **Statistik über Zigbee.** Jeder sichtbare Sensor und der Schalter sind ein
  Zigbee-Endpunkt. Zigbee2MQTT meldet sie per MQTT-Discovery an Home Assistant.
  `common/diagnostics.yaml` ist nicht eingebunden: Textsensoren gehen nicht
  über Zigbee, und die WLAN-Werte sind ohne WLAN leer.

---

## 2. Hardware

Seeed Studio XIAO ESP32-C6, Speisung über USB-C. Keine weiteren Bauteile.

| Signal | GPIO | ID in der YAML | Besonderheit |
| :--- | :--- | :--- | :--- |
| HF-Schalter Freigabe | GPIO3 | `rf_switch_enable` | LOW: Antennenumschaltung aktiv |
| Antennenwahl | GPIO14 | `antenna_select` | HIGH: extern (U.FL), LOW: intern (Keramik) |
| Benutzer-LED (gelb) | GPIO15 | `status_led` | leuchtet bei LOW, Strapping-Pin |

Die Antenne wählt die Substitution `antenne: extern|intern` in der
Instanzdatei. Ein anderer Wert fällt beim `config` auf.

---

## 3. Dateien und Instanzen

| Repo | `~/esphome` und HA | Rolle |
| :--- | :--- | :--- |
| `ha-zigbee-router.yaml` | `common/ha-zigbee-router.yaml` | Baustein, wird nicht direkt geflasht |
| `instanzen/ha-zigbee-router-NN.yaml` | `ha-zigbee-router-NN.yaml` | ein Router |

Die Instanzdatei setzt den Namen, die Antenne und den API-Schlüssel und bindet
`common/ota.yaml` ein. Ihre Pfade gelten relativ zu `~/esphome`.

**Neuer Router:**

1. `ha-zigbee-router-01.yaml` kopieren, Nummer im Dateinamen, in `name` und im
   Secret-Namen hochzählen, Antenne setzen.
2. In `secrets.yaml` einen neuen Schlüssel anlegen
   (`zigbee_router_NN_api_key`, 32 Byte Base64, z.B. `openssl rand -base64 32`).
3. Die Instanzdatei auch nach `instanzen/` im Repo legen.

Der Standort steht nicht im Gerätenamen, sondern als Gerätename in
Zigbee2MQTT.

---

## 4. Inbetriebnahme

1. **Erster Flash per USB** – ein neues Gerät hat noch keine OTA-Firmware:
   `esphome run ha-zigbee-router-NN.yaml` mit angeschlossenem XIAO.
2. **In Zigbee2MQTT anmelden:** «Permit join» öffnen, dann den Router
   einstecken. Ein neues Gerät sucht zehnmal im Sekundentakt nach einem
   offenen Netz, danach nur noch alle 10 Minuten. Wer den Moment verpasst,
   steckt den Router kurz aus und wieder ein.
3. **In Zigbee2MQTT benennen** (Standort). Daraus entstehen die Entity-IDs in
   Home Assistant.
4. **ESPHome-Integration in HA ignorieren.** Während eines WLAN-Fensters findet
   HA das Gerät auch über die ESPHome-Integration. Dort wäre es fast immer
   `unavailable`; die Erkennung darum ignorieren.

**Neu anlernen:** Gerät in Zigbee2MQTT entfernen. Der Router setzt sich dabei
selbst zurück und sucht erneut ein offenes Netz.

---

## 5. Bedienung

**OTA-Update:** Schalter «1.0 WLAN Wartung» einschalten, warten bis das Gerät
im WLAN ist, dann flashen:

```sh
esphome upload ha-zigbee-router-NN.yaml --device <ip>
```

Das Fenster schliesst nach 15 min von selbst; Ausschalten beendet es sofort.
Ein erneutes Einschalten startet die Zeit neu.

**Status-LED:**

| LED | Bedeutung |
| :--- | :--- |
| dauernd an | WLAN-Fenster offen |
| blinkt (0,5 s) | nicht im Zigbee-Netz |
| aus | im Zigbee-Netz, WLAN aus |

---

## 6. Entitäten

Alle Entitäten erscheinen über Zigbee2MQTT. Die Namen tragen keine Umlaute,
weil ESPHome Nicht-ASCII-Zeichen in der Zigbee-Beschreibung verwirft.

| Entität | Typ | Meldet |
| :--- | :--- | :--- |
| 1.0 WLAN Wartung | Schalter | öffnet und schliesst das WLAN-Fenster |
| 1.1 Laufzeit | h | alle 15 min |
| 1.2 Chiptemperatur | °C | bei Änderung ab 0.5 K |
| 1.3 Freier Speicher | kB | alle 5 min |
| 1.4 Zigbee Kinder | Anzahl | bei Änderung; Endgeräte mit diesem Router als Parent, höchstens 10 |

Linkqualität und Netzwerkkarte liefert Zigbee2MQTT selbst.

Zigbee2MQTT kennt das Gerät nicht und baut die Definition aus den Clustern
selbst («Automatically generated definition», im Log als «NOT supported»
gemeldet). Daraus folgt:

* Die Entity-IDs heissen nach dem Endpunkt, nicht nach dem Namen:
  `sensor.<gerät>_analog_input_1` für die Laufzeit, `…_analog_in_temperature_2`,
  `…_analog_input_3`, `…_analog_input_4`; der Schalter ist `switch.<gerät>`.
* «1.3 Freier Speicher» hat in HA keine Einheit, weil es für kB keine
  BACnet-Einheit gibt.
* Zum On/Off-Cluster legt Zigbee2MQTT ein Select «Power-on behavior» an. Es hat
  keine Wirkung, der Schalter startet immer mit dem Notfenster.

---

## 7. Stand

V1.0.0 am 2026-11-12 auf `ha-zigbee-router-01` geprüft, ESPHome 2026.10.1,
Zigbee2MQTT 2.14.3:

* Anmeldung bei offenem «Permit join» innert 15 s nach dem Start, Interview
  erfolgreich, alle fünf Entitäten in HA.
* Notfenster schliesst nach 3 min von selbst.
* Wartungsfenster per Schalter, verschlüsselter OTA über WLAN; danach tritt
  der Router ohne «Permit join» wieder dem Netz bei.

Offen ist die Stabilität als Router über mehrere Tage, mit angebundenen
Endgeräten.
