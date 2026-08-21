# Changelog - ha-frontroom-info-display

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.5.0] - 2026-08-21

### Neu

* **Abgelehnte Befehle sagen, warum.** Bisher tat das Gerät bei einem
  unzulässigen Befehl schlicht nichts — kein Bild, keine LED, keine Meldung.
  «Gerät kaputt» und «absichtlich abgelehnt» sahen gleich aus. Neu erscheint
  ein Balken über die volle Breite, 44 px hoch am unteren Rand, vier Sekunden
  lang: **blau** für abgelehnt, **rot** für fehlgeschlagen. Er wird auf allen
  fünf Seiten zuletzt gezeichnet und deckt ab, was darunter liegt.

  Gesetzt wird er ausschliesslich über das Skript `show_hint` mit Text und
  Stufe als Parameter. `hint_no_plan` unterscheidet die beiden Gründe, aus
  denen ein Ladeplan abgelehnt wird — `No vehicle connected` oder
  `Guest vehicle - no plan`.

  **Erfolg meldet sich bewusst nicht.** Dafür sind die beiden Tasten-LEDs da,
  die im Sekundentakt den evcc-Zustand spiegeln. Der Balken zeigt nur, was
  davon abweicht; so bleibt die Anzeige ruhig und ein Hinweis heisst etwas.

* **Sensor «Letzter Hinweis» in Home Assistant.** Hält denselben Text fest,
  ohne Ablauf. Der Schalter *EVCC Planladung* springt bei einer Ablehnung
  sofort zurück, weil sein Lambda den evcc-Zustand meldet — das sah bisher nach
  einem Fehler aus. Jetzt steht der Grund daneben.

### Geändert

* **Die Hardware-Taste *Schnellladen* prüft auf ein angestecktes Fahrzeug.**
  Sie schaltete den Modus bisher bedingungslos, während die drei Modusfelder
  auf `ev_page` das längst ablehnen — dieselbe Handlung war auf dem Bildschirm
  verboten und auf der Taste erlaubt. Eine Vorwahl brächte ohnehin nichts: die
  HA-Automation «Wallbox: Fahrzeug angesteckt» setzt beim Einstecken als Erstes
  `off` und überschreibt sie.

* **`touch_lock` ist aus der gemeinsamen Bedingung gelöst.** Auf `ev_page`
  stand die Sperre gegen die Berührung vom Seitenwechsel im selben `&&` wie die
  Fahrzeugprüfung. Das ist keine Ablehnung, sondern ein Fehlereignis, und muss
  stumm bleiben — sonst blinkte bei jedem Wechsel auf die Seite ein Balken auf.

* **Der verworfene Ladeplan meldet sich.** Läuft der Zehn-Sekunden-Timer der
  Eingabeseite ab, während kein oder ein fremdes Fahrzeug angesteckt ist, wurde
  der eingestellte Plan wortlos verworfen.

### Bekannt

Die fünf evcc-Skripte werten die HTTP-Antwort weiterhin nicht aus; die rote
Stufe des Balkens ist dafür schon angelegt. Ebenso fehlt die Überwachung, ob
evcc einen angenommenen Befehl auch ausführt. Beides ist für V1.6.0 vorgesehen,
zusammen mit `timeout: 2s` gegen das Einfrieren der Anzeige — `http_request`
ist synchron, ein nicht erreichbares evcc blockiert die Schleife bis zum
Zeitablauf.

## [1.4.2] - 2026-08-21

### Geändert

* **Die Unterdrückung `logger: logs: component: ERROR` ist entfernt.** Sie
  verbarg die Warnungen über zu lange Komponentenlaufzeiten — bei fünf
  umfangreichen Zeichenroutinen genau die Meldung, die man sucht, wenn die
  Anzeige träge wird.

  Vorher gemessen, weil die Sorge vor einem zugespammten Log berechtigt war:
  Die Anzeige braucht 120 bis 130 ms je Zeichenvorgang und meldet das **rund
  dreimal in den ersten zehn Sekunden nach dem Start**, danach nicht mehr. Der
  Grund steht in `esphome/core/component.cpp:233` — nach jeder Meldung hebt
  `should_warn_of_blocking()` die Schwelle der betroffenen Komponente auf die
  gemessene Zeit plus 10 ms an, ab Werk sind es 50 ms. Ein Dauerstrom entsteht
  dadurch nicht.

* **Bilder und Animation sind Plattformen des `image`-Bausteins.** Die obersten
  Blöcke `image:` und `animation:` sind abgekündigt und fallen mit ESPHome
  2027.1 weg. Die 34 Bilder tragen jetzt `- platform: file`, die
  Wetteranimation ist als `- platform: animation` der 35. Eintrag derselben
  Liste, der eigene `animation:`-Block ist aufgelöst. An den Bilddaten und an
  der Darstellung ändert sich nichts.

### Geprüft und verworfen

