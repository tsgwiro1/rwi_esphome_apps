# ha-flowmeter - Impulszähler für Wasserdurchfluss und Gesamtmenge

![Version](https://img.shields.io/badge/version-1.0.0-blue)
[![ESPHome](https://img.shields.io/badge/ESPHome-Ready-03a9f4?logo=esphome&logoColor=white)](https://esphome.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ein Wemos D1 Mini, der die Impulse eines Wasserzählers mitliest und daraus zwei
Werte für Home Assistant bildet: die aktuelle Durchflussrate in Litern pro
Minute und einen neustartfesten Gesamtzähler in Litern. Die Umrechnung von
Impulsen auf Liter ist aus Home Assistant heraus einstellbar, der Zählerstand
lässt sich dort auch zurücksetzen. Eine LED am Gerät blitzt bei jedem Impuls
auf - damit ist ohne Blick in HA erkennbar, dass gezählt wird.

---

## Haftungsausschluss (Disclaimer)

⚠️ **WICHTIGER HINWEIS: VERWENDUNG AUF EIGENE GEFAHR!** ⚠️

Dieses Projekt beschreibt ein privates Bastelprojekt zur Optimierung der eigenen
Hausautomatisierung. Die Nutzung, der Nachbau sowie das Einspielen des
bereitgestellten Codes und der Konfigurationen erfolgen ausdrücklich auf
**eigene Gefahr und eigenes Risiko**.

Der Autor übernimmt **keinerlei Haftung, Gewährleistung oder Verantwortung**
für:

* **Schäden jeglicher Art** an Elektronik, Sanitärinstallation oder anderen
  Komponenten der Haustechnik.
* Die Richtigkeit der **gemessenen Werte**. Der Zählerstand entsteht aus
  Impulsen und einem frei einstellbaren Umrechnungsfaktor und wird im Flash des
  Mikrocontrollers gehalten. Er ist **keine geeichte Messeinrichtung** und für
  keinerlei Abrechnung geeignet - weder gegenüber einem Wasserversorger noch
  zwischen Parteien.
* **Datenverlust am Zählerstand.** Ein Flash-Vorgang mit gelöschtem Speicher,
  ein Defekt oder ein versehentlicher Druck auf den Reset-Knopf setzt den Wert
  auf 0 zurück. Es gibt keine Sicherung ausserhalb des Geräts.
* Die Richtigkeit, Aktualität oder Vollständigkeit des bereitgestellten Codes
  oder der Dokumentation.

Mit der Verwendung dieses Codes oder Nachbau der Hardware erklärst du dich damit
einverstanden, auf jegliche Schadensersatzansprüche gegenüber dem Autor zu
verzichten.

---

## 1. Funktionsprinzip

* **Reines Messgerät.** Das Gerät schaltet nichts. Es liest einen
  Impulsgeber - üblicherweise den Reedkontakt eines Wasserzählers - und stellt
  zwei Sensoren, eine Einstellung und einen Knopf in Home Assistant bereit.
* **Zwei Grössen aus einer Impulsquelle.** Die `pulse_meter`-Komponente liefert
  gleichzeitig die Impulsrate (für die Durchflussrate) und einen laufenden
  Impulszähler (als Auslöser für die Zählerlogik).
* **Umrechnung zur Laufzeit, nicht zur Buildzeit.** Der Faktor «Impulse pro
  Liter» liegt in einem neustartfesten Global und ist über eine
  `number`-Entität aus HA einstellbar. Ein Wechsel des Zählers braucht damit
  keinen neuen Flash.
* **Zählerstand lebt auf dem Gerät.** Der Gesamtstand wird lokal geführt und
  im Flash gehalten, nicht in Home Assistant. Ein HA-Ausfall oder ein Neustart
  des Recorders verliert keine Liter; ein gelöschter Flash schon.
* **Lokale Rückmeldung.** Aktivitäts-LED bei jedem Impuls, Status-LED für die
  Verbindung, dazu ein Webserver auf Port 80 als Zugang unabhängig von HA.

---

## 2. Hardware & Pinout (Wemos D1 Mini)

ESP8266 unter dem Arduino-Framework, `board: d1_mini`.

| Peripherie / Funktion | Pin | GPIO | Beschreibung / Besonderheit |
| :--- | :---: | :---: | :--- |
| **Impulseingang** | D1 | `GPIO5` | `pulse_meter`, `internal_filter: 100ms`, `timeout: 60s` |
| **Status-LED** | D3 | `GPIO0` | `status_led`, **invertiert** |
| **Aktivitäts-LED** | D4 | `GPIO2` | `esp8266_pwm` 1 kHz, **invertiert**, als `monochromatic`-Light, `internal: true` |
| **LED unbenutzt** | D6 | `GPIO12` | `gpio`-Output, invertiert, beim Boot ausgeschaltet |
| **LED unbenutzt** | D7 | `GPIO13` | `gpio`-Output, invertiert, beim Boot ausgeschaltet |

**Entprellung:** `internal_filter: 100ms` verwirft Signale, die weniger als
100 ms nach dem vorigen kommen. Das begrenzt die zählbare Impulsrate auf
rund 10 Hz und ist bei einem Reedkontakt notwendig, weil dessen Prellen sonst
Mehrfachzählungen erzeugt. Bei einem Zähler mit vielen Impulsen pro Liter ist
zu prüfen, ob 100 ms nicht zu grob sind (siehe Abschnitt 6).

**Timeout:** Bleibt eine Minute lang ein Impuls aus, meldet der Sensor 0 L/min.
Bei einem Zähler mit 1 imp/L bedeutet das: Ein Durchfluss unter 1 L/min wird
nicht als Rate sichtbar, die Liter landen aber trotzdem im Gesamtzähler.

**GPIO0 (D3)** ist beim ESP8266 der Boot-Mode-Pin. Die Status-LED daran ist im
Betrieb unkritisch, ein niederohmiger Verbraucher an diesem Pin kann aber das
Starten aus dem Flash verhindern - beim Umbau der Beschaltung zu beachten.

---

## 3. Home Assistant Integration

### Vom Gerät bereitgestellt

| Entität | Typ | Bedeutung |
| :--- | :--- | :--- |
| **Wasser Durchflussrate** | `sensor` (pulse_meter) | Aktueller Durchfluss in L/min, `mdi:water-pump` |
| **Wasser Gesamtmenge** | `sensor` (template) | Zählerstand in L, `state_class: total_increasing`, eine Dezimalstelle |
| **Konfig: Impulse pro Liter** | `number` (template) | 0.1…1000 imp/L, Schritt 0.1, `mode: box`, `entity_category: config` |
| **Reset Gesamtzähler** | `button` (template) | Setzt den Zählerstand auf 0, `entity_category: config` |

Dazu die Diagnose-Entitäten der Kategorien 2.x bis 6.x aus
`common/diagnostics.yaml`, mit den ESP8266-Vorgabewerten für die Heap-Grenzen
(15 kB gut / 8 kB kritisch).

Nicht in Home Assistant sichtbar sind das Aktivitäts-Light «Status Activity»
und der Impulszähler `raw_total_pulses` - beide sind `internal: true`.

> **Achtung beim Reset-Knopf:** Er wirkt sofort und ohne Rückfrage, und der
> vorige Stand ist danach auf dem Gerät nicht mehr vorhanden. Der Verlauf in
> der HA-Datenbank bleibt zwar, der Zähler beginnt aber bei 0. Wer den Knopf
> nicht braucht, kann ihn in HA ausblenden.

### Vom Gerät konsumiert

Keine. Das Gerät abonniert keine HA-Entitäten und ist in seiner Messfunktion
vollständig autonom.

---

## 4. Secrets & Inbetriebnahme

**Benötigte Secrets:** `flowmeter_api_key`, `flowmeter_ota_key`,
`flowmeter_fallback_ap_ssid`, `flowmeter_fallback_ap_password` sowie
`wifi_ssid` / `wifi_password`. Das eingebundene Diagnose-Paket benötigt
zusätzlich `mac_bssid_ug`, `mac_bssid_eg` und `mac_bssid_dg`.

**Kalibrierung:** Nach dem ersten Flash steht der Faktor auf 1.0 imp/L. Der
tatsächliche Wert steht auf dem Zählwerk (oft «1 Imp = 1 L» oder «1 Imp =
10 L»). Er wird einmal in HA eingestellt und überlebt Neustarts; ein Flash mit
gelöschtem Speicherbereich setzt ihn wieder auf 1.0.

**Reihenfolge beim Ersteinsatz:** Faktor einstellen, *dann* den Zählerstand
zurücksetzen. Umgekehrt sind die vor der Korrektur gezählten Liter mit dem
falschen Faktor verrechnet - der Zähler rechnet nicht rückwirkend um.

---

## 5. Datenlast gegenüber Home Assistant

Die Melderate hängt direkt am Wasserverbrauch: Bei 1 imp/L meldet das Gerät
pro verbrauchtem Liter je eine Aktualisierung von Durchflussrate und
Gesamtmenge. Bei stehendem Wasser meldet die Durchflussrate den Wert 0 und die
Gesamtmenge einen unveränderten Stand.

Dazu kommen zwei zyklische Meldungen mit der 60-Sekunden-Vorgabe: Der
Kalibrier-Regler wertet sein Lambda minütlich aus, und der Template-Sensor der
Gesamtmenge pollt zusätzlich zum ereignisgesteuerten `component.update`.

> **Zur Einordnung:** Eine ESPHome-Meldung ist nicht automatisch eine
> Datenbankzeile. Home Assistant schreibt nur, wenn sich Status oder Attribute
> tatsächlich ändern; identische Wiederholungen feuern `STATE_REPORTED` und
> werden vom Recorder verworfen. Die minütlichen Wiederholungen des
> Kalibrierwerts und eines stehenden Zählerstands kosten also Netzwerk- und
> Event-Bus-Last, aber keine Zeilen. Wer hier optimieren will, sollte die
> tatsächlichen Zeilenzahlen je Entität aus der Recorder-Historie messen, statt
> aus Melderaten zu schliessen.

**Flash-Verschleiss:** `preferences.flash_write_interval` ist nicht gesetzt,
gilt also mit dem Vorgabewert von einer Minute. Beide Globals sind
neustartfest, und der Zählerstand ändert sich bei laufendem Wasser
fortlaufend - während eines Bewässerungszyklus oder eines Duschgangs entsteht
damit etwa ein Schreibvorgang pro Minute. Über eine Saison summiert ist das
relevant und ein Punkt für die spätere funktionale Durchsicht.

---

## 6. Bekannte Punkte

* **Der `strobe`-Effekt «Flash» wird nie aufgerufen.** Am Light ist ein Effekt
  mit 100 ms hell / 200 ms dunkel definiert, der Impuls-Handler baut den Blitz
  aber von Hand aus `light.turn_on` / `delay` / `light.turn_off`. Der
  Effektblock ist damit toter Konfigurationsteil.
* **Die Zählung steht hinter dem Blitz.** Im `on_value`-Handler kommt zuerst
  das Einschalten der LED, dann `delay: 100ms`, und erst danach das Erhöhen des
  Zählerstands. Zu prüfen ist, was passiert, wenn während dieser 100 ms der
  nächste Impuls eintrifft - je nach Verhalten der Automation bei erneuter
  Auslösung kann ein Impuls verloren gehen. Mit `internal_filter: 100ms` und
  1 imp/L ist das im Alltag kaum erreichbar; bei einem Zähler mit vielen
  Impulsen pro Liter rückt die Grenze aber in den Arbeitsbereich. Sauberer wäre
  es, zuerst zu zählen und die LED danach anzusteuern.
* **Der Zählerstand wird doppelt geführt.** Der `total:`-Untersensor
  `raw_total_pulses` des `pulse_meter` zählt die Impulse bereits selbst, wird
  aber nur als Auslöser verwendet; der eigentliche Stand läuft parallel über das
  Global `total_water_liters`. Ein Filter auf dem Untersensor käme ohne das
  zweite Global aus - allerdings um den Preis der Neustartfestigkeit, die
  gerade das Global liefert.
* **Kein `device_class`.** Beiden Sensoren fehlt die Geräteklasse (`water` beim
  Zähler, sinnvollerweise auch `state_class: measurement` bei der Rate). Ohne
  `device_class: water` nimmt das Wasser-Dashboard von Home Assistant den
  Zähler nicht an.
* **Kalibrier-Regler pollt.** «Konfig: Impulse pro Liter» wertet sein Lambda im
  60-Sekunden-Takt aus und meldet dabei immer denselben Wert. Bei
  `ha-irrigation` sind die Konfigurationsregler dafür auf
  `update_interval: never` umgestellt und werden beim Boot einmal publiziert -
  dasselbe Muster liesse sich hier anwenden.
* **Kein Schutz gegen Fehlimpulse.** Ein prellender oder dauerhaft
  geschlossener Kontakt zählt ungebremst hoch; es gibt keine Plausibilitäts-
  oder Maximalratenprüfung und keinen Weg, einen zu hohen Zählerstand zu
  korrigieren - nur den Reset auf 0.
* **Der Zählerstand ist nicht setzbar.** Beim Anschluss an einen bereits
  gelaufenen Zähler lässt sich der Anfangsstand nicht eintragen. Ein
  `number`-Feld für den Startwert wäre dafür der naheliegende Weg.
* **ESPHome-Version nicht gepinnt.** Es ist kein `min_version` gesetzt.

Diese Liste ist die Bestandsaufnahme bei der Repo-Aufnahme, nicht eine
Änderungsliste - die funktionale Durchsicht erfolgt gesondert.
