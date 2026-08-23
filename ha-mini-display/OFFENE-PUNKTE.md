# ha-mini-display - Offene Punkte

Was an diesem Gerät bekannt, aber nicht erledigt ist. Jeder Punkt sagt, **worum
es geht**, **was er praktisch bedeutet** und **was ihn schliessen würde** - oder
warum er bewusst offen bleibt.

Die Liste stand bis V1.1.0 als Kapitel 6 in der [README](README.md) und ist von
dort hierher gezogen, damit die README beschreibt, was das Gerät tut, und nicht
was es nicht tut.

Stand: 2026-08-23, V1.1.0.

---

## 1. Ungeprüfte Anzeige

### 1.1 Wie die Glyphen tatsächlich sitzen, ist nicht nachgemessen

**Worum es geht.** Mit V1.1.0 sind alle Symbole von Bildern auf Glyphen der
Material-Design-Icons-Schrift umgestellt. Die Koordinaten wurden dabei
unverändert von den Bildern übernommen.

**Was das bedeutet.** `it.image(x, y, …)` setzt die linke obere Ecke des Bildes,
`it.printf(x, y, …)` dagegen die linke obere Ecke des **Textkastens** - und MDI
legt je Glyph einen eigenen `offset_y` an. Kleine Versätze gegenüber V1.0.1 sind
zu erwarten. Beim `ha-frontroom-info-display` ist beim gleichen Umbau genau das
passiert: Symbole wanderten und überdeckten Beschriftungen.

**Was ihn schliesst.** Am Gerät hinsehen und die Koordinaten in den
Seiten-Lambdas nachziehen. Rechnen hilft hier nicht weiter.

### 1.2 Vierzehn der fünfzehn Wetterlagen sind ungeprüft

**Worum es geht.** Die Wetterseite deckt alle fünfzehn Zustände ab, die
`weather.egnach` liefern kann, jeweils mit Symbol, Beschriftung und Farbe.

**Was das bedeutet.** Während des Flashs meldete Home Assistant `sunny`. Nur
dieser eine Zweig ist gesehen worden. Insbesondere die vier zweizeiligen Fälle
(«PARTLY / CLOUDY», «SNOWY / RAIN», «CLEAR / NIGHT», «LIGHTNING / RAINY») und der
Schriftwechsel auf `latobold` ab acht Zeichen sind ungeprüft.

**Was ihn schliesst.** Abwarten - oder den Text-Sensor kurzzeitig auf eine
Testquelle legen. `clear-night` kommt jede klare Nacht von selbst.

### 1.3 Der Gastfahrzeug-Fall ist nie eingetreten

**Worum es geht.** Die Fahrzeugseite unterscheidet Grigio (`db:1` in
`sensor.evcc_vehicle_name`) von einem fremden Auto und zeigt während
`binary_sensor.evcc_vehicle_detection` ein «DETECTING ...».

**Was das bedeutet.** Beide Zweige sind aus evccs Verhalten abgeleitet, nicht
beobachtet. Ein erster Versuch mit einem fremden Auto am 2026-08-22 scheiterte
daran, dass evcc bei jenem Fahrzeug - einem Renault Zoe erster Generation - gar
nicht zu einem Erkennungsergebnis kam. Ob evcc dann auf `db:32` fällt oder der
Name leer bleibt, ist weiterhin offen; **für die Anzeige spielt es keine Rolle,
beide Werte sind ungleich `db:1`**.

**Was ihn schliesst.** Der zweite Fremdfahrzeug-Test, der ohnehin aussteht.

### 1.4 Das Ausblenden der Seiten ist nicht im Betrieb beobachtet

**Worum es geht.** Hängt nichts am Kabel und läuft keine Erkennung, überspringt
die Rotation Fahrzeug- und Wallbox-Seite.

**Was das bedeutet.** Bei allen Flashs hing Grigio am Kabel, die Sprungschleife
lief nie an. Geprüft ist nur, dass das Gerät mit ihr fehlerfrei läuft.

**Was ihn schliesst.** Beim nächsten Abstecken hinsehen: die Rotation sollte von
der Uhrzeit direkt auf SOLAR POWER gehen. Bleibt sie auf WALLBOX stehen, greift
die Schleife nicht.

---

## 2. Eigenschaften, die bewusst so bleiben

### 2.1 Ohne Home Assistant zeigt das Gerät nichts

**Worum es geht.** Alle fünfzehn Quellen sind `platform: homeassistant`.

**Was das bedeutet.** Ist HA nicht erreichbar, behält ESPHome die letzten
bekannten Werte, und die Anzeige friert auf dem Stand des Verbindungsabbruchs ein
- für den Betrachter **nicht von einer stehenden Anlage zu unterscheiden**. Nach
einem Neustart ohne HA stehen alle Seiten auf «LOADING...» und die Uhrzeitseite
auf «NO TIME». Die Fahrzeugseite wird dann *nicht* übersprungen, weil «unbekannt»
nicht dasselbe ist wie «nichts angesteckt». Es gibt keinen lokalen Webserver und
keine Fallback-Anzeige.

