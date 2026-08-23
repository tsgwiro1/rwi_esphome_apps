# Changelog - ha-mini-display

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.1.0] - 2026-08-23

Arbeitet die offenen Punkte der README ab. Der sichtbarste Teil: **alle zwölf
Bilder sind verschwunden**, sämtliche Symbole kommen jetzt als Glyphen aus der
Material-Design-Icons-Schrift. Das Gerät hat damit keine Bildabhängigkeit mehr.

### Symbole als Schrift statt als Bilder

Der Anlass war ein doppelter. Erstens lagen die zwölf Vorlagen im gemeinsamen
Ordner `~/esphome/pic/`, der am 2026-08-17 für `ha-frontroom-info-display` auf
Material Design Icons umgestellt wurde - fünf der zwölf waren dadurch bereits
getauscht, und der nächste Build hätte das Aussehen ungefragt geändert. Zweitens
war die Herkunft der übrigen sieben Vorlagen unbekannt, was sie für ein
öffentliches Repository untauglich machte.

Neu bindet die Konfiguration `fonts/materialdesignicons-webfont.ttf` zweimal ein:
`mdi80` mit 29 Glyphen bei `size: 80` für die Seitensymbole, die elf
Batteriestufen und die fünfzehn Wetterlagen, `mdi30` mit drei Glyphen bei `size: 30` für Thermometer, Nass und
Trocken, beide mit `bpp: 4`. FreeType rendert direkt auf die Zielgrösse, es wird
also nichts mehr skaliert, und die Farbe entsteht beim Zeichnen statt in der
Datei.

| | vorher | nachher |
| :--- | :--- | :--- |
| Symbole | 11 PNG + 1 GIF, `type: RGB` | 32 Glyphen aus einer TTF |
| Flash gesamt | 64.3 % | **59.0 %** |
| Bildabhängigkeit | `~/esphome/pic/`, 12 Dateien | keine |

Die 80 × 80 grossen Bilder kosteten je 19 200 Bytes, weil ESPHome sie
unkomprimiert mit drei Bytes je Bildpunkt ablegt. Der Build ist dadurch um
95 484 Bytes kleiner geworden, obwohl mit der Uhrzeitseite gleichzeitig eine
sechste Seite und mit den Batteriestufen sechs weitere Glyphen hinzugekommen
sind.

Die Schriftdatei liegt in `fonts/` neben der YAML, wie bei
`ha-frontroom-info-display`, damit der Bau ohne Netz auskommt. Lizenz Apache 2.0,
Text daneben in `LICENSE-materialdesignicons.txt`.

**Die Wetteranimation ist dabei entfallen.** Das bisherige `weather.gif` lief
unabhängig von der tatsächlichen Lage; an seiner Stelle steht jetzt das Symbol
des gemeldeten Zustands, eingefärbt nach Art des Wetters - gelb bei Sonne und
Gewitter, blau bei Niederschlag, grau bei Wolke und Nebel. Die Seite zeigt damit
mehr Information als vorher, aber sie bewegt sich nicht mehr.

### Behoben

* **Die Hintergrundbeleuchtung ist dimmbar geworden.** GPIO4 war dreifach
  belegt: als `backlight_pin` des Displays, als `ledc`-Ausgang hinter dem Licht
  «Backlight» und als interner GPIO-Schalter. Drei Komponenten schrieben
  unkoordiniert auf denselben Pin, weshalb in der YAML seit je «Currently not
  working» stand. Neu besitzt der `ledc`-Ausgang den Pin allein.

  Der Ausweg war eine Eigenheit der Plattform: das Modell
  `TTGO_TDISPLAY_135x240` bringt GPIO4 als `backlight_pin` selbst mit, weshalb
  blosses Weglassen nichts nützt. `backlight_pin: false` schaltet ihn ab - der
  Parameter nimmt laut Schema auch einen Boolean.

  Weil das Display den Pin damit nicht mehr beim Start einschaltet, trägt das
  Licht `restore_mode: RESTORE_DEFAULT_ON`. Ohne das bliebe der Schirm nach jedem
  Flash dunkel.
