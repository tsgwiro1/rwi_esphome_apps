# Changelog - ha-mini-display

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.0.1] - 2026-07-30

Korrigiert die vier Punkte, die bei der Erstaufnahme gefunden und in V1.0.0
bewusst noch nicht angefasst wurden. Alles Anzeige- und Aufräumarbeit, keine
Änderung an Struktur oder Bedienung.

### Behoben

* **Drei Wetterzustände wurden nie erkannt.** Die Wetterseite verglich den
  Zustandstext gegen Konstanten, die so nie ankommen konnten:

  | vorher | nachher | betroffener Zustand |
  | :--- | :--- | :--- |
  | `LINGTNING` | `LIGHTNING` | Gewitter |
  | `SNOWY-RAIN` | `SNOWY-RAINY` | Schneeregen |
  | *(nicht abgefragt)* | `CLEAR-NIGHT` | klare Nacht |

  In allen drei Fällen blieb die Zustandszeile leer, während Animation,
  Temperatur und Regenstatus normal erschienen. `CLEAR-NIGHT` ist neu als
  zweizeilige Ausgabe «CLEAR / NIGHT» ergänzt und war der häufigste der drei
  Fälle - er trat jede klare Nacht ein. Die Ausgabe für Schneeregen bleibt
  unverändert «SNOWY / RAIN», nur der Vergleich stimmt jetzt.
* **`nan °C` nach dem Start.** Die Aussentemperatur war die einzige Grösse auf
  den fünf Seiten, die ohne `has_state()`-Prüfung ausgegeben wurde. In den ersten
  Sekunden nach einem Reboot stand deshalb `nan °C` auf der Wetterseite. Neu
  zeigt sie bis zum ersten Wert `--.- °C`.

### Entfernt

* **`sensor.grid_active_power`** wurde abonniert und in keinem Seiten-Lambda
  verwendet. Die Subscription ist entfallen.
* **Der Graph der Sonneneinstrahlung** (`sun_radiant_egnach_graph`, 4-h-Puffer
  über 220 Punkte) hielt Daten für eine auskommentierte Seite. Graph, die
  zugehörige Quelle `sensor.egnach_sun_radiant` und der auskommentierte
  Seitenblock sind entfernt - damit bleibt keine Leiche zurück, die aussieht, als
  liesse sie sich durch Entkommentieren wiederbeleben.

Das Gerät abonniert damit zwölf statt vierzehn Home-Assistant-Entitäten. Der
Build wird um 1608 Bytes Flash und 296 Bytes RAM kleiner (28.1 % statt 28.3 %
RAM).

### Nicht geändert

Die auskommentierte Uhrzeitseite bleibt samt Zeitquelle `esptime` und dem nur
dort benutzten Schriftschnitt `latoblackheading1` stehen. Anders als beim Graphen
ist sie eine vollständige, sofort wieder aktivierbare Seite - sie zu löschen wäre
eine Entscheidung über die Anzeige, nicht eine Korrektur.

Ebenfalls unverändert: die wirkungslose Fallunterscheidung auf Seite 3, die
Dreifachbelegung von GPIO4 und die nicht neustartfeste Rotation. Sie stehen in
der README unter «Bekannte Punkte».

### Geflashter Stand

Per OTA eingespielt und geprüft am 2026-07-30 um 15:47 (192.168.0.129).
Konfig-Hash `0x0abc867e`, `project` meldet `tsgwiro1.ha-mini-display` 1.0.1,
ESPHome 2026.7.3, `common/diagnostics.yaml` 1.4.0. Die zwölf verbleibenden
Home-Assistant-Quellen wurden mit ihren erwarteten Entity-IDs abonniert - der Log
zählt genau zwölf `Entity ID:`-Zeilen, `sensor.grid_active_power` und
`sensor.egnach_sun_radiant` erscheinen nicht mehr. Freier Heap 182 kB, also rund
1.3 kB mehr als unter V1.0.0, WLAN −50 dBm, Access Point 🏠 DG, System Gesundheit
🟢 Stabil, WLAN Status 🟢 Exzellent.

