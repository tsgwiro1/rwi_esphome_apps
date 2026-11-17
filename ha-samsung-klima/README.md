# ha-samsung-klima - Samsung-Klimaanlage am F1/F2-Bus

![Version](https://img.shields.io/badge/version-0.1.0-blue)
[![ESPHome](https://img.shields.io/badge/ESPHome-Ready-03a9f4?logo=esphome&logoColor=white)](https://esphome.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ein M5Stack ATOM Lite auf der Atomic RS485 Base, der am Kommunikationsbus
F1/F2 einer Samsung-Klimaanlage (NASA-Protokoll) mitliest und mitschreibt. Die
Anbindung übernimmt die externe Komponente
[`samsung_ac`](https://github.com/omerfaruk-aran/esphome_samsung_hvac_bus)
([Doku](https://docs.samsung-hvac.aran.net.tr/wiki/)). Ziel ist eine
`climate`-Entität je Innengerät in Home Assistant, dazu Raumtemperatur,
Aussentemperatur, Leistung und Fehlercode.

**Stand 0.1.0: Erkennungsbetrieb.** Die Firmware liest den Bus und meldet die
gefundenen Geräteadressen ins Log, legt aber noch keine Klima-Entitäten an.

---

## Haftungsausschluss (Disclaimer)

⚠️ **WICHTIGER HINWEIS: VERWENDUNG AUF EIGENE GEFAHR!** ⚠️

Dieses Projekt beschreibt ein privates Bastelprojekt. Die Nutzung, der Nachbau
sowie das Einspielen des bereitgestellten Codes erfolgen ausdrücklich auf
**eigene Gefahr und eigenes Risiko**.

Der Autor übernimmt **keinerlei Haftung, Gewährleistung oder Verantwortung**
für Schäden an der Klimaanlage, Garantieverlust beim Hersteller oder Unfälle.
Die Klemmen F1/F2 und V1/V2 liegen im Innengerät neben den 230-V-Anschlüssen:
**Gerät vor dem Öffnen allpolig vom Netz trennen.** Arbeiten an Netzelektrik
dürfen nur von ausgebildetem Fachpersonal durchgeführt werden.

---

## 1. Funktionsprinzip

* **Busteilnehmer, kein IR-Ersatz.** Das Gerät hängt am selben RS485-Bus wie
  Innen- und Aussengerät und sieht deren Meldungen. Befehle (Ein/Aus, Modus,
  Solltemperatur) schreibt es auf denselben Bus.
* **Ein ESP für die ganze Anlage.** Alle Innengeräte an einem Aussengerät sind
  über einen Bus erreichbar und werden in der Liste `devices` je mit ihrer
  Adresse eingetragen.
* **Adressen aus dem Log.** Welche Adressen am Bus hängen, meldet die
  Komponente selbst nach etwa einer Minute Betrieb («Discovered devices»). Bei
  NASA hat das Aussengerät die Adresse `10.00.00`, die Innengeräte `20.00.00`,
  `20.00.01` usw.
* **Komponente auf festem Stand.** Die Substitution `samsung_ac_ref` pinnt die
  Komponente auf einen Commit. Ein Update der Komponente ist eine bewusste
  Änderung mit eigenem Versionssprung.

---

## 2. Hardware & Pinout

M5Stack ATOM Lite (ESP32-PICO-D4) unter ESP-IDF, `board: m5stack-atom`, auf
der M5Stack Atomic RS485 Base.

| Peripherie / Funktion | GPIO | Beschreibung / Besonderheit |
| :--- | :---: | :--- |
| **RS485 TX** | `GPIO19` | `uart`, 9600 Baud, Parität EVEN |
| **RS485 RX** | `GPIO22` | `uart`, mit Debug-Haken für den Empfangszeitpunkt |
| **Taste** | `GPIO39` | im ATOM Lite eingebaut, nur Eingang, Pull-up auf der Platine, **invertiert** |
| **RGB-LED SK6812** | `GPIO27` | im ATOM Lite eingebaut, `esp32_rmt_led_strip`, GRB |
| IR-Sender (unbenutzt) | `GPIO12` | im ATOM Lite eingebaut |

Die RS485 Base schaltet die Senderichtung selbst, ein `flow_control_pin` ist
nicht nötig.

### Anschluss an die Klimaanlage

| Innengerät | RS485 Base | Bemerkung |
| :---: | :---: | :--- |
| **F1** | **A** | Kommunikationsbus |
| **F2** | **B** | Kommunikationsbus |
| V1 | DC | 12 V, nur falls die Speisung aus der Anlage kommt |
| V2 | GND | dito |

Kommen keine Meldungen an, zuerst F1 und F2 tauschen. F1/F2 ist der Bus
zwischen Innen- und Aussengerät, nicht der Anschluss einer Kabelfernbedienung.

**Speisung: noch offen.** Entweder 12 V aus V1/V2 auf den DC-Eingang der Base,
oder ein USB-Netzteil am ATOM Lite. Nicht beides gleichzeitig.

### Status-LED

Vorrang von oben nach unten:

| Anzeige | Bedeutung |
| :--- | :--- |
| weiss | Taste lang genug gehalten, Loslassen startet neu |
| rot blinkend (0,5 s) | kein WLAN oder Home Assistant nicht verbunden |
| blau blinkend (1 s) | vom Bus kommt seit 10 s nichts: nicht angeschlossen, F1/F2 vertauscht |
| grüner Blitz | Daten vom Bus, höchstens einmal pro Sekunde |

«Daten vom Bus» heisst: Am UART kommen Bytes an. Ob es gültige Pakete sind,
prüft die Anzeige nicht. Jeder Zustandswechsel steht auch im Log (`status_led`).
Der Schalter «Status-LED» in HA schaltet die Anzeige ab.

### Taste

| Drücken | Wirkung |
| :--- | :--- |
| kurz (bis 1 s) | Ereignis `press` an der Entität «Taste» in HA |
| lang (ab 3 s, LED weiss) | Neustart beim Loslassen |

Dazwischen passiert nichts. Helligkeit, Bus-Timeout und Tastenzeiten stehen
unter `substitutions`.

---

## 3. Home Assistant Integration

### Vom Gerät bereitgestellt

| Entität | Typ | Bedeutung |
| :--- | :--- | :--- |
| **Taste** | `event` | Ereignis `press` bei kurzem Druck |
| **Status-LED** | `switch` (template) | Statusanzeige ein/aus, neustartfest, `entity_category: config` |

Dazu die Diagnose-Entitäten der Kategorien 2.x bis 6.x aus
`common/diagnostics.yaml`, mit den ESP32-Werten für die Heap-Grenzen
(80 kB gut / 40 kB kritisch). Klima- und Sensor-Entitäten folgen mit den
Geräteadressen.

### Vom Gerät konsumiert

Keine.

---

## 4. Secrets & Inbetriebnahme

**Benötigte Secrets:** `samsungklima_api_key`,
`samsungklima_fallback_ap_ssid`, `samsungklima_fallback_ap_password` sowie
`wifi_ssid` / `wifi_password`. Das Diagnose-Paket benötigt zusätzlich
`mac_bssid_ug`, `mac_bssid_eg` und `mac_bssid_dg`.

**Reihenfolge:**

1. **Erstflash per USB-C** am ATOM Lite, noch ohne Anschluss an die Anlage.
   Danach erscheint das Gerät in Home Assistant und ist per OTA erreichbar.
2. **Einbau** im stromlosen Innengerät: F1/F2 an A/B, Speisung nach Wahl.
3. **Log beobachten** (`esphome logs ha-samsung-klima.yaml`). Gelbe
   Meldungen zeigen empfangene Pakete. Kommt nur alle 30 s ein
   `samsung_ac … update`, kommt nichts an: Verdrahtung prüfen, F1/F2 tauschen.
4. **Adressen ablesen** aus dem Block «Discovered devices» nach etwa einer
   Minute.
5. **Liste `devices` füllen:** ein Eintrag je Innengerät mit `climate` und den
   gewünschten Sensoren, ein Eintrag für das Aussengerät `10.00.00` mit
   Aussentemperatur, Leistung und Fehlercode. Die Anlage hat ein Aussengerät
   und zwei Innengeräte, erwartet sind also `20.00.00` und `20.00.01`. Vorlage ist die
   [`example.yaml`](https://github.com/omerfaruk-aran/esphome_samsung_hvac_bus/blob/main/example.yaml)
   der Komponente. Damit wird die Version 1.0.0.

---

## 5. Offene Punkte

* **Modellnummer** von Innen- und Aussengerät ermitteln und mit dem
  [Model Checker](https://docs.samsung-hvac.aran.net.tr/wiki/model-checker/)
  gegen das NASA-Protokoll prüfen.
* **Speisung** festlegen (V1/V2 oder USB).
* **Funktionsumfang** nach der Erkennung bestimmen: Swing-Richtungen, Presets
  (Wind-Free, Eco …), Luftfeuchte, Anzeige-LED, Filterwarnung.
* **Entitätsnamen** mit dem HA-Bereichspräfix vergeben, sobald feststeht, in
  welchen Räumen die Innengeräte stehen.
* **Status-LED rot dauernd** bei einem Fehlercode der Anlage, sobald das
  Aussengerät mit `error_code` eingetragen ist.