* **Nebenwerte werden einzeln geprüft.** Restreichweite, Ladeleistung,
  Batterieleistung und Sensorfrequenz hingen bisher an der `has_state()`-Prüfung
  der Leitgrösse ihrer Seite und hätten `nan` zeigen können, wenn sie später
  eintreffen. Jede zeigt jetzt einen eigenen Platzhalter.
* **Die wirkungslose Fallunterscheidung auf Seite 3 ist weg.** Der Vergleich
  `solar_input > -1000` wählte zwischen zwei Schriftschnitten, gab aber in beiden
  Zweigen denselben Text im selben Format aus.

### Bewusst nicht geändert

* **Die Rotation bleibt nicht neustartfest.** Ein Zwischenstand dieser Version
  hatte dem Global `rotate` ein `restore_value: yes` verpasst, damit eine per
  Langdruck angehaltene Rotation den Neustart übersteht. Das ist wieder
  entfernt: Das Anhalten ist ein Eingriff für den Moment, kein Dauerzustand -
  wer das Gerät neu startet, will den Normalbetrieb. Nach Reboot und OTA
  rotiert die Anzeige also wieder, wie schon vor V1.1.0.

### Neu

* **Die Hausbatterie hat elf Symbolstufen statt fünf**, in Zehnerschritten von
  `battery-outline` bei unter 10 % bis `battery` bei 100 %. Der Index ist der
  Zehnerschritt selbst, die Reihenfolge der Glyphenliste in `mdi80` deckt sich
  damit. Der Wert wird vorher auf 0 bis 100 begrenzt, damit ein Ausreisser der
  Quelle nicht über das Feldende hinausgreift.

  **Das Symbol trägt jetzt auch eine Farbe**, was als Bild nicht ging - ein
  PNG bringt seine Farbe mit, ein Glyph bekommt sie beim Zeichnen:

  | Füllung | Farbe |
  | :--- | :--- |
  | ab 80 % | grün |
  | 60 - 79 % | hellgrün |
  | 40 - 59 % | gelb |
  | 20 - 39 % | orange |
  | unter 20 % | hellrot |

  Die Farbstufen sind feiner als die des Fahrzeugs auf Seite 2, das bei denselben
  Schwellen ohne Gelb auskommt.
* **Das Wallbox-Symbol ist grün, solange geladen wird**, sonst weiss. Die Abfrage
  steht vor der Torbedingung «verbunden», die Farbe hängt also allein am
  Ladezustand.
* **Die Fahrzeugseite unterscheidet Grigio von einem Gastfahrzeug.** Sie hiess
  bisher `showtesla` und ging davon aus, dass am Kabel nur Grigio hängen kann.
  Neu heisst sie `showvehicle` und kennt vier Lagen:

  | Lage | Anzeige |
  | :--- | :--- |
  | noch nichts bekannt | «VEHICLE», Symbol weiss, «LOADING...» |
  | nichts angesteckt | «VEHICLE», Symbol grau, «NOT CONNECTED» |
  | Erkennung läuft | «VEHICLE» grau, Symbol grau, «DETECTING ...» |
  | Grigio erkannt | «GRIGIO» weiss, Ladestand in Farbstufen, Reichweite |
  | fremdes Auto | Titel aus evcc in Orange, «GUEST», «no data» |

  Die Unterscheidung läuft über `sensor.evcc_vehicle_name`: evcc kennt Grigio als
  `db:1`, jeder andere Wert bedeutet ein fremdes Auto. **Die Reihenfolge der
  Abfragen ist dabei entscheidend** - während `binary_sensor.evcc_vehicle_detection`
  läuft, ist der Fahrzeugname noch leer, und ein leerer Name wäre sonst
  fälschlich als Gastfahrzeug ausgewiesen worden. Für ein fremdes Auto liefert
  evcc weder Ladestand noch Reichweite, deshalb steht dort «no data» statt einer
  Null.

  Das Gerät abonniert dafür drei weitere Entitäten und liest damit fünfzehn
  statt zwölf. Der interne Sensor `grigio_connected` heisst jetzt
  `vehicle_connected`, weil er nichts mit Grigio zu tun hat.