Keine Fehler im Log. Zwei Hinweise ohne Bezug zu dieser Version: der bekannte
Bootloader-Hinweis sowie einmalig `api took a long time for an operation (51 ms),
max is 50 ms` rund zwei Minuten nach dem Start - eine Überschreitung um 1 ms, die
bei diesem Gerät durch das sekündliche Neuzeichnen des Displays neben der
API-Verarbeitung zu erwarten ist und keine Folge hat.

Die korrigierten Wetterzustände liessen sich nicht am Gerät beobachten - HA
meldete während des Flashs `sunny`. Geprüft ist damit, dass die Seite unverändert
zeichnet und der Code kompiliert, nicht das Erscheinen der drei Texte. `sunny`
wurde vorher wie nachher korrekt als «SUNNY» ausgegeben.

## [1.0.0] - 2026-07-30

### Erstrelease

Aufnahme des bereits im Betrieb stehenden TTGO-T-Display-Statusmonitors ins
Repository. Der funktionale Stand der Anzeige entspricht dem, was auf dem Gerät
läuft; ergänzt wurden die repo-seitig zwingenden Punkte (siehe unten).

Das Gerät ist ein reines Anzeigegerät: es steuert nichts, sondern holt sich
vierzehn Entitäten aus Home Assistant und stellt sie auf fünf rotierenden Seiten
dar.

* **Plattform:** ESP32 auf `board: esp32dev` mit ESP-IDF-Framework,
  `minimum_chip_revision: "3.0"`. Logger ohne Dämpfung.
* **Display:** ST7789V, Modell `TTGO_TDISPLAY_135x240` über SPI (CLK GPIO18,
  MOSI GPIO19, CS GPIO5, DC GPIO16, Reset GPIO23), `rotation: 270°`, also
  240x135 im Querformat. `update_interval: 1s` - das Bild wird sekündlich neu
  gezeichnet, unabhängig vom Seitenwechsel.
* **Fünf Seiten in fester Reihenfolge:**
  1. **`showtesla`** «GRIGIO» - Fahrzeugsymbol, Ladestand in Farbstufen (ab 60 %
     grün, ab 40 % hellgrün, ab 20 % orange, darunter hellrot) und Restreichweite
     in km. Ist das Fahrzeug nicht verbunden, steht «NOT CONNECTED», vor dem
     ersten Wert «LOADING...».
  2. **`showcharger`** «WALLBOX» - Wallbox-Symbol, «CHARGING» mit Ladeleistung in
     W, sonst «READY», bei fehlendem Fahrzeug «NOT CONNECTED».
  3. **`shownettopower`** «SOLAR POWER» - Solarpanel-Symbol und die
     Wechselrichter-Eingangsleistung in W.
  4. **`showbattery`** «BATTERY» - Batteriesymbol in fünf Füllstufen (ab 80 %,
     60 %, 40 %, 20 %, darunter), Ladestand in Prozent und Lade-/Entladeleistung,
     grün bei Ladung, rot bei Entladung (dort als Absolutwert).
  5. **`show_weather`** - animiertes Wetter-GIF, der Wetterzustand als Text, die
     Aussentemperatur mit Thermometersymbol sowie «WET» mit der Sensorfrequenz
     oder «DRY» aus der Regenerkennung der Wetterstation.

  Zwei weitere Seiten sind auskommentiert und damit inaktiv: eine Datums-/
  Uhrzeitanzeige und ein 4-h-Graph der Sonneneinstrahlung.
* **Automatischer Seitenwechsel:** Ein `interval` von 5 s blättert weiter,
  solange das Global `rotate` (`bool`, Startwert `true`) gesetzt ist.
