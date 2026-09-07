# Arbeitsanweisungen für dieses Repository

Monorepo mit ESPHome-Konfigurationen. Jeder Unterordner ist ein eigenständiges
Projekt mit eigener Version, eigenem `CHANGELOG.md` und eigener `README.md`.

## Die drei Orte einer YAML

Dieselbe Gerätedatei existiert dreifach und muss identisch bleiben:

| Ort | Pfad | Rolle |
| :--- | :--- | :--- |
| Repo | `~/repos/rwi_esphome_apps/<projekt>/<projekt>.yaml` | versionierte Quelle |
| Lokal | `~/esphome/<projekt>.yaml` | Arbeitskopie, hier wird gebaut |
| HA | `ha:/config/esphome/<projekt>.yaml` | ESPHome-Add-on |

Lokal ↔ HA wird mit `~/esphome/sync2HA.command` abgeglichen (rsync in beide
Richtungen, ohne `--delete`). **Das Skript führst du selbst aus**, sobald eine
Geräte-YAML in `~/esphome` geändert wurde — nicht Roger, und nicht erst auf
Nachfrage. Sonst baut der Update-Knopf in Home Assistant aus einer veralteten
Kopie. Der Abgleich zum Repo passiert weiterhin von Hand.

**Bei Abweichung ist `~/esphome` massgeblich, nicht das Repo.** Belegt am
2026-07-28: Im Repo fehlte bei `ha-smartrelais` der `on_boot`-Block für
RF-Switch und Antennenwahl — ein Flash aus dem Repo hätte dem Gerät den
definierten Funkpfad genommen. Also **immer erst diffen, dann bauen**, und bei
Unterschieden nicht raten, sondern nachfragen, welcher Stand gilt.

Zeilenenden können täuschen (CRLF vs. LF). Vor dem Vergleich normalisieren:

```sh
diff <(tr -d '\r' < a.yaml) <(tr -d '\r' < b.yaml)
```

Zugriff auf HA geht per `rsync --rsync-path="sudo rsync" ha:/config/esphome/…`.
`scp` scheitert, HA-OS hat kein SFTP-Subsystem.

## Bauen, prüfen, flashen

Nur in `~/esphome` — dort sind `secrets.yaml` und die Packages auflösbar.

```sh
cd ~/esphome
PLATFORMIO_CORE_DIR="$HOME/.platformio_esphome" ~/.local/bin/esphome config <gerät>.yaml
PLATFORMIO_CORE_DIR="$HOME/.platformio_esphome" ~/.local/bin/esphome compile <gerät>.yaml
PLATFORMIO_CORE_DIR="$HOME/.platformio_esphome" ~/.local/bin/esphome upload <gerät>.yaml --device <ip>
```

`config` prüft nur das Schema, `compile` auch den C++-Code in den Lambdas.
Änderungen an Lambdas immer kompilieren.

## Ein Wert, eine Stelle

**Jeder Parameter und jede Konfiguration steht genau einmal in der YAML. Keine
Doppelung.** Ein Schwellwert, eine Zeitspanne, ein Grenzwert: eine Definition,
alle anderen Stellen verweisen darauf. Je nach Fall ist die Quelle

* eine Zeile unter `substitutions:`, referenziert als `${name}`,
* ein `number`, `select` oder `globals`, gelesen mit `id(name).state`,
* oder der Wert in `common/`, wenn er mehrere Geräte betrifft.

Ein zweites Mal hingeschriebenes Literal ist keine Kopie, sondern ein zweiter
Wert.

**Warum:** Wer den Sollwert ändert, ändert die Stelle, die er sieht. Die
andere bleibt stehen und wirkt weiter — das Gerät verhält sich dann nach einem
Wert, der nirgends mehr als Sollwert geführt wird. Das fällt erst im Betrieb
auf, und dort am teuersten.

**Wie umsetzen:** `.claude/hooks/yaml-single-source.sh` erzwingt die Prüfung.
Der Hook blockiert `git commit`, solange eine YAML gestagt und die Prüfung
nicht quittiert ist, und legt die neuen und geänderten Zeilen vor. Quittiert
wird mit `.claude/hooks/yaml-single-source.sh --ok` — **erst nach der
Prüfung**; eine Quittung ohne Prüfung belügt den nächsten Chat. Die Marke
hängt am Inhalt des Index und verfällt, sobald danach noch etwas gestagt wird.

Grenzfälle benennen statt stillschweigend durchwinken. Pixelkoordinaten,
Farbwerte und Pin-Nummern sind oft zufällig gleich und keine Doppelung.

## Geheimnisse

Passwörter, API-Keys, SSIDs und OTA-Keys gehören ausschliesslich nach
`~/esphome/secrets.yaml` und werden per `!secret` referenziert. Niemals im
Klartext in eine Repo-YAML.

## Versionierung

