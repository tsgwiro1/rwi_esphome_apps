# ha-frontroom-info-display - Touch-Infodisplay für PV, Hausbatterie und Wallbox

![Version](https://img.shields.io/badge/version-1.1.0-blue)
[![ESPHome](https://img.shields.io/badge/ESPHome-Ready-03a9f4?logo=esphome&logoColor=white)](https://esphome.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ein wandmontiertes 2.8"-Touchdisplay im Vorzimmer, das die wichtigsten Werte des
Hauses ohne Handy und ohne App zeigt: Wetter, PV-Erzeugung, Netzbezug bzw.
-einspeisung, Hausbatterie, Wärmepumpe und den Zustand der Wallbox. Über den
Touchscreen und zwei Hardware-Taster lässt sich der Lademodus des Autos direkt
umschalten und ein Ladeplan setzen - die Anfragen gehen per REST an evcc, nicht
über eine Home-Assistant-Automation.

![ha-frontroom-info-display](images/geraet-schraeg.jpg)

Gehäuse, Aufbau und die nötigen Umbauten am Board stehen in
[HARDWARE.md](HARDWARE.md), das 3D-Modell liegt unter [`3D/`](3D/).

---

## Haftungsausschluss (Disclaimer)

⚠️ **WICHTIGER HINWEIS: VERWENDUNG AUF EIGENE GEFAHR!** ⚠️

Dieses Projekt beschreibt ein privates Bastelprojekt zur Optimierung der eigenen
Hausautomatisierung. Die Nutzung, der Nachbau sowie das Einspielen des
bereitgestellten Codes und der Konfigurationen erfolgen ausdrücklich auf
**eigene Gefahr und eigenes Risiko**.

Der Autor übernimmt **keinerlei Haftung, Gewährleistung oder Verantwortung**
für:

* **Schäden jeglicher Art** an Display, Elektronik oder anderen Komponenten der
  Haustechnik.
* **Folgeschäden durch Fehlbedienung der Wallbox:** Das Display schreibt
  ungefragt und unauthentifiziert in die evcc-API. Ein Fehlgriff auf dem
  Touchscreen, ein prellender Taster oder ein fehlerhaft berechneter
  Ladeplan-Zeitstempel können eine Ladung starten, verhindern oder verschieben -
  mit entsprechenden Stromkosten oder einem morgens nicht geladenen Auto.
* Die Richtigkeit der **angezeigten Werte**. Die Anzeige ist eine
  Wiedergabe fremder Sensoren, teils mit selbst gerechneten Restgrössen. Sie ist
  keine Messeinrichtung und für keinerlei Abrechnung geeignet.
* Die Richtigkeit, Aktualität oder Vollständigkeit des bereitgestellten Codes
  oder der Dokumentation.

Mit der Verwendung dieses Codes oder Nachbau der Hardware erklärst du dich damit
einverstanden, auf jegliche Schadensersatzansprüche gegenüber dem Autor zu
verzichten.

---

## 1. Funktionsprinzip

* **Reines Anzeige- und Bediengerät.** Das Display erfasst selbst nur die
  Raumhelligkeit und die beiden Tasterzustände. Alle dargestellten Messwerte
  kommen als `homeassistant`-Sensoren aus Home Assistant herein; das Gerät ist
  ohne HA-Verbindung dunkel bis auf die Diagnose.
* **Fünf Seiten, eine Startseite.** Die Übersicht (`main_page`) ist der
  Ruhezustand. Von dort führen drei Berührungsflächen in Detailseiten, eine
  Rückkehrfläche oben rechts führt zurück. Nach zwei Minuten ohne Berührung
  fällt die Anzeige selbständig auf die Übersicht zurück.
* **Schreibender Zugriff nur auf evcc.** Lademodus und Ladeplan werden per HTTP
  direkt an die evcc-REST-API geschickt. Home Assistant ist an diesem Pfad
  nicht beteiligt und erfährt die Änderung erst über die evcc-Integration.
* **Zwei Wege für dieselbe Funktion.** Schnellladen und Planladung sind sowohl
  als Hardware-Taster mit Status-LED als auch als Template-Schalter in Home
  Assistant ausgeführt. Beide lösen dieselben Skripte aus.
* **Lokale Helligkeitsregelung.** Ein LDR am ADC steuert die
  Hintergrundbeleuchtung in zwei Stufen, unabhängig von Home Assistant.

---

## 2. Hardware & Pinout (ESP32-2432S028R)

Das Projekt läuft auf einem ESP32-2432S028R (verbreitet als «Cheap Yellow
Display») unter dem ESP-IDF-Framework, `board: esp32dev`, mit
`minimum_chip_revision: "3.1"`.

> **Das Board muss umgebaut werden.** Zwei der vier Signale für die Taster
> liegen am unveränderten CYD nicht auf einem Stecker. Die nötigen Eingriffe —
> LDR-Mod, Entfernen der RGB-LED, Auftrennen und Neuverdrahten des
> Tasteranschlusses — samt Speisung, Kabelbelegung und Fotos stehen in
> [HARDWARE.md](HARDWARE.md).

Die Baugruppe nutzt **zwei getrennte SPI-Busse** - Display und Touchcontroller
teilen sich auf diesem Board keinen Bus:

| Bus | CLK | MOSI | MISO |
| :--- | :---: | :---: | :---: |
| `tft` (Display) | `GPIO14` | `GPIO13` | `GPIO12` |
| `touch` (XPT2046) | `GPIO25` | `GPIO32` | `GPIO39` |

| Peripherie / Funktion | GPIO | Beschreibung / Besonderheit |
| :--- | :---: | :--- |
| **Display CS** | `GPIO15` | `ili9xxx`, Modell `ili9342`, 320 × 240 |
| **Display DC** | `GPIO2` | `color_order: rgb`, `invert_colors: false` |
| **Hintergrundbeleuchtung** | `GPIO21` | LEDC-PWM, als `monochromatic`-Light |
| **Touch CS** | `GPIO33` | `xpt2046`, `threshold: 400`, 50 ms Abtastung |
| **Touch IRQ** | `GPIO36` | Interrupt-Pin des Touchcontrollers |
| **LDR Raumhelligkeit** | `GPIO34` | ADC, Rohwert, 2 s, `internal: true` |
| **Taster «Schnellladen»** | `GPIO35` | `delayed_on: 10ms`, Input-only-Pin |
| **Taster «Ladeplan»** | `GPIO22` | `delayed_on: 10ms`, interner Pull-Up |
| **LED «Charge Now»** | `GPIO17` | LEDC, **invertiert** |
| **LED «Charge Plan»** | `GPIO27` | LEDC, **invertiert** |

**Touch-Kalibrierung:** `x: 280…3860`, `y: 340…3860` mit `swap_xy: true`,
`mirror_x: true`, `mirror_y: true`. Der `on_touch`-Handler loggt bei jeder
Berührung Roh- und umgerechnete Koordinaten (`ESP_LOGI("cal", …)`) - praktisch
beim Ausrichten neuer Berührungsflächen, im Dauerbetrieb reine Log-Last.

**Hinweis zu GPIO35:** Der Pin ist beim ESP32 reiner Eingang ohne internen
Pull-Up. Der Taster «Schnellladen» braucht daher einen externen Pull-Widerstand
auf der Platine - anders als der Taster an GPIO22, der den internen Pull-Up
nutzt.

**Anzeige:** Das Panel wird über die Modellvorgabe im Landscape-Format mit
320 × 240 betrieben. `color_palette: 8BIT` hält den Framebuffer klein, kostet
aber Farbabstufungen - sichtbar an Verläufen im Wetter-GIF. Die Seite wird alle
500 ms neu gezeichnet.

---

## 3. Display-Seiten & Bedienung

### `main_page` - Übersicht (Ruhezustand)

Vier Zonen, durch Linien in HA-Blau getrennt:

* **Oben:** animiertes Wetter-GIF, Wetterlage als Text, Aussentemperatur, und
  der Zustand des Regensensors (`WET` mit Sensorfrequenz oder `DRY`). Ohne
  gültigen Regenwert steht dort `---`.
* **Mitte links:** PV-Erzeugung und Netzleistung. Netzeinspeisung wird grün,
  Netzbezug rot dargestellt.
* **Mitte rechts:** Hausbatterie mit SoC-abhängigem Symbol (fünf Stufen in
  20-%-Schritten), SoC in Prozent und Lade-/Entladeleistung, wieder grün für
  Laden und rot für Entladen.
* **Unten:** Wallbox. `CHARGING` mit Leistung, SoC und Reichweite; `DONE`, wenn
  der Ziel-SoC erreicht ist; `READY` bei angestecktem, nicht ladendem Auto -
  mit Ladeplan-Angabe, falls ein Plan aktiv ist. Ist nichts angesteckt, steht
  `nothing connected` samt Solaranteil der letzten 30 Tage.

### Berührungsflächen der Übersicht

| Zone (x / y) | Ziel |
| :--- | :--- |
| `0…320` / `160…240` | `ev_page` |
| `0…160` / `80…160` | `energy_page` |
| `160…320` / `80…160` | `bat_page` |
| `280…320` / `0…40` | `main_page` (seitenübergreifend) |

### `ev_page` - Wallbox-Detail

Kopfzeile je nach Zustand `Charging`, `Charge done` oder `Charger ready`. Darunter
ein SoC-Balken mit Skala 0…100 % sowie - nur während des Ladens - ein
Leistungsbalken mit Skala 0…11 kW. Unten drei Flächen zur Modusumschaltung, der
aktive Modus ist gefüllt dargestellt:

| Fläche (x / y) | Aktion |
| :--- | :--- |
| `60…116` / `180…236` | Modus `OFF` |
| `132…188` / `180…236` | Modus `PV` |
| `204…260` / `180…236` | Modus `NOW` |

Ein aktiver Ladeplan wird links unten mit Uhrzeit und Ziel-SoC eingeblendet. Ist
nichts angesteckt, zeigt die Seite nur `Nothing connected to wallbox`.

**Touch-Sperre:** Der Sprung von der Übersicht auf `ev_page` erfolgt über eine
Fläche, die den Modusflächen der Zielseite räumlich überlappt. Damit dieselbe
Berührung nicht sofort einen Modus umschaltet, setzt die Eintrittsfläche
`touch_lock` und gibt ihn erst im `on_release` wieder frei. Die drei
Modusflächen prüfen dieses Flag.

### `plan_setup_page` - Ladeplan setzen

Drei Wertepaare mit Auf-/Ab-Flächen, jeweils als gedrückt/ungedrückt gezeichnete
Bilder:

| Wert | Schrittweite | Umlauf / Grenzen |
| :--- | :---: | :--- |
| Stunde | 1 | 0…23, umlaufend |
| Minute | 10 | 0…50, umlaufend |
| Ziel-SoC | 5 | 0…100 %, geklemmt |

Alle drei Werte sind neustartfest (`restore_value: yes`, Vorgaben 03:30 / 65 %).
Jede Berührung setzt einen **10-Sekunden-Timer** zurück. Läuft er ab, wird der
Plan an evcc gesendet und die Anzeige springt auf die Übersicht - es gibt keine
gesonderte Bestätigungsfläche und kein Abbrechen. Die Seite lässt sich nur über
den Taster an GPIO22 oder den HA-Schalter «EVCC Planladung» öffnen, nicht per
Touch von der Übersicht aus.

### `bat_page` - Hausbatterie

SoC und aktuelle Lade-/Entladeleistung als Zahlenwerte, darunter ein
`graph`-Element mit dem SoC-Verlauf der letzten 24 Stunden (Raster 2 h / 20 %,
300 × 100 px). Der Verlauf wird im RAM gehalten und ist nach einem Reboot leer.

### `energy_page` - Energieflussbild

Symbolische Darstellung von Netz, PV, Hausbatterie, Wallbox, Wärmepumpe,
Heizstab und Haus, verbunden durch **animierte Richtungspfeile**, deren Richtung
sich nach dem Vorzeichen der jeweiligen Leistung richtet. Der Zähler `arr_anim`
läuft bei jedem Seitenaufbau von 0 bis 5 und verschiebt die Pfeile um jeweils
vier Pixel.

Die Hausleistung ist **keine gemessene Grösse**, sondern die Restgrösse der
Bilanz:

```
P_ein   = PV + Netzbezug + Batterieentladung
P_Haus  = P_ein − Netzeinspeisung − Batterieladung − Wallbox − Heizstab − Wärmepumpe
```

Messfehler und nicht erfasste Verbraucher landen damit vollständig im Wert für
das Haus, der dadurch auch negativ werden kann.

---

## 4. evcc-Anbindung

Alle schreibenden Aufrufe gehen per `http_request` an die evcc-Instanz auf
`http://homeassistant.local:7070`. Fünf Skripte decken die Funktionen ab:

| Skript | Aufruf |
| :--- | :--- |
| `set_mode_now` | `POST /api/loadpoints/1/mode/now` |
| `set_mode_pv` | `POST /api/loadpoints/1/mode/pv` |
| `set_mode_off` | `POST /api/loadpoints/1/mode/off` (löscht zusätzlich die NOW-LED) |
| `send_plan_request` | `POST /api/vehicles/db:1/plan/soc/<soc>/<zeitstempel>` |
| `delete_plan_request` | `DELETE /api/vehicles/db:1/plan/soc` |

**Zeitstempel des Ladeplans:** Aus Stunde, Minute und der aktuellen Zeit von
Home Assistant wird im Lambda ein ISO-8601-Zeitstempel gebildet. Liegt die
eingestellte Uhrzeit noch in der Zukunft, gilt sie für heute, sonst für morgen.
Die Umrechnung in UTC nutzt einen **fest verdrahteten Basisversatz von einer
Stunde** und addiert bei `is_dst` eine weitere - gültig also nur für
Mitteleuropa (CET/CEST), siehe Abschnitt 8.

**Keine Fehlerbehandlung:** Die Skripte werten die HTTP-Antwort nicht aus. Ist
evcc nicht erreichbar, bleibt die Anzeige unverändert und es gibt keinen
Hinweis; erst der nächste Zustandsbericht der evcc-Integration korrigiert das
Bild. `verify_ssl: false` ist gesetzt, ohne Bedeutung, da ohnehin nur `http://`
aufgerufen wird.

---

## 5. Home Assistant Integration

### Vom Gerät bereitgestellt

| Entität | Typ | Bedeutung |
| :--- | :--- | :--- |
| **Display Backlight** | `light` (monochromatic) | Helligkeit der Hintergrundbeleuchtung, `restore_mode: ALWAYS_ON` |
| **EVCC Schnellladen** | `switch` (template) | EIN spiegelt evcc-Modus `NOW`; Einschalten setzt `NOW`, Ausschalten `PV` |
| **EVCC Planladung** | `switch` (template) | EIN spiegelt einen aktiven Ladeplan; Einschalten öffnet die Eingabeseite am Display, Ausschalten löscht den Plan |

Dazu die Diagnose-Entitäten der Kategorien 2.x bis 6.x aus
`common/diagnostics.yaml`. Die Heap-Grenzen sind für den ESP32 auf 80 kB (gut)
und 40 kB (kritisch) angehoben.

Nicht in Home Assistant sichtbar sind der LDR-Sensor «Room Brightness» und die
beiden Status-LEDs - sie sind als `internal: true` deklariert.

> **Achtung beim Schalter «EVCC Planladung»:** Einschalten *setzt keinen Plan*,
> sondern öffnet nur die Eingabeseite am Display und startet den
> 10-Sekunden-Timer. Wer den Schalter in HA einschaltet und nicht ans Display
> geht, sendet nach zehn Sekunden die zuletzt gespeicherten Werte. Der Schalter
> fällt danach auf den tatsächlichen evcc-Zustand zurück.

### Vom Gerät konsumiert

Das Display abonniert 28 Entitäten aus Home Assistant.

**Binärsensoren:** `binary_sensor.raining`,
`binary_sensor.evcc_loadpoint_charging`, `binary_sensor.evcc_loadpoint_connected`,
`binary_sensor.evcc_chargeplan_enabled`.

**Textsensoren:** `weather.egnach`, `select.evcc_mode`,
`sensor.evcc_chargeplan_time`.

**Zahlensensoren:**

| Bereich | Entitäten |
| :--- | :--- |
| PV & Netz | `sensor.input_power`, `sensor.grid_active_power` |
| Hausbatterie | `sensor.battery_state_of_capacity`, `sensor.charge_discharge_power` |
| Wetter | `sensor.outdoor_temperature`, `sensor.weather_station_frequency` |
| Fahrzeug | `sensor.evcc_vehicle_soc`, `sensor.evcc_vehicle_range`, `sensor.evcc_vehicle_target_soc` |
| Wallbox | `sensor.evcc_charge_power_w`, `sensor.evcc_charge_current`, `sensor.evcc_charge_30d_solar_percentage`, `sensor.evcc_chargeplan_soc` |
| Wärmepumpe & Heizstab | `sensor.total_wp`, `sensor.wp_warmeleistung`, `sensor.heizstab`, `sensor.wp_zwe2_controller_output_power` |
| Ungenutzt | `sensor.home_power`, `sensor.temperature_living_room`, `sensor.humidity_living_room` |

Die drei letztgenannten werden abonniert, aber in keiner Anzeige verwendet -
siehe Abschnitt 8.

Ein `time`-Sensor der Plattform `homeassistant` liefert die Zeitbasis für den
Ladeplan. Ohne HA-Verbindung ist damit auch das Setzen eines Plans nicht
möglich.

---

## 6. Assets, Secrets & Inbetriebnahme

**Die Bilddateien liegen seit V1.1.0 im Ordner `pic/` neben dieser Datei** — 32
Symbole und ein Wetter-GIF, zusammen 144 KB. Die Konfiguration ist damit ohne
weiteres Zutun baubar; ESPHome löst die Pfade `pic/…` relativ zur YAML auf.

Alle Symbole stammen aus [Material Design Icons](https://pictogrammers.com/library/mdi/)
und stehen unter Apache 2.0. Sie wurden aus den SVG-Vorlagen als PNG in der
jeweils benötigten Grösse gerendert und eingefärbt; das Wetter-GIF ist aus
`white-balance-sunny`, `cloud` und den Tropfen von `weather-pouring`
zusammengesetzt.

> **Zur Vorgeschichte:** Bis V1.0.0 lagen die Bilder ausschliesslich in
> `~/esphome/pic/` und waren nicht Teil des Repositorys. Es handelte sich um
> über die Jahre zusammengetragene Dateien unterschiedlicher Herkunft, deren
> Lizenz sich nicht mehr rekonstruieren liess — und eine MIT-Lizenz kann nur
> Rechte einräumen, die man selbst hält. Der Austausch gegen einen Satz mit
> bekannter Lizenz hat dieses Problem beseitigt und die Konfiguration nebenbei
> erstmals vollständig gemacht.

**Hinweis zur lokalen Arbeitsumgebung:** In `~/esphome/` ist `pic/` ein
gemeinsamer Ordner für *alle* Geräte. Fünf Dateien — `dry.png`, `rain_ws.png`,
`thermometer_icon.png`, `wallbox.png` und `weather.gif` — werden auch von
`ha-mini-display` verwendet. Wer sie dort ersetzt, ändert damit auch dessen
Anzeige. Im Repository hat jedes Projekt seinen eigenen Ordner, dort besteht
diese Kopplung nicht.

**Zur Bildgrösse:** `resize:` passt eine Vorlage unter Wahrung ihres
Seitenverhältnisses in den angegebenen Kasten ein — eine hochkant-Vorlage füllt
ihn also nicht aus. ESPHome legt das Ergebnis unkomprimiert als
`Breite × Höhe × 3` Bytes im Flash ab. Beim Ersetzen einer Vorlage lohnt daher
der Blick auf beides: auf den Platzbedarf und darauf, dass `it.image(x, y, …)`
die **linke obere Ecke** setzt — ein breiteres Bild verschiebt das sichtbare
Symbol nach rechts und kann Beschriftungen überdecken.

Die Schriften werden über `gfonts` (Lato in fünf Schnitten und sechs Grössen)
zur Buildzeit heruntergeladen und brauchen keine lokalen Dateien. Die
`glyphs:`-Listen sind bewusst knapp gehalten; fehlt ein Zeichen in einem
`printf`, bleibt es in der Anzeige leer.

**Benötigte Secrets:** `frontroom_api_key`, `frontroom_ota_key`,
`frontroom_fallback_ap_ssid`, `frontroom_fallback_ap_password` sowie
`wifi_ssid` / `wifi_password`. Das eingebundene Diagnose-Paket benötigt
zusätzlich `mac_bssid_ug`, `mac_bssid_eg` und `mac_bssid_dg`.

**Kein Webserver:** Anders als die übrigen Projekte in diesem Repository hat
dieses Gerät keinen `web_server`. Bei einem HA-Ausfall bleibt nur der Blick
aufs Display selbst; der Captive Portal des Fallback-AP ist die einzige
Netzwerkschnittstelle.

`power_save_mode: none` ist gesetzt, damit die abonnierten Werte ohne
Verzögerung ankommen - das kostet dauerhaft WLAN-Sendeleistung, bei einem
netzgespeisten Wandgerät unkritisch.

---

## 7. Datenlast gegenüber Home Assistant

Dieses Gerät ist beim **Senden** sparsam und beim **Empfangen** der grösste
Abonnent im Haus.

* **Senden:** Ausser den beiden Template-Schaltern (zyklische Auswertung ihres
  Lambdas) und dem Backlight-Light publiziert das Gerät nichts Eigenes. Der
  LDR-Sensor tastet alle 2 s ab, ist aber `internal` und erzeugt keinen
  Netzwerkverkehr. Den Hauptanteil stellt `common/diagnostics.yaml`.
* **Empfangen:** 28 Abonnements bedeuten, dass jede Zustandsänderung dieser
  Entitäten an das Display geschickt wird. Das ist Last auf dem Event-Bus und
  im Netzwerk, nicht in der Datenbank - und sie entsteht auf der HA-Seite
  ohnehin, unabhängig davon, ob das Display zuhört.
* **Neuzeichnen ist lokal.** Die 500-ms-Aktualisierung des Displays läuft
  vollständig auf dem ESP32 und löst keinerlei Verkehr aus.

> **Zur Einordnung:** Eine ESPHome-Meldung ist nicht automatisch eine
> Datenbankzeile. Home Assistant schreibt nur, wenn sich Status oder Attribute
> tatsächlich ändern; identische Wiederholungen feuern `STATE_REPORTED` und
> werden vom Recorder verworfen. Wer hier optimieren will, sollte die
> tatsächlichen Zeilenzahlen je Entität aus der Recorder-Historie messen, statt
> aus Melderaten zu schliessen.

**Flash-Verschleiss:** `preferences.flash_write_interval` ist nicht gesetzt,
gilt also mit dem Vorgabewert von einer Minute. Neustartfest sind nur die drei
Ladeplan-Werte, und die ändern sich ausschliesslich auf Tastendruck - eine
Dauerbelastung des NVS entsteht daraus nicht.

---

## 8. Bekannte Punkte

* **Wetteranimation ist reine Dekoration.** `weather_animation.next_frame()`
  läuft bei jedem Seitenaufbau weiter, unabhängig von
  `id(weather_condition)`. Das GIF zeigt also nicht die aktuelle Wetterlage -
  die steht nur im Text daneben.
* **Zeitzone im Ladeplan-Lambda fest verdrahtet.** Der Basisversatz von einer
  Stunde gegenüber UTC steht als Konstante im Code, die Sommerzeit kommt über
  `is_dst` hinzu. Ausserhalb Mitteleuropas ist der gesendete Zeitstempel falsch,
  und eine künftige Änderung der Sommerzeitregelung müsste hier nachgezogen
  werden. Saubere Lösung wäre ein `time`-Sensor mit gesetzter `timezone` und
  `mktime`, statt der Handrechnung.
* **Drei ungenutzte Abonnements:** `sensor.home_power`,
  `sensor.temperature_living_room` und `sensor.humidity_living_room` werden
  importiert, aber in keinem Lambda gelesen. Entweder sollen sie noch angezeigt
  werden, oder sie können entfallen. Beim Hausverbrauch ist zu beachten, dass
  das Energiebild den Wert bewusst selbst als Restgrösse rechnet - ein Vergleich
  der beiden Zahlen wäre eine gute Plausibilitätsprüfung.
* **Keine Rückmeldung bei fehlgeschlagenen evcc-Aufrufen.** Weder Display noch
  Home Assistant zeigen an, dass eine Modusumschaltung oder ein Ladeplan nicht
  angekommen ist (siehe Abschnitt 4).
* **Ladeplan ohne Abbrechen.** Die Eingabeseite sendet nach zehn Sekunden ohne
  Berührung immer. Es gibt keinen Weg, die Seite zu verlassen, ohne einen Plan
  zu setzen - die Rückkehrfläche oben rechts wechselt zwar die Seite, der Timer
  läuft aber weiter und feuert trotzdem.
* **`on_touch`-Kalibrierlogger dauerhaft aktiv.** Jede Berührung schreibt eine
  `ESP_LOGI`-Zeile mit Roh- und Zielkoordinaten. Nützlich beim Einrichten, im
  Betrieb unnötig.
* **Schreibfehler `now_indiactor` / `plan_indiactor`** in den beiden LED-IDs.
  Beide sind `internal: true`, eine Korrektur hat daher keine Auswirkung auf
  Home Assistant und ist reine Kosmetik.
* **`logger` unterdrückt Komponentenwarnungen** (`component: ERROR`). Das
  blendet unter anderem die Warnungen über zu lange Lambda-Laufzeiten aus - bei
  fünf Seiten mit umfangreichen Zeichenroutinen genau die Meldung, die man
  sehen möchte, wenn die Anzeige träge wird.
* **Kein `web_server`** als Notfallzugang, siehe Abschnitt 6.