* **Zwei Hardware-Taster, vier Funktionen** über kurze und lange Betätigung:

  | Taster | Dauer | Funktion |
  | :--- | :--- | :--- |
  | GPIO0 | 1 - 1000 ms | eine Seite zurück |
  | GPIO0 | 1001 - 5000 ms | Hintergrundbeleuchtung umschalten |
  | GPIO35 | 1 - 1000 ms | eine Seite vor |
  | GPIO35 | 1001 - 5000 ms | automatische Rotation an/aus |

  Beide Pins sind invertiert und mit `allow_other_uses: true` doppelt belegt,
  weil kurze und lange Betätigung als je eigener `binary_sensor` definiert sind.
* **Vierzehn konsumierte Entitäten** aus Home Assistant: drei Binärsensoren
  (Regen, Wallbox verbunden, Wallbox lädt), zehn Zahlensensoren (PV-Eingangs-
  leistung, Netzleistung, Batterie-SoC und -Leistung, Sonneneinstrahlung,
  Aussentemperatur, Regensensorfrequenz, Fahrzeug-SoC und -Reichweite,
  Ladeleistung) und ein Text-Sensor auf `weather.egnach`, per `to_upper`-Filter
  in Grossbuchstaben gewandelt.
* **Hintergrundbeleuchtung** an GPIO4, dreifach angesprochen: als
  `backlight_pin` des Displays, als `ledc`-Ausgang hinter dem dimmbaren Licht
  «Backlight» und als interner GPIO-Schalter für den Langdruck auf GPIO0. Die
  Dimmbarkeit funktioniert dadurch nicht (siehe README, Abschnitt 6).
* **Zeitquelle** `platform: homeassistant` als `esptime`. Sie wird ausschliesslich
  von der auskommentierten Uhrzeitseite genutzt und ist im aktiven Code ohne
  Funktion.
* **Vier Farben und acht Bilder** aus `~/esphome/pic/` (Fahrzeug, Wallbox,
  Solarpanel, fünf Batteriestufen, Thermometer, Regen, Trocken) plus die
  Animation `weather.gif`, alle als `type: RGB`. Vier Lato-Schnitte in den Grössen
  20, 24, 30 und 50 aus Google Fonts.
* Gemeinsames Diagnose-Paket `common/diagnostics.yaml` eingebunden, mit
  angehobenen Heap-Grenzen für den ESP32 (80 kB / 40 kB statt 15 kB / 8 kB).

### Für die Repo-Aufnahme geändert

Alle vier Punkte sind nicht funktional, brauchen aber einen Flash, damit Gerät
und Repo denselben Stand tragen.

* **Zugangsdaten über `!secret` ausgelagert.** API-Key, OTA-Passwort und die
  Zugangsdaten des Fallback-AP standen im Klartext in der YAML. Neu:
  `minidisplay_api_key`, `minidisplay_ota_key`,
  `minidisplay_fallback_ap_ssid` und `minidisplay_fallback_ap_password`. Die
  Werte sind unverändert übernommen, es wurde nichts rotiert.
* **`fw_version`-Substitution und `project:`-Block ergänzt**, damit der
  Firmwarestand am Gerät ablesbar ist und die Versionierung des Repos greift.
* **`friendly_name` auf Kleinschreibung umgestellt**, von «HA-mini-Display» auf
  «ha-mini-display», entsprechend der Konvention der übrigen Geräte. Die
  Entity-IDs in Home Assistant bleiben unverändert, weil beide Schreibweisen zum
  selben Slug `ha_mini_display` führen; sichtbar ändert sich nur der angezeigte
  Gerätename.
* **Feste Zeitzone entfernt.** Die Zeitquelle trug `timezone: UTC-01:00`. Weil
  POSIX-Zeitzonenstrings das Vorzeichen umkehren, entsprach das tatsächlich UTC+1
  und damit der hiesigen Winterzeit - aber ohne Sommerzeitregel, das Gerät wäre
  also von Ende März bis Ende Oktober eine Stunde nachgegangen. Ohne Angabe
  übernimmt es die Zeitzone von Home Assistant, wie bei den übrigen
  Display-Projekten; der Log meldet nach dem Flash `UTC+1:00 (DST UTC+2:00)`. Da
  die Zeit nur von der auskommentierten Uhrzeitseite gelesen wird, ist der Effekt
  heute rein vorsorglich.