* **`mipi_spi` löst `ili9xxx` noch nicht ab.** Der Nachfolger wurde gebaut und
  geflasht: Modell `ESP32-2432S028-9342`, Geometrie und Farben bestätigt
  identisch (320×240, Mirror X, RGB, nicht invertiert). Der Zeichenvorgang
  stieg dabei von 124 ms auf **193 ms**.

  Ursache ist die Formatumwandlung. `mipi_spi` schreibt den Puffer nur dann am
  Stück heraus, wenn Puffer- und Panelformat übereinstimmen
  (`mipi_spi.h:423`). Hier sind es 8 gegen 16 Bit, also läuft alles über
  `dbuffer[DISPLAYPIXEL * 48]` — 48 Bildpunkte je SPI-Übertragung gegenüber 63
  bei `ili9xxx` (`ili9xxx_display.h:11`). Ein Vollbild sind 76 800
  Bildpunkte, und ein Vollbild ist es jedes Mal, weil ESPHome vor jedem
  Seitenaufruf `clear()` ruft und das die ganze Fläche als verändert markiert.

  Der schnelle Weg wäre ein 16-Bit-Puffer ohne Umwandlung. Der braucht
  153.6 KB, frei sind rund 122 KB, und PSRAM hat das Board keinen. Teilpuffer
  über `buffer_size` scheiden aus, weil `mipi_spi.h:554` das Seiten-Lambda
  einmal je Teilstück aufruft.

  `ili9xxx` bleibt deshalb bis auf Weiteres und ist in der YAML entsprechend
  kommentiert.

## [1.4.1] - 2026-08-20

### Geändert

* **Bildtypen von `RGB` auf `GRAYSCALE` und `RGB565` umgestellt.** Alle 35
  Bilder lagen mit drei Bytes je Bildpunkt im Flash. 22 davon sind
  nachweislich einfarbig — jeder sichtbare Bildpunkt hat R=G=B — und liegen
  jetzt als `GRAYSCALE` mit einem Byte dort. Das ist verlustfrei: ESPHome
  liefert bei der Vorgabe `TRANSPARENCY_OPAQUE` genau
  `Color(gray, gray, gray, 0xFF)`. Die übrigen 13 samt Wetteranimation sind
  `RGB565` mit zwei Bytes.

  Die Bilddaten schrumpfen damit von 250.9 KiB auf 131.7 KiB, der Flash von
  77.9 % auf **71.2 %**. An der Darstellung ändert sich nichts.

  `BINARY` wäre für die einfarbigen Symbole nochmals achtmal kleiner, opfert
  aber die Kantenglättung und wurde deshalb nicht genommen.

## [1.4.0] - 2026-08-20

### Neu

* **Das Gerät weiss jetzt, welches Fahrzeug an der Wallbox hängt.** Bisher kam
  aus evcc nur, *dass* etwas angesteckt ist. Neu werden `vehicleName`,
  `vehicleTitle` und `vehicleDetectionActive` als Substitutionen
  `ent_vehicle_name`, `ent_vehicle_title` und `ent_vehicle_detection`
  abonniert. Ein internes Merkmal `known_vehicle` vergleicht die gemeldete
  Fahrzeug-ID mit `evcc_vehicle`. Verglichen wird die ID und nicht der Titel:
  der Titel ist in evcc frei benannt.

* **Fahrzeuganzeige auf beiden Seiten.** Auf `ev_page` steht unter dem Zustand
  der Titel aus evcc, beim bekannten Fahrzeug weiss, bei einem fremden orange,
  ohne Titel `Guest vehicle`. Auf der Übersicht steht dasselbe im Zustand
  `READY` mittig über dem Fahrzeugsymbol, in den übrigen Zuständen klein
  rechtsbündig in der freien Zeile darüber — dort füllt der Text den Streifen
  bis nach rechts.

* **Die Prüfphase ist sichtbar.** `ent_plan_automation` abonniert das Attribut
  `current` der Home-Assistant-Automation «Wallbox: Fahrzeug angesteckt».
  Solange sie nach dem Anstecken auf die Fahrzeugbestätigung wartet und den
  Lademodus auf `OFF` hält, steht auf dem Display `Checking vehicle …` statt
  eines Namens. Läuft evccs eigene Erkennung, steht dort `Detecting vehicle …`.
  Ohne diese Unterscheidung sähe ein noch leerer Titel wie ein Gastfahrzeug
  aus.

### Geändert

* **Der Ladeplan ist dem bekannten Fahrzeug vorbehalten.** Die Eingabeseite
  wird nur noch geöffnet und der Plan nur noch gesendet, wenn evcc
  `evcc_vehicle` als zugeordnetes Fahrzeug meldet — geprüft an allen drei
  Eintrittspunkten: Touchfläche der Übersicht, HA-Schalter «EVCC Planladung»
  und Ablauf des Sendetimers. V1.3.2 prüfte nur, *dass* etwas angesteckt ist;
  der Plan wird aber fest auf `${evcc_vehicle}` geschrieben und landete bei
  einem fremden Auto an der Wallbox trotzdem beim eigenen. Löschen bleibt
  uneingeschränkt, und die drei Lademodi stehen weiterhin jedem Fahrzeug offen.

