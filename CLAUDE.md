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

Lokal ↔ HA synchronisiert Roger mit `~/esphome/sync2HA.command` (rsync in beide
Richtungen). Der Abgleich zum Repo passiert von Hand.

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

## Chat-Aufteilung

Ein Chat pro Gerät, plus einer für Querschnittsarbeit (`common/`, HA-seitige
Themen wie `recorder`, repo-weite Umbauten). Chat-Grenze = Commit-Grenze.

Mehrere Chats dürfen offen sein, aber immer nur einer schreibt und committet
gerade — Git-Index und Arbeitsverzeichnis sind geteilt.