### Nicht geändert

Bei der Aufnahme sind mehrere Fehler und Altlasten im Anzeigecode aufgefallen -
drei nie zutreffende Wetterzustände, eine fehlende `has_state()`-Prüfung an der
Aussentemperatur, ein unbenutzter Sensor und ein Graph ohne Seite. Sie sind in
der README unter «Bekannte Punkte» festgehalten und bewusst nicht in dieser
Version korrigiert, damit V1.0.0 den laufenden Stand des Geräts abbildet.

### Geflashter Stand

Per OTA eingespielt und geprüft am 2026-07-30 um 15:29 (192.168.0.129), Upload
in 5.7 s. Der Flash hat einen weiteren Stand mitgezogen, der nicht zu dieser
Version gehört, sondern nur zum Zeitpunkt: **ESPHome 2026.7.3**, entsprechend der
lokal installierten CLI. Die Display-Plattform `st7789v` ist dort als deprecated
markiert, aber noch der eigenständige Legacy-Treiber - sie initialisiert
unverändert (ST7789V, `TTGO_TDISPLAY_135X240`, 240x135, Rotation 270°, Offset
52/40, 20 MHz, kein 8-Bit-Farbmodus). Die `mipi_spi`-Regression, die
`wp-fp1-smartblock` auf 2026.5.3 festhält, betrifft dieses Gerät nicht.

Nach dem Neustart gemeldet: `project` steht auf `tsgwiro1.ha-mini-display` 1.0.0,
Konfig-Hash `0xe94edb80`, ESPHome 2026.7.3, `common/diagnostics.yaml` 1.4.0. Alle
vierzehn Home-Assistant-Quellen wurden mit ihren erwarteten Entity-IDs abonniert.
Freier Heap 181 kB, WLAN −50 dBm bei 99 % Qualität auf `WiKaRo_Infra`, Access
Point 🏠 DG, System Gesundheit 🟢 Stabil, WLAN Status 🟢 Exzellent, Neustartgrund
«software via esp_restart». Keine Fehler und keine Warnungen im Log.

Zwei Beobachtungen zum Flash:

* **Die Ampeln fielen diesmal nicht auf 🔴 Kritisch.** Beide sprangen direkt auf
  ihren korrekten Wert. Das ist die Wirkung der NAN-Abfrage aus
  `common/diagnostics.yaml` 1.4.0 - bei `wp-solar-monitor` stand «4.0 System
  Gesundheit» unter 1.3.0 nach dem Boot noch 56 s lang falsch auf 🔴 Kritisch.
* **Die neuen Diagnose-Entitäten tragen einen Bereichspräfix.** Home Assistant hat
  sie als `sensor.attic_ha_mini_display_…` angelegt, nicht als
  `sensor.ha_mini_display_…`, weil das Gerät dem Bereich «Attic» zugeordnet ist
  und HA neu erzeugten Entitäten den Bereichsnamen voranstellt. Die schon vorher
  bestehenden Entitäten des Geräts (die drei Taster und «Backlight») behalten ihre
  Bezeichnung ohne Präfix. Von zehn Geräten mit dem Diagnose-Paket sind damit acht
  ohne Präfix, dieses mit `attic_` und `wp-fp1-smartblock` mit `infrastructure_`.
  Rein kosmetisch, aber uneinheitlich - siehe README, Abschnitt 6.

Ein Hinweis ohne Auswirkung auf diese Version: **«Bootloader too old for OTA
rollback and SRAM1 as IRAM (+40KB)»**. Der Bootloader stammt aus der
Erstinbetriebnahme; erneuern geht nur per USB. Praktische Folge: ein fehlerhaftes
OTA fällt nicht automatisch auf die vorige Firmware zurück, sondern muss über den
Fallback-AP oder per Kabel gerettet werden. Der Safe Mode selbst ist aktiv und
meldet `Bootloader rollback: supported`. Ausserdem bleiben 40 kB IRAM ungenutzt -
bei 28.3 % RAM-Auslastung kein Problem.