* **`ev_page` neu aufgeteilt.** Der Fahrzeugname braucht Raum, und unten stand
  eine leere Fläche. Ohne Ladung rückt der SoC-Balken deshalb an den Platz des
  Leistungsbalkens direkt über die Modusflächen; wird geladen, bleibt die
  bisherige Staffelung. Die Zeile `Plan active` steht neu unter dem Namen statt
  über dem Balken, und die Skalenbeschriftungen sind nach innen gerückt, damit
  sie den Ziel-SoC des Ladeplans nicht mehr berühren.

* **Fahrzeugsymbol im Wallbox-Streifen der Übersicht auf 56 px vergrössert**
  (`ev_icon_big`) und so gesetzt, dass sein sichtbarer Abstand zum rechten
  Displayrand dem des Wallbox-Symbols links entspricht: beide Vorlagen haben
  schwarzen Rand, gerechnet wurde mit dem sichtbaren Inhalt, nicht mit dem
  Bildkasten.

## [1.3.2] - 2026-08-19

### Geändert

* **Die Tasten-LEDs zeigen jetzt, was evcc meldet.** Bisher wurden sie an drei
  Stellen lokal geschaltet: aus dem Zustandswechsel von
  `binary_sensor.evcc_chargeplan_enabled`, aus dem Wertwechsel von
  `select.evcc_mode` und zusätzlich direkt in `set_mode_off`. Wer nur auf
  Wechsel reagiert, verpasst jede Meldung, die keinen Wechsel darstellt — und
  der Griff in `set_mode_off` setzte die LED auf einen lokal *gewünschten*
  Zustand, bevor evcc ihn bestätigt hatte.

  Alle drei Stellen sind entfernt. Stattdessen gleicht das Sekundenintervall
  die beiden LEDs gegen den aktuellen Zustand der evcc-Entitäten ab und
  schaltet nur bei Abweichung. Ein lokaler Eingriff kann damit nicht stehen
  bleiben, eine verpasste Meldung heilt innerhalb einer Sekunde.

  Anlass war ein beobachteter Widerspruch: Die Wallbox-Seite zeigte einen
  Ladeplan, während die zugehörige Taste dunkel blieb. Der Mechanismus dahinter
  liess sich aus dem Quelltext nicht rekonstruieren — der Abgleich macht ihn
  gegenstandslos, unabhängig von der Ursache.

### Behoben

* **Kein Ladeplan mehr ohne gemeldetes Fahrzeug.** Die Eingabeseite liess sich
  über den Taster an GPIO22 und über den HA-Schalter «EVCC Planladung» auch
  dann öffnen, wenn nichts angesteckt war; nach zehn Sekunden ging der Plan an
  evcc. Dort konnte er keinem Fahrzeug zugeordnet werden. Beide Wege prüfen
  jetzt `binary_sensor.evcc_loadpoint_connected`, ebenso der Timer selbst.
  `delete_plan_request` bleibt uneingeschränkt — einen Plan zu löschen ist auch
  ohne angestecktes Fahrzeug sinnvoll.

* **«DONE - 0 %» bei schlafendem Fahrzeug.** Beide Seiten entschieden mit
  `vehicle_soc >= vehicle_target_soc`, ob geladen ist. evcc meldet einen
  unbekannten Ladestand als 0 — der MQTT-Sensor setzt `float(0)`, wenn die
  Nachricht leer ist —, und `0 >= 0` ergab «geladen». Reproduzierbar mit
  angestecktem, schlafendem Fahrzeug und einem evcc-Neustart. Beide Werte
  müssen jetzt grösser als 0 sein, sonst steht dort «Charger ready»; der
  SoC-Balken auf der Wallbox-Seite zeigt in dem Fall `---` statt 0 %.

### Hinweis

Ausgangspunkt war ein Fehlerbild nach einem evcc-Neustart: Plan aktiv, obwohl
nichts angesteckt war. Die Ursache lag **nicht** im Gerät. Am Ladepunkt war in
evcc «Grigio» als festes Fahrzeug eingetragen; beim Start ordnete evcc es zu,
ohne je eine Verbindung gesehen zu haben, und reichte damit den am Fahrzeug
hinterlegten Ladeplan als `effectivePlan` weiter. Nachgewiesen mit einem
Versuch: Zuordnung entfernt → Plan verschwand; evcc neu gestartet → Zuordnung
und Plan waren drei Sekunden später wieder da. Nach der Umstellung auf
«automatisch erkennen» meldet evcc korrekt kein Fahrzeug.

Das Gerät bleibt bei seiner Rolle als Anzeige: Es filtert nicht, was evcc
meldet, sondern zeigt es. Ein Plan, den evcc als aktiv meldet, erscheint auf
dem Display — auch wenn kein Fahrzeug angesteckt ist.

---

## [1.3.1] - 2026-08-18

### Behoben