* **Fahrzeug- und Wallbox-Seite fallen aus der Rotation, wenn nichts angesteckt
  ist.** Beide melden in diesem Fall nur «NOT CONNECTED» - zwei Seiten
  hintereinander mit derselben Nichtaussage. Läuft eine Erkennung, bleiben beide
  drin. Der Durchlauf verkürzt sich damit von 30 auf 20 Sekunden, sobald das
  Kabel frei ist.

  Umgesetzt als Lambda im `interval`. Es blättert zunächst regulär weiter und
  schaltet dann in einer Schleife über die auszublendenden Seiten hinweg. **Die
  Schleife ist nicht Zierde:** die beiden Seiten liegen nebeneinander, ein
  einzelner Extraschritt wäre auf der zweiten stehengeblieben - der erste
  Entwurf, der nur die Fahrzeugseite kannte, hatte genau diesen Fehler. Eine
  Zählgrenze über die Seitenzahl verhindert, dass ein künftiger Umbau hier endlos
  dreht.

  **«Noch unbekannt» zählt bewusst nicht als «nichts angesteckt».** Die Bedingung
  verlangt ausdrücklich `has_state()`; solange das Gerät den Verbindungszustand
  nicht kennt - etwa nach einem Neustart ohne Home Assistant -, bleiben beide
  Seiten in der Rotation und zeigen «LOADING...».

  **Von Hand bleiben beide über die Taster erreichbar** - wer nachsehen will, ob
  wirklich nichts angesteckt ist, kommt hin.
* **Die Uhrzeitseite ist aktiv** und steht als erste in der Rotation: Datum in
  `latoblack`, darunter die Uhrzeit in `latoblackheading1` mit 50 px. Sie war seit
  jeher auskommentiert vorhanden. Ist die Zeit von Home Assistant noch nicht da,
  steht «NO TIME» statt einer falschen Uhrzeit. Der Durchlauf dauert damit 30
  statt 25 Sekunden.
* **Die Taster melden Ereignisse statt Zustände.** Die drei benannten
  Binärsensoren sind durch zwei `event`-Entitäten ersetzt, «Button Left» und
  «Button Right», je mit den Typen `press` und `long_press` und
  `device_class: button`. Ein Tastendruck ist damit ein Vorgang mit Typ statt
  zweier Zustandswechsel. Die GPIO-Sensoren selbst tragen keinen Namen mehr und
  sind geräteintern.

  Home Assistant hat die drei alten Entitäten von selbst entfernt, es war kein
  Eingriff in die Registry nötig. Vor der Umstellung geprüft: keine Automation,
  kein Skript und kein Helfer verwies auf sie.

### Geflashter Stand

Über Kabel eingespielt und geprüft am 2026-08-23 um 12:41, danach per OTA
gegengeprüft. Konfig-Hash `0xa10cd7fa`, `project` meldet
`tsgwiro1.ha-mini-display` 1.1.0, `common/diagnostics.yaml` 1.4.1. Freier Heap
182 kB, System Gesundheit 🟢 Stabil, WLAN Status 🟢 Exzellent. Keine Fehler im
Log; der Bootloader-Hinweis ist mit dem Kabel-Flash entfallen, siehe unten.

Beim Start meldet das Gerät zweimal «took a long time for an operation» (Display
65 ms, Interval 64 ms, Grenze 50 ms), beides einmalig während des ersten
Seitenaufbaus und im laufenden Betrieb nicht wieder.

Die drei neuen Quellen der Fahrzeugseite wurden beim Start abonniert und
lieferten sofort: Erkennung `OFF`, Name `db:1`, Titel `Grigio`. Grigio hing
während des Flashs am Kabel und lud, die Seite stand also auf «GRIGIO» und das
Wallbox-Symbol auf Grün; die Hausbatterie lag bei 86 %, also `battery-80` in
Grün.

**Das Ausblenden der beiden Seiten liess sich deshalb nicht beobachten** - dazu
hätte das Kabel frei sein müssen. Geprüft ist, dass das Gerät mit der neuen
Schleife fehlerfrei läuft, nicht dass sie im Ernstfall richtig springt.

