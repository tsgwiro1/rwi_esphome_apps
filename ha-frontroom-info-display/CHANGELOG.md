# Changelog - ha-frontroom-info-display

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

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