* **Zeitzone war nicht festgelegt.** Das `time`-Bauteil hatte kein `timezone:`.
  ESPHome ermittelt in diesem Fall die Zeitzone des **bauenden Rechners**
  (`tzlocal.get_localzone_name()`) und schreibt sie fest in die Firmware. Auf
  Rogers Rechner ergab das `Europe/Zurich` und damit das Richtige — ein Build
  anderswo hätte dem Gerät stillschweigend eine fremde Ortszeit gegeben, und
  der Ladeplan wäre entsprechend verschoben bei evcc angekommen. Jetzt steht
  die Zeitzone als `device_timezone` im Substitutionsblock.

  Der erzeugte Zeitzonenblock ist dadurch unverändert: `Europe/Zurich` liefert
  genau die Struktur, die bisher erraten wurde.

* **Ladeplan-Zeitstempel an den beiden Umstellungsnächten falsch.** Das Lambda
  rechnete mit einem fest verdrahteten Basisversatz von einer Stunde plus
  `is_dst` und gab das Ergebnis über `localtime()` mit angehängtem `Z` aus —
  zwei Fehler, die sich im Normalbetrieb gegenseitig aufhoben. In der Nacht der
  Zeitumstellung nicht:

  | Fall | Soll | vorher |
  | :--- | :--- | :--- |
  | Nacht der Vorstellung, Plan 03:30 | `2026-03-29T01:30:00Z` | `03:30:00Z` |
  | Nacht der Rückstellung, Plan 03:30 | `2026-10-25T02:30:00Z` | `01:30:00Z` |

  Die Rechnung geht jetzt über `now().timestamp` (UTC) abzüglich der
  Ortszeit-Sekunden seit Mitternacht. Das ergibt die Epoche der lokalen
  Mitternacht ohne jede Annahme über die Zeitzone. Ein Gegencheck mit
  `ESPTime::from_epoch_local()` fängt den Fall ab, dass eine Umstellung
  zwischen Mitternacht und die geplante Uhrzeit fällt. `local_timediff`,
  `is_dst` und `localtime()` sind damit weg.

---

## [1.3.0] - 2026-08-18

### Hinzugefügt

* **Substitutionsblock am Kopf der YAML, 47 Einträge in sechs Gruppen.** Alles,
  was in einer anderen Installation abweicht, steht jetzt an einer Stelle
  zuoberst; darunter ist kein Entitätsname, keine Adresse und kein Anlagenwert
  mehr fest verdrahtet.

  | Gruppe | Inhalt |
  | :--- | :--- |
  | Gerät | `device_name`, `project_name`, `fw_version` |
  | evcc | `evcc_url`, `evcc_loadpoint`, `evcc_vehicle` |
  | Entitäten | 24 Namen, nach Bereich gruppiert |
  | Anlage | Wallbox-Maximum, zwei LDR-Schwellen, sieben Touch-Kalibrierwerte |
  | Verhalten | Ladeplan-Vorgaben, zwei Zeitlimiten |
  | Diagnose | die beiden Heap-Grenzen wie bisher |

  Die evcc-Adresse stand fünfmal im Code, jeweils mit Ladepunkt und Fahrzeug-ID
  darin — darunter einmal in einem Lambda. Das geht, weil der
  Substitutionsdurchlauf `core.Lambda` ausdrücklich mitbehandelt.

  Zugangsdaten bleiben draussen und gehören ins `secrets.yaml`; ihre Namen
  liessen sich ohnehin nicht substituieren, weil ESPHome `!secret` beim Laden
  auflöst.

* **Webserver ergänzt** (`port: 80`, `version: 3`, `ota: false`), wie in den
  übrigen Projekten des Repositorys. Das Gerät ist damit auch dann erreichbar,
  wenn Home Assistant ausgefallen ist. Kostet 14 KB Flash, weil die
  Bedienoberfläche von `oi.esphome.io` nachgeladen wird; die REST-Schnittstelle
  darunter antwortet auch ohne Internet.

### Geändert

* **Magic Number der Wallbox-Skala aufgelöst.** Beschriftung (`"11kW"`) und
  Umrechnungsfaktor (`0.023`) standen zwei Zeilen auseinander und waren als
  zusammengehörig nicht erkennbar. Beide hängen jetzt an `wallbox_max_power`:
  die Beschriftung an `${wallbox_max_power} / 1000.0`, die Balkenlänge an
  `250.0 / ${wallbox_max_power}`.

  Damit ist nebenbei ein kleiner Fehler weg: `0.023 × 11000 = 253` wurde auf
  250 gekappt, der Balken war also schon bei 10 870 W voll. Jetzt trifft er
  exakt beim eingestellten Maximum an.

### Prüfung

Der Vergleich der mit `esphome config` aufgelösten Konfiguration vor und nach
dem Umbau enthält ausser dem Substitutionsblock, der Versionsnummer und den
zwei Wallbox-Zeilen keinen Unterschied — alle 47 Werte lösen sich zeichengleich
auf. Am Gerät gegengeprüft: der Startdump nennt genau die 24 erwarteten
Entitäten.

### Dokumentation

