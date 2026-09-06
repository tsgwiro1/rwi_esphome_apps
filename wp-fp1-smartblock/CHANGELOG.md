# Changelog - wp-fp1-smartblock

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert. Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/) und diese Versionierung folgt dem [Semantic Versioning](https://semver.org/lang/de/).

## [1.1.0] - 2026-09-06

### Geändert
- **Die Heizgrenze kommt jetzt aus Home Assistant.** Der lokale Slider `number.schwellwert` ist entfallen; das Gerät importiert stattdessen `input_number.heizgrenze` – genauso, wie es `sensor.wp_mitteltemperatur` schon importiert. Damit existiert die Zahl im Haus nur noch **einmal** und wird ausschliesslich in HA verstellt. Sie ist dieselbe, die die Wärmepumpe als Luxtronik-Parameter 700 `ID_Einst_Heizgrenze_Temp` führt.
- **Wirksame Änderung des Verhaltens:** Der Vergleichswert wechselt damit von **27 °C auf 16 °C**. Die 27 °C waren ein Testwert, bei dem der Sommerfall nie eintrat – die Mitteltemperatur erreicht im Hochsommer 20.5 °C, das Relais stand also dauerhaft auf «Heizung steuert». Ab jetzt schaltet der FP1 die Pumpe im Sommer tatsächlich ab.
- **Display:** Zone 3 zeigt weiterhin den Vergleichswert, nun mit einer Nachkommastelle (`S: 16.0°C`), weil der HA-Helfer in Schritten von 0.5 K verstellt wird. Fehlt der Wert, steht dort `S: --.-°C`.
- Die **Hysterese bleibt ein lokaler Slider**. Sie ist eine Eigenschaft dieses Geräts, wird nirgends sonst gelesen und gehört daher nicht nach HA.

### Hinzugefügt
- **Fehlercode 8 «Heizgrenze fehlt»** mit eigenem Watchdog (`heizgrenze_timeout`, Default 60 s), aufgebaut wie die bestehende Überwachung der Mitteltemperatur: Kurze Aussetzer (z.B. HA-Neustart) überbrückt das Gerät durch Halten des letzten Relaiszustands, erst danach greift der Fail-Safe und die Pumpe läuft wieder unter Kontrolle der Heizung. Eigener Code statt Wiederverwendung von 7, damit im Logbuch ablesbar ist, **welcher** der beiden HA-Werte fehlt; auf dem Display teilt er sich das Symbol `mdi:api-off` mit den Codes 3 und 7.
- **Kürzel unter dem `mdi:api-off`-Symbol.** Die drei Fälle „ein Wert aus HA fehlt" (Codes 3, 7 und 8) zeigten bisher ein identisches Bild und waren am Gerät nicht auseinanderzuhalten – der Grund stand nur im HA-Logbuch. Unter dem Symbol steht jetzt `API`, `MITTEL` oder `GRENZE`. Kostet keine zusätzliche Glyphe, da die vorhandene Schrift `font_medium` verwendet wird.

### Behoben
- **Waagrechte Störlinie im Pumpensymbol.** Sie sah nach einem Panel-Defekt aus, war aber eine Nahtstelle des Bildaufbaus: Ohne PSRAM begrenzt ESPHome den Bildpuffer automatisch auf rund 20 KB (`mipi_spi/display.py`, Zeilen 327–337). Unser Bild braucht 80 × 160 × 2 = 25 600 Byte, also wählte ESPHome stillschweigend ein Viertel und zeichnete in vier Bändern zu 40 Zeilen (Grenzen bei 40, 80 und 120). Bei `rotation: 180` wird jedes Band einzeln adressiert und vom Controller gespiegelt; ein Zeilenversatz zwischen zwei Bändern fällt dort auf, wo eine kontrastreiche Kante darüberläuft – die Grenze bei Zeile 120 lag mitten im Pumpensymbol (Zeilen 110–150). Mit `buffer_size: 1.0` gibt es nur noch ein Band und damit keine Nahtstelle. Kostet rund 20 KB Heap (gemessen: 280 272 → 259 684 Byte frei), bei einer Warnschwelle von 80 000 unkritisch.
- **Abgeschnittene Fusszeile.** Die Gehäusetemperatur wurde mit `TextAlign::BASELINE_CENTER` auf `y = 160` gezeichnet. Das Panel hat die Zeilen 0–159, die Grundlinie lag also eine Zeile unterhalb der letzten sichtbaren und schnitt die Unterkanten ab. Jetzt `BOTTOM_CENTER` auf `y = 158`; das Pumpensymbol rückte dafür von 130 auf 126, und die Zeile wurde von RGB 100 auf 150 aufgehellt, weil sie gegen das aufgehellte Schwarz des Panels kaum lesbar war.

### Migration
- Die Entität `number.infrastructure_wp_fp1_smartblock_schwellwert` verschwindet nach dem Flashen aus Home Assistant. Sie wurde vorher geprüft und war in keiner Automation, keinem Skript, keiner Szene und keinem Dashboard referenziert.

---

## [1.0.3] - 2026-08-01

### Behoben
- **Schwarzes Display ab ESPHome 2026.6.0:** Ursache waren **zwei** gleichzeitig geänderte Defaults im `mipi_spi`-Treiber, auf die sich unsere Konfiguration stillschweigend verlassen hatte. Beide sind jetzt explizit gesetzt, die Anzeige funktioniert wieder – verifiziert am Gerät mit ESPHome 2026.7.2.
- **SPI-Modus (`spi_mode: MODE0`):** Der CS-Pin liegt per Jumper fest auf GND, in der YAML gibt es also kein `cs_pin`. Bis 2026.5.3 wählte ESPHome in diesem Fall MODE0, seit 2026.6.0 MODE3 (`mipi_spi/display.py`: „Mode3 for octal bus or single bus with no cs pin"). Mit falscher Clock-Polarität empfängt der ST7735S nur Bitmüll und bleibt dunkel. ESPHome warnt davor bei jedem Lauf – die Meldung wurde bislang übersehen.
- **Offsets (`pad_width: 26`, `pad_height: 1`):** Das ESPHome-Modell `ST7735` meldet 128×160, der verbaute ST7735S hat aber 132×162 GRAM. Ohne explizite Pads rechnet der Treiber `pad = native − width − offset`, also 22 statt 26 und **−1** statt 1. Seit [#16722](https://github.com/esphome/esphome/pull/16722) (in 2026.6.0) findet die Rotation zur Laufzeit statt und benutzt bei `rotation: 180` die Pad-Werte als Offsets – aus −1 wurde als `uint16_t` 65535, das Adressfenster lag ausserhalb des Panels. Mit 26/1 ergibt sich native 132×162 und ein symmetrisches Fenster (26|80|26 und 1|160|1).

### Geändert
- **Kein Versions-Pin mehr nötig:** Der Hinweis, das Gerät auf ESPHome 2026.5.3 zu halten, entfällt. Der Verweis auf [esphome#17050](https://github.com/esphome/esphome/issues/17050) war eine Fehlzuordnung – jenes Issue betrifft ein ST7789V mit überschriebenen Offsets, ein ähnliches Symptom bei anderer Ursache. Es lag kein Upstream-Bug vor, sondern eine unvollständige Konfiguration auf unserer Seite; die ab 2026.7.x neu eingebaute Prüfung („Invalid offsets") hat den Fehler schliesslich sichtbar gemacht, statt ihn still zu einem schwarzen Bild werden zu lassen.

---

## [1.0.2] - 2026-06-27

### Geändert
- **Display-Tausch:** Das ursprüngliche LCD war defekt und wurde ersetzt. Das neue Panel benötigt eine andere Farbeinstellung – `invert_colors` von `true` auf `false` umgestellt, damit die Farben wieder korrekt dargestellt werden.

---

## [1.0.1] - 2026-06-27

### Behoben
- **Fehlerhafte API-Verbindungserkennung:** Der Verbindungsstatus wurde über eine globale Boolean in `on_client_connected`/`on_client_disconnected` geführt. Ein einzelner zusätzlicher oder unverschlüsselter Client (z.B. ein Fleet-Live-Log oder ein Klartext-Ping ohne Encryption-Key) löste `on_client_disconnected` aus und setzte den Status dauerhaft auf „getrennt", obwohl die Home-Assistant-Hauptverbindung bestand. In der Folge lief der API-Watchdog voll und hätte nach einer Stunde fälschlich den Failsafe (Prio 4) ausgelöst.
- **Lösung:** Direkte Abfrage der API über `id(api_id).is_connected()` im 1-Sekunden-Interval. Diese Methode wertet die Anzahl aktiver Verbindungen aus statt einer kippbaren Boolean – solange Home Assistant verbunden ist, bleibt der Status korrekt, auch wenn ein Logger-/Ping-Client (z.B. Fleet-Live-Log) auf- und wieder zugeht. Die globale `api_connected`-Variable und die `on_client_connected`/`on_client_disconnected`-Handler wurden entfernt.

---

## [1.0.0] - 2026-06-11

### Hinzugefügt
- **Initialer Release:** Vollständige Inbetriebnahme des Projekts für das Seeed Studio XIAO ESP32-C6 Modul zur intelligenten, PV-optimierten Steuerung der Heizkreispumpe (FP1).
- **Prioritäten-Kaskade:** Implementierung eines sekündlich prüfenden, 7-stufigen Sicherheits-Baums im ESP32-Core (`Überhitzung -> Sensor defekt -> WLAN -> API-Ausfall -> Hauptschalter -> Übersteuerung -> Automatik`).
- **Hardware-Schutz:** Integration des DS18B20-Temperatursensors (`GPIO16`, via `one_wire`/`dallas_temp`) als lokaler Überhitzungsschutz mit konfigurierbarem Schwellwert (Default: 50°C), geglättet über einen gleitenden Mittelwert (10 Messungen, Update alle 10 s).
- **Sensor-Watchdog:** Ausfallerkennung für den DS18B20 – liefert der Sensor länger als 60 s (Substitution `temp_sensor_timeout`) keinen gültigen Wert (NaN oder den 85.0°C-Power-On-Reset-Wert), fällt das Relais ab und das Display zeigt `mdi:thermometer-off`.
- **Mitteltemperatur-Überwachung:** Fehlt die von HA gelieferte Mitteltemperatur länger als 60 s (Substitution `mittel_temp_timeout`), greift der Failsafe als eigener Fehlercode. Kürzere Aussetzer (z.B. HA-Neustart) werden durch Halten des letzten Zustands überbrückt – kein Relais-Klackern.
- **Status-Text-Sensor:** Klartext-Systemzustand (z.B. `Automatik`, `FEHLER: Temperatursensor defekt`, `FEHLER: Mitteltemperatur fehlt`) wird nur bei Zustandswechseln an HA publiziert – genau ein Logbuch-Eintrag pro Ereignis, zusätzlich Einträge im ESPHome-Log.
- **Feste Antennenwahl:** Beim Boot (`on_boot`, Priorität 800) wird der Onboard-RF-Switch über `GPIO3` aktiviert und mit `GPIO14` fest die interne Keramikantenne gewählt – der Funkpfad ist damit unabhängig vom Auslieferungszustand des XIAO-Moduls eindeutig definiert.
- **Intelligentes Backlight:** Automatische Abschaltung der Display-Hintergrundbeleuchtung (`GPIO1`) bei Dunkelheit via LDR (`GPIO0`), stabilisiert durch einen asymmetrischen EMA-Filter (sehr schnell hell bei α = 0.99, langsam dunkel bei α = 0.45; Schaltschwellen 0.2/0.4 V).
- **Home Assistant native Entities:** Bereitstellung von Slidern (`number`) für Schwellwert, Hysterese und Überhitzungslimit sowie Schaltern (`switch`) für Hauptschalter und Übersteuerung direkt vom ESP aus. Alle Entitäten sind als `config` kategorisiert.
- **Zustandsspeicherung:** Aktivierung von `restore_value: true` und passenden `restore_mode`-Optionen, damit der ESP alle Einstellungen bei einem Stromausfall lokal behält und autark startet.
- **Lokaler Webserver:** Aktivierung des `web_server`-Moduls auf Port 80, um Statuswerte und Steuerungsmöglichkeiten auch bei komplettem HA-Ausfall im Browser bereitzustellen.
- **Erweiterte UI-Zustände:** Vollbild-Fehlermeldungen und zentrierte Groß-Icons für alle blockierenden Systemzustände (`mdi:thermometer-alert`, `mdi:thermometer-off`, `mdi:wifi-off`, `mdi:api-off`, `mdi:power`, `mdi:pump-off`).
- **Read-Only Status-Sensoren:** Binärsensoren für den exakten Relais-Zustand und den Backlight-Status sowie der gefilterte LDR-Wert (Diagnose) zur sauberen Visualisierung in Home Assistant.

### Geändert
- **Neues Display-Framework:** Umstellung des ST7735-Displays auf das `mipi_spi`-Framework. Der CS-Pin entfällt in der Konfiguration komplett (per Jumper JP1 fest auf GND, bei `mipi_spi` optional) – dadurch bleiben D4/D5 (I2C) vollständig frei.
- **Versions-Anpassung:** Projektversion im `esphome`-Konfigurationsblock offiziell auf `1.0.0` angehoben.
- **Entkopplung der Hardware-Ebene:** Das physische Relais (`GPIO17`) und der Backlight-Ausgang wurden auf `internal: true` gesetzt. Sie können von Home Assistant nicht mehr direkt manipuliert werden, um Fehlbedienungen auszuschließen. Die Steuerung erfolgt ausschließlich über das interne Regelwerk.
- **Display-Ausrichtung:** Display um 180° gedreht (`rotation: 180`) passend zur Einbaulage.
- **Entity-Benennung:** Diagnose-Entitäten an das nummerierte Namensschema angeglichen (`1.0 Backlight`, `1.1 LDR`); Relais-Statussensor auf `Relais` verkürzt.

### Sicherheit
- **Fail-Safe-Verdrahtung:** Das Relais agiert als Öffner (Normally Closed). Bei jeglicher logischer Störung (Überhitzung, Sensorausfall, WLAN weg, API für > 1h getrennt, Mitteltemperatur fehlt) fällt das Relais ab. Dadurch wird der Stromkreis geschlossen und die Hoheit augenblicklich und zu 100% an die originale Heizungssteuerung zurückgegeben.
- **Kein stiller Fallback:** Der Überhitzungsschutz rechnet nicht mehr mit einem Default-Wert weiter, wenn der DS18B20 keinen Messwert liefert – ein Sensorausfall führt immer in den sichtbaren Fehlerzustand.