**Warum es bleibt.** Das Gerät ist als Anzeige ohne eigene Logik gebaut. Ein
Alterungshinweis («Wert ist älter als …») wäre die kleinste sinnvolle Ergänzung,
falls das einmal stört.

### 2.2 Die Wetterseite bewegt sich nicht mehr

**Worum es geht.** Bis V1.0.1 lief dort ein animiertes GIF.

**Was das bedeutet.** Die Animation zeigte immer dasselbe, unabhängig von der
tatsächlichen Wetterlage. An ihrer Stelle steht seit V1.1.0 das Symbol des
gemeldeten Zustands - mehr Aussage, weniger Bewegung.

**Warum es bleibt.** Die Animation zurückzuholen hiesse, wieder eine Bilddatei
einzubinden und damit die Abhängigkeit vom gemeinsamen Ordner `~/esphome/pic/`,
die V1.1.0 gerade beseitigt hat.

### 2.3 Die Seitenreihenfolge und alle Koordinaten sind Festwerte

**Worum es geht.** Die Texte sind auf 240 x 135 und auf die Symbolgrössen
abgestimmt.

**Was das bedeutet.** Wird ein Glyph getauscht oder die Rotation geändert, müssen
die Koordinaten in den Lambdas von Hand nachgezogen werden.

**Warum es bleibt.** Ein Layoutsystem wäre für sechs Seiten mit je einer Handvoll
Elementen mehr Aufwand als Nutzen.

---

## 3. Umgebung und Betrieb

### 3.1 Das Gerät hat keine DHCP-Reservierung

**Worum es geht.** Die Adresse wird vom Router vergeben.

**Was das bedeutet.** Am 2026-08-23 ist das Gerät von 192.168.0.129 auf
192.168.0.144 gewandert, wodurch ein OTA-Versuch in einen Timeout lief.

**Was ihn schliesst.** Eine Reservierung im Router. Bis dahin ist der mDNS-Name
`ha-mini-display.local` der verlässliche Weg - er wandert nicht mit und steht so
auch in der README.

### 3.2 Diagnose- und Ereignis-Entitäten tragen einen Bereichspräfix, das Licht nicht

**Worum es geht.** Home Assistant stellt neu erzeugten Entitäten den
Bereichsnamen voran, und das Gerät liegt im Bereich «Attic».

**Was das bedeutet.** Die mit V1.0.0 und V1.1.0 entstandenen Entitäten heissen
`sensor.attic_ha_mini_display_…` und `event.attic_ha_mini_display_…`, während das
ältere `light.ha_mini_display_backlight` ohne Präfix läuft. Wer Entitäten über ein
Muster `…ha_mini_display_…` anspricht, trifft beides nicht mit demselben Ausdruck.

**Warum es bleibt.** Eine Umbenennung wäre ein reiner Eingriff in die
Entitätsregistrierung und würde jeden bestehenden Verweis brechen.

### 3.3 OTA-Rollback meldet «support unknown»

**Worum es geht.** Bis zum 2026-08-23 meldete das Gerät beim Start «Bootloader
too old for OTA rollback and SRAM1 as IRAM (+40KB)». Mit dem Kabel-Flash an
diesem Tag ist der Bootloader erneuert (ESP-IDF v5.5.5); die Warnung ist weg und
`sram1_as_iram: true` ist gesetzt, die 40 kB IRAM sind also nutzbar.

**Was offen bleibt.** Die Zeile `Bootloader rollback: support unknown` im
Startbanner. Ob ein fehlerhaftes OTA nun automatisch auf die vorige Firmware
zurückfällt, ist damit **nicht belegt** - nur, dass der alte Ausschlussgrund weg
ist. Der Rückweg über den Fallback-AP oder das Kabel besteht ohnehin.

**Was ihn schliesst.** Ein absichtlich fehlerhaftes OTA - was niemand aus
Neugier macht. Praktisch: beim nächsten regulären OTA auf die Zeile achten.

### 3.4 Die Display-Plattform `st7789v` ist deprecated

**Worum es geht.** Ab ESPHome 2026.7 ist `st7789v` als veraltet markiert und
verweist auf `mipi_spi`.

**Was das bedeutet.** Heute nichts - sie ist dort noch der eigenständige
Legacy-Treiber und funktioniert unverändert. Die `mipi_spi`-Regression, die
`wp-fp1-smartblock` auf 2026.5.3 festhält, betrifft dieses Gerät nicht.

**Was ihn schliesst.** Der Wechsel auf `mipi_spi`, wenn der Legacy-Treiber
entfällt. Dann sind Farbformat, die Offsets 52/40 und der Umgang mit
`backlight_pin: false` neu zu prüfen - Letzteres ist die Stelle, an der dieses
Gerät seine dimmbare Beleuchtung hat.