* **Abschnitt 6 der README heisst jetzt «Konfiguration, Assets &
  Inbetriebnahme»** und führt jede Substitution mit Vorgabewert und Bedeutung
  auf, dazu den Hinweis zu den `!secret`-Schlüsseln.
* **Abschnitt 5** listet statt der Entitätsnamen die Substitutionen, nach
  Bereich gruppiert — die Vorgaben stehen nur noch an einer Stelle.
* **HARDWARE.md Abschnitt 8** zeigt die Kalibrierung als Substitutionen; die
  Abgleichtabelle in Abschnitt 6 ist auf den aktuellen Stand datiert.
* **Drei veraltete Stellen in der README korrigiert**, die V1.2.0 und V1.3.0
  hinterlassen hatten: der Kalibrierlogger galt noch als dauerhaft aktiv, die
  Kalibrierwerte standen als dritte Kopie im Klartext, und die evcc-Tabelle
  nannte Adresse, Ladepunkt und Fahrzeug-ID statt der Substitutionen.
* **Abschnitt 1** nennt jetzt drei Wege zum Lademodus statt zwei — die
  Touchflächen auf `ev_page` fehlten. Sie kennen zusätzlich `OFF`, und sie sind
  nur bei angestecktem Fahrzeug wirksam. Der Ladeplan hat weiterhin zwei Wege.
* **Abschnitt 8 «Bekannte Punkte» geleert** bis auf die Wetteranimation. Die
  übrigen Einträge sind Aufgaben, keine Betriebshinweise, und werden angegangen
  statt dokumentiert.
* **Zwei Absätze ohne Bezug zum Betrieb entfernt:** die Herkunftsgeschichte der
  alten Symbole und die allgemeine Erläuterung zum Recorder-Verhalten von Home
  Assistant.

---

## [1.2.1] - 2026-08-18

### Entfernt

* **Drei nie gelesene Abonnements.** `sensor.home_power`,
  `sensor.temperature_living_room` und `sensor.humidity_living_room` wurden aus
  Home Assistant importiert, aber in keinem Lambda verwendet. Jedes kostete ein
  Abonnement und liess jede Zustandsänderung über den Event-Bus ans Gerät
  schicken, ohne dass irgendwo etwas davon zu sehen war. Damit sinkt die Zahl
  der abonnierten Entitäten von 27 auf 24.

  Nebenbei korrigiert: README und CHANGELOG sprachen bisher von 28 Entitäten,
  tatsächlich waren es 27.

### Geändert

* **Sprechende IDs statt Eigennamen und Abkürzungen.** Die internen Bezeichner
  hiessen teils nach dem Fahrzeug des Autors, teils nach deutschen
  Anlagenbegriffen. Für einen Nachbau ist beides nichtssagend:

  | vorher | nachher |
  | :--- | :--- |
  | `grigio_connected`, `grigio_charging`, `grigio_soc`, `grigio_range`, `grigio_target_soc` | `vehicle_*` |
  | `solar_input` | `pv_power` |
  | `solar_grid_power` | `grid_power` |
  | `solar_battery_soc`, `solar_battery_power` | `battery_soc`, `battery_power` |
  | `heizstab_power`, `heizstab_power_percent` | `heater_power`, `heater_percent` |
  | `wp_electric_power`, `wp_heat_power` | `heatpump_power_electric`, `heatpump_power_heat` |

  Zusammen 92 Fundstellen. Alle betroffenen Objekte sind geräteintern; in Home
  Assistant ändert sich dadurch nichts.

### Dokumentation

* **Abschnitt 8 der README aufgeräumt.** Vier Einträge beschrieben Punkte, die
  in V1.1.1 und V1.2.0 behoben wurden: der dauerhaft aktive Kalibrierlogger,
  die Schreibfehler in den LED-IDs, die drei ungenutzten Abonnements und die
  Rückkehrfläche, die den Ladeplan-Timer weiterlaufen liess. Der Punkt zum
  fehlenden Abbrechen bleibt bestehen, ist aber auf den heutigen Stand gebracht.

---

## [1.2.0] - 2026-08-18

### Hinzugefügt

* **Schalter «Touch Kalibrierlog».** Das `on_touch`-Lambda gibt bei jeder
  Berührung Bildschirm- und Rohkoordinaten aus. Die Rohwerte des `xpt2046`
  fallen von Panel zu Panel anders aus und werden gebraucht, um `calibration:`
  für ein neues Board zu füllen — bisher lief diese Ausgabe unbedingt mit.
  Jetzt hängt sie an einem Schalter der Kategorie *Konfiguration*, der nach
  jedem Neustart auf *aus* steht. Damit bleibt das Gerät im Normalbetrieb
  still, und die Kalibrierung ist trotzdem ohne Codeänderung und ohne
  Neuflashen möglich.

* **Logausgabe des `xpt2046` auf `INFO` gesetzt.** Die Komponente meldet bei
  jedem Abtastvorgang eine Zeile mit den Rohkoordinaten auf `DEBUG` — bei 50 ms
  Abtastung rund 20 pro Sekunde, solange ein Finger aufliegt. Das
  `on_touch`-Lambda liefert dieselbe Information einmal pro Berührung und nur
  auf Wunsch; der Rohdatenstrom daneben macht das Log unlesbar.