Jede inhaltliche Änderung an einem Projekt hebt dessen Version nach SemVer
(Bugfix → Patch, Feature → Minor, Breaking oder Hardware-Layout → Major).
Vier Stellen gehören dabei nachgezogen:

1. `fw_version`-Substitution in der Geräte-YAML
2. neuer datierter Abschnitt in `<projekt>/CHANGELOG.md`
3. Versions-Badge in `<projekt>/README.md`
4. Versionsspalte in der Tabelle im Root-`README.md`

`common` hat eine eigene Version. Sie wird über die `version`-Substitution in
`diagnostics.yaml` an den Sensor `5.1 Common Diagnostics Version` durchgereicht
— daran ist ablesbar, welches Gerät den Paketstand schon geflasht hat.

Reine Doku-Commits ohne Firmware-Änderung heben die Version **nicht** an und
sagen das im Commit-Body ausdrücklich.

## Git

**Commits nur nach Rückfrage.** Änderungen vorbereiten, Diff zeigen, fragen.

**Ein Projekt pro Commit.** Keine Vermischung zwischen Geräten oder zwischen
Gerät und `common`. Die zugehörige Zeile im Root-`README.md` darf mit, sofern
sie dasselbe Projekt betrifft. Auch zusammenhängende Korrekturen über mehrere
Projekte werden aufgeteilt — sonst steht in der Historie eines Geräts ein
Commit mit fremdem Titel.

Commit-Messages auf Deutsch im Stil der Historie
(`<projekt>: V1.0.1 – Kurzbeschreibung`), **ohne** `Co-Authored-By`-Zeile.

**Vorsicht bei `git add <projekt>/`** — das zieht untracked Dateien mit rein.
Vor dem Commit `git diff --cached --name-only` prüfen.

Zu jedem Versionssprung gehört ein **annotierter** Tag im Schema
`<projekt>/v<version>`, auch für `common`. Der Tag zeigt auf den letzten
Commit, der das Projekt in dieser Version berührt hat.

```sh
GIT_COMMITTER_DATE="$(git log -1 --format=%aI <commit>)" \
  git tag -a "<projekt>/v<version>" <commit> -m "<beschreibung>"
```

Gepusht wird **nicht** aus dem Terminal — Roger pusht selbst über den
Fork-Client. Tags gehen dabei nicht automatisch mit, die Option muss aktiv sein.

## Datenbanklast in Home Assistant

Eine ESPHome-Meldung ist **keine** Datenbankzeile. HA schreibt nur, wenn sich
Status oder Attribute tatsächlich ändern; identische Wiederholungen feuern
`STATE_REPORTED` statt `STATE_CHANGED` und werden vom Recorder verworfen. Eine
hohe Melderate bedeutet also nicht automatisch DB-Last.

Vor jeder Aussage über Schreiblast **messen**, nicht schliessen — `total_count`
je Entität aus der Recorder-Historie ist die echte Zeilenzahl.

Melderate senken bleibt trotzdem sinnvoll: für Netzwerk- und Event-Bus-Last und
gegen Flash-Verschleiss (jeder `ClimateCall::perform()` löst über
`Climate::publish_state()` ein `save_state_()` ins NVS aus).

## Diagnosedaten nach einem Neustart

**Nach einem Reboot oder OTA brauchen die Diagnosewerte ein bis zwei Minuten,
bis sie stimmen.** Vorher melden besonders WLAN und Heap falsche Werte. Nicht
in dieser Zeit messen, vergleichen oder Schlüsse ziehen — erst abwarten.

Der Grund liegt in den Abfragezyklen und in der Startbelegung `NAN`. Die
Quellsensoren `2.1 WLAN Signalpegel` und `4.1 Freier Speicher` liefern ihren
ersten Wert erst nach 60 s (`polling_component_schema("60s")`). Ein Sensor
startet aber mit `Sensor::Sensor() : state(NAN)`, und die Ampel-Lambdas von
`2.0 WLAN Status` und `4.0 System Gesundheit` vergleichen diesen Startwert
direkt mit ihren Schwellen. Jeder Vergleich gegen `NAN` ist falsch, also fallen
beide in den `else`-Zweig und melden **„🔴 Kritisch", obwohl nichts kritisch
ist**. `2.4 Verbundener Access Point` steht aus demselben Grund kurz auf
„⚠️ Nicht verbunden", weil die BSSID noch leer ist.

Beim Beurteilen eines Geräts also zuerst `4.2 Laufzeit` ansehen: unter zwei
Minuten sind die Diagnosewerte nicht belastbar.

## Chat-Aufteilung

Ein Chat pro Gerät, plus einer für Querschnittsarbeit (`common/`, HA-seitige
Themen wie `recorder`, repo-weite Umbauten). Chat-Grenze = Commit-Grenze.

Mehrere Chats dürfen offen sein, aber immer nur einer schreibt und committet
gerade — Git-Index und Arbeitsverzeichnis sind geteilt.