Nachgeprüft, weil es die kritischen Punkte dieser Version sind: Das Licht
«Backlight» steht nach dem Neustart auf `on` mit Helligkeit 255, der Schirm
bleibt also hell. Der Log führt keine `B/L Pin`-Zeile mehr, der Backlight-Pin des
Displays ist damit tatsächlich abgeschaltet. Die beiden `event`-Entitäten sind in
Home Assistant angelegt, die drei alten Binärsensoren verschwunden.

Zwei Stände sind mitgezogen, die nicht zu dieser Version gehören:

* **ESPHome 2026.7.3 → 2026.7.4**, entsprechend der lokal installierten CLI.
* **`common/diagnostics.yaml` 1.4.0 → 1.4.1.** Das Paket war seit dem letzten
  Flash dieses Geräts angehoben worden.
* **Das Gerät hat die Adresse gewechselt**, von 192.168.0.129 auf 192.168.0.144.
  Der erste OTA-Versuch lief deshalb in einen Timeout. Es hat keine
  DHCP-Reservierung; gebaut und geflasht wird seither über den mDNS-Namen
  `ha-mini-display.local`, der davon unberührt bleibt.

**Nicht am Gerät geprüft:** wie die neuen Symbole tatsächlich stehen. Glyphen
werden anders positioniert als Bilder - `it.printf` setzt die linke obere Ecke
des Textkastens, nicht die des sichtbaren Symbols, und MDI legt je Glyph einen
eigenen `offset_y` an. Die Koordinaten sind unverändert von den Bildern
übernommen. Ebenso ungeprüft sind vierzehn der fünfzehn Wetterlagen; Home
Assistant meldete während des Flashs `sunny`.

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

### Dokumentation

**Die «Bekannten Punkte» sind aus der README ausgezogen.** Sie standen dort als
Kapitel 6 und waren auf elf Einträge angewachsen. Neu liegen sie in
[OFFENE-PUNKTE.md](OFFENE-PUNKTE.md), gegliedert in ungeprüfte Anzeige, bewusste
Eigenschaften und Umgebung; jeder Punkt sagt ausdrücklich, **worum es geht**,
**was er praktisch bedeutet** und **was ihn schliessen würde**. Die README
verweist darauf und nennt nur noch die drei, die beim Lesen am ehesten stören.

Damit beschreibt die README, was das Gerät tut, und nicht, was es nicht tut.

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

### Bootloader erneuert

Der Startbanner meldete seit je **«Bootloader too old for OTA rollback and SRAM1
as IRAM (+40KB). Flash via USB once to update the bootloader»** - der Bootloader
stammte aus der Erstinbetriebnahme und liess sich nur per Kabel erneuern.

Am 2026-08-23 wurde das Gerät dafür an den Mac gehängt und über
`--device /dev/cu.usbserial-…` geflasht. ESPHome schreibt beim seriellen Upload
das **Factory-Image ab Offset 0x0**, also Bootloader, Partitionstabelle und
Anwendung zusammen - genau das, was der Hinweis verlangte. Die NVS-Partition
liegt laut Partitionstabelle hinter beiden App-Partitionen und wird dabei nicht
berührt; gespeicherte Zustände überleben.

Ergebnis:

* **Die Warnung ist weg.** Es startet jetzt der Bootloader von ESP-IDF v5.5.5.
* An ihrer Stelle stand ein Angebot: «Bootloader supports SRAM1 as IRAM (+40KB).
  Set `sram1_as_iram: true`». Genau das ist gesetzt - die 40 kB, die vorher
  brachlagen, sind nutzbar. Danach meldet der Start gar keine Warnung mehr.
* **OTA funktioniert unverändert.** Direkt nach dem Kabel-Flash über WLAN
  gegengeprüft, Upload in 5.2 s, sauberer Neustart.

Was **nicht** belegt ist: Der Safe Mode meldet weiterhin
`Bootloader rollback: support unknown`. Ob ein fehlerhaftes OTA nun automatisch
auf die vorige Firmware zurückfällt, ist damit offen - nur der frühere
Ausschlussgrund ist weg. Nachweisen liesse sich das nur mit einem absichtlich
fehlerhaften OTA. Der Rückweg über Fallback-AP oder Kabel besteht ohnehin.