### Behoben

* **Die drei Modusflächen der Wallbox-Seite waren auch ohne Fahrzeug aktiv.**
  Sie werden nur im Zweig «verbunden» gezeichnet; zeigt die Seite `Nothing
  connected to wallbox`, lag darunter trotzdem eine wirksame Fläche und ein
  Tipper ins Leere schaltete den evcc-Modus um. Sie prüfen jetzt zusätzlich den
  Anschlusszustand — derselbe Fehlertyp wie bei der Rückkehr-Fläche in V1.1.1.

* **Die sechs Pfeilflächen der Ladeplan-Seite lagen 10 px zu hoch.** Gezeichnet
  werden 60 × 60 grosse Bilder bei `y = 40` und `y = 160`, die Flächen standen
  auf `y = 30…90` und `y = 150…210`. Oberhalb jeder Taste war damit ein
  unsichtbarer Streifen wirksam, während die unteren 10 px der sichtbaren Taste
  nicht reagierten. Flächen und Bilder decken sich jetzt.

  Aufgefallen beim Abgleich aller Berührungsflächen gegen die Zeichenlogik der
  fünf Seiten. Die übrigen sechs Flächen sind in Ordnung: die drei Kacheln der
  Übersicht liegen über Elementen, die immer gezeichnet werden, und die
  Rückkehr-Fläche ist seit V1.1.1 an das Zurück-Symbol gebunden.

### Entfernt

* **Auskommentierter Kalibrierblock** beim Touchscreen — eine ältere Variante
  desselben `calibration:`/`transform:` mit vertauschtem `x_min`/`x_max`,
  ersetzt durch die aktive Fassung darunter.

* **Vier auskommentierte Zeichenbefehle** in den Display-Lambdas: ein
  `dry_icon` im Zweig ohne Regenmeldung, eine zweite Zeile zum Ladeplan auf der
  Wallbox-Seite und drei Pfeilvarianten im Energieflussbild.

* **Ein `if`/`else` mit zwei identischen Zweigen.** Die Abfrage
  `solar_input > -1000` führte in beiden Fällen dieselbe Zeile aus.

* **Nie verwendete Umlaut-Glyphen** aus allen fünf Schriftgrössen. Auf dem
  Display erscheint kein deutscher Text — die Beschriftungen sind englisch, die
  aus Home Assistant übernommenen Zustände ebenfalls.

* **Ein toter Kommentarkopf** (`# Setup the ili9xxx platform`) über dem
  `interval:`-Block.

### Geändert

* **Tippfehler in zwei IDs behoben:** `now_indiactor` → `now_indicator`,
  `plan_indiactor` → `plan_indicator`. Beide Lichter sind `internal: true`, in
  Home Assistant ändert sich dadurch nichts.

### Dokumentation

* **`HARDWARE.md` Abschnitt 8 «Touch kalibrieren» neu.** Was `calibration:` und
  `transform:` bedeuten, und der Ablauf für ein neues Panel in sieben
  Schritten.

* **Inbetriebnahme-Anleitung in Abschnitt 6 der README.** Acht Schritte vom
  Hardwareumbau bis zur ersten Diagnose, mit den drei Stellen, an denen ein
  Nachbau erfahrungsgemäss hängen bleibt: die Umbauten am Board, die fest
  verdrahteten Entitäts-IDs und die Touch-Kalibrierung.

---

## [1.1.1] - 2026-08-18

### Behoben

* **`nan` auf den Anzeigeseiten nach jedem Neustart.** Von 28 importierten
  Home-Assistant-Entitäten waren vier mit `has_state()` abgesichert, alle auf
  der Übersichtsseite. Ein ESPHome-Sensor startet mit `NAN`, bis der erste Wert
  aus HA eintrifft — bis dahin stand auf der Wallbox-, Batterie- und
  Energieseite überall `nan W` beziehungsweise `-nan %`. Jetzt zeigen alle
  Seiten `---`, solange ein Wert fehlt.

  Auf der Energieseite kam ein zweiter Effekt dazu: Netzbezug und
  Batterieleistung laufen dort durch `min()` und `max()`, und die geben gegen
  `NAN` den anderen Operanden zurück. Aus dem fehlenden Wert wurde damit
  stillschweigend eine Null, und die als Restgrösse gerechnete Hausleistung war
  entsprechend zu hoch. Beide Sensoren werden nun direkt geprüft.

  Ebenfalls behoben: Ohne Fahrzeug-SoC bekam `filled_rectangle()` auf der
  Wallbox-Seite `NAN` als Balkenbreite.

* **Die Rückkehr-Fläche brach den Ladeplan nicht ab.** `button_return` war der
  einzige Touch-Bereich ohne Seitenbindung und lag damit unsichtbar auch über
  der Ladeplan-Seite, direkt neben dem SoC-Pfeil. Ein Tipper daneben sprang zur
  Übersicht, während `plan_setup_timeout_timer` weiterlief und den Plan zehn
  Sekunden später trotzdem an evcc schickte. Die Fläche ist jetzt auf die drei
  Seiten beschränkt, die oben rechts auch ein Zurück-Symbol zeichnen.

