# Changelog - ha-frontroom-info-display

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

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