---

## [1.1.0] - 2026-08-17

### Geändert

* **Sämtliche Symbole durch Material Design Icons ersetzt (Apache-2.0).** Die
  bisherigen 33 Bilddateien waren über die Jahre aus verschiedenen Quellen
  zusammengesucht; ihre Herkunft und damit ihre Lizenz liess sich nicht mehr
  klären. In einem MIT-lizenzierten öffentlichen Repository ist das nicht
  haltbar — eine MIT-Lizenz räumt Rechte ein, die man selbst halten muss. Der
  neue Satz stammt vollständig aus einer Quelle mit bekannter Lizenz und liegt
  erstmals mit im Repository; die Konfiguration ist damit ohne Handarbeit
  baubar. Als Nebeneffekt sind die Grössen einheitlich (vorher 30 × 30 bis
  2065 × 2050) und der Ordner schrumpft von 608 KB auf 144 KB.

* **Wärmepumpe statt Klimagerät.** Das Gerät auf der Energieseite ist eine
  Wärmepumpe; das Symbol zeigte bisher einen Ventilator mit der Aufschrift
  «A/C».

* **Knotenpunkt statt Ventil.** Die beiden Symbole in der Mitte des
  Energieflussbildes stellen die Punkte dar, an denen die Flüsse
  zusammenlaufen — nicht Armaturen. Sie zeigen jetzt einen Sammelpunkt.

* **Wetteranimation nachgebaut.** Zwei Bilder wie bisher, Sonne hinter
  Regenwolke, zwischen den Bildern dreht sich die Sonne um eine halbe
  Strahlenteilung. Weiterhin reine Dekoration ohne Bezug zur gemeldeten
  Wetterlage, siehe Abschnitt 8 der README.

### Behoben

* **Leistungsangabe der Hausbatterie wurde vom Symbol überdeckt.** Das Symbol
  bei `(90,189)` belegt 46 × 46 Pixel und damit die Zeilen bis y 235, die Zahl
  stand auf y 220. Sie steht jetzt rechtsbündig unter der Prozentangabe in der
  linken Spalte.

  Ursache war das Seitenverhältnis: `resize:` passt ein Bild unter Wahrung
  seines Seitenverhältnisses in den angegebenen Kasten ein. Die alte Vorlage
  war 46 × 29 gross und endete deshalb bei y 218, die neue ist quadratisch und
  füllt den Kasten aus.

* **Beschriftungen der Wärmepumpe klebten am Symbol.** Die Heizleistung stand
  mit `BOTTOM_CENTER` auf y 89, die elektrische Leistung mit `TOP_CENTER` auf
  y 122 — das Symbol belegt y 85 bis 125, beide ragten hinein. Jetzt y 83 und
  y 127, also 2 px Abstand wie bei der Wallbox darüber.

* **Wärmepumpe und Haus standen zu eng beieinander.** Das Haussymbol ist von
  y 147 auf y 157 gerückt, seine Beschriftung von y 189 auf y 199. Zwischen der
  elektrischen Leistung der Wärmepumpe und dem Haussymbol liegen damit 12 statt
  2 px.

* **Pfeile treffen den Pol der Hausbatterie.** Das Batteriesymbol ist von
  `x = 90` auf `x = 98` gerückt, die Pfeile bleiben unverändert auf `x = 103`.

  Der Ladeblitz rechts im Symbol verschiebt dessen optische Mitte nach rechts;
  der Pol lag dadurch bei x 105, während die Pfeilspalte auf x 113 steht. Nicht
  die Pfeile durften wandern — sie bilden die Verbindung zum Sammelpunkt und
  stehen in einer Flucht mit den Solarpfeilen darüber. Verschoben wurde deshalb
  das Symbol, bis sein Pol unter der Pfeilspalte liegt.

### Dokumentation

* **`HARDWARE.md` neu.** Die Umbauten am CYD waren bisher nirgends im
  Repository festgehalten, obwohl die Konfiguration ohne sie nicht läuft: zwei
  der vier Tastersignale liegen am unveränderten Board auf keinem Stecker.

  Das Dokument beschreibt Speisung, Taster und Kabelbelegung, die drei
  Modifikationen — LDR-Mod, Entfernen der RGB-LED, Auftrennen und Neuverdrahten
  von `P3` — sowie den fehlenden Pull-up an `GPIO35`, mit sieben Fotos in
  `images/` und einer Abgleichtabelle gegen die Firmware. Abschnitt 2 der README
  verweist darauf.

  Festgehalten ist dabei auch, welcher Stecker welchen Taster trägt: `P3` den
  Taster «Charge Now» mit `GPIO35` und roter LED, `CN1` den Taster «Charge Plan»
  mit `GPIO22` und blauer LED. Am Board erkennbar am Siebdruck — `P3` ist der
  Stecker mit `IO35`.

* **Gehäuse und 3D-Modell aufgenommen.** Abschnitt 7 von `HARDWARE.md`
  beschreibt das zweiteilige Wandgehäuse — Schale und Frontblende — mit Renderings
  und Fotos des geöffneten Geräts. Die Konstruktionsdaten liegen in `3D/` als
  Fusion-Archiv und als STEP für andere CAD-Programme.

* **Fotos des Geräts.** Fünf Aufnahmen in `images/`, darunter eine im Kopf der
  README.

* **Metadaten aus allen Fotos entfernt.** Fünf der ursprünglichen Aufnahmen
  trugen GPS-Koordinaten des Aufnahmeorts, dazu Kameramodell und Zeitstempel.
  In einem öffentlichen Repository hat das nichts verloren.

### Hinweis

Der Flash-Bedarf steigt von 75.0 % auf 76.7 %. Grund ist allein die Pixelzahl:
ESPHome legt jedes Bild unkomprimiert als `Breite × Höhe × 3` Bytes ab, und die
quadratischen Vorlagen füllen ihren `resize:`-Kasten vollständig aus, wo die
alten hochkant-Vorlagen schmaler eingepasst wurden. Die Bilddaten wachsen
dadurch von 215'619 auf 247'545 Bytes.

---

## [1.0.0] - 2026-07-30

### Erstrelease

Aufnahme des bereits im Betrieb stehenden Info-Displays ins Repository. Der
funktionale Stand entspricht dem, was auf dem Gerät läuft; ergänzt wurden nur
die repo-seitig zwingenden Punkte (siehe unten).

* **Plattform:** ESP32-2432S028R («Cheap Yellow Display») mit 2.8"-TFT
  (320 × 240, `ili9342` über SPI) und resistivem Touch (`xpt2046` auf einem
  zweiten SPI-Bus). ESP-IDF-Framework, `minimum_chip_revision: 3.1`.
* **Fünf Display-Seiten:** Übersicht (Wetter, PV, Hausbatterie, Wallbox),
  EV-Detail mit Balkenanzeige und Modusumschaltung, Ladeplan-Eingabe,
  Hausbatterie mit 24-h-Verlaufsgraph und ein Energieflussbild mit animierten
  Richtungspfeilen.
* **Touch-Bedienung:** Kachelbereiche auf der Übersicht führen in die
  Unterseiten, eine Rückkehr-Fläche oben rechts zurück. Nach zwei Minuten ohne
  Berührung fällt die Anzeige selbständig auf die Übersicht zurück.
* **Zwei Hardware-Taster:** «Schnellladen» (GPIO35) schaltet evcc zwischen
  `NOW` und `PV` um, «Ladeplan» (GPIO22) löscht einen bestehenden Plan oder
  öffnet die Eingabeseite. Zwei zugehörige Status-LEDs (GPIO17, GPIO27)
  spiegeln den evcc-Zustand.
* **Direkte evcc-Steuerung über REST** (`http_request`), ohne Umweg über eine
  Home-Assistant-Automation: Lademodus `now`/`pv`/`off` sowie Anlegen und
  Löschen eines SoC-Ladeplans. Der Zeitstempel des Plans wird in einem Lambda
  aus den drei eingestellten Werten gebildet.
* **Zwei Template-Schalter für Home Assistant** («EVCC Schnellladen», «EVCC
  Planladung»), damit die beiden Hardware-Funktionen auch aus HA heraus
  bedienbar sind.
* **Helligkeitsnachführung:** Der LDR auf GPIO34 schaltet die
  Hintergrundbeleuchtung zwischen 100 % und 50 %, mit einem Totband zwischen
  den beiden Schaltschwellen.
* **Datenquellen:** 21 Zahlen-, drei Text- und vier Binärsensoren werden aus
  Home Assistant importiert (PV-Anlage, Hausbatterie, Wärmepumpe, Heizstab,
  Wetterstation, evcc). Das Gerät rechnet die Hausleistung im Energiebild als
  Restgrösse selbst aus.
* Gemeinsames Diagnose-Paket `common/diagnostics.yaml` eingebunden, mit auf den
  ESP32 angehobenen Heap-Grenzen (80 kB / 40 kB).

### Für die Repo-Aufnahme geändert

* **Zugangsdaten über `!secret` ausgelagert.** API-Key, OTA-Passwort und die
  Zugangsdaten des Fallback-AP standen bisher im Klartext in der YAML. Neu:
  `frontroom_api_key`, `frontroom_ota_key`, `frontroom_fallback_ap_ssid` und
  `frontroom_fallback_ap_password`. Die Werte sind unverändert übernommen, es
  wurde nichts rotiert.
* **`fw_version`-Substitution und `project:`-Block ergänzt**, damit der
  Firmwarestand am Gerät ablesbar ist und die Versionierung des Repos greift.

Die Bilddateien unter `pic/` sind **nicht** Teil des Repositorys (siehe
README, Abschnitt 6). Die Repo-Kopie ist damit dokumentiert, aber nicht
eigenständig baubar.
