# Changelog

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/)
und dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

## [1.1.0] - 2026-06-04

### Hinzugefügt
- **Architektur-Upgrade (State Machine):** Das System arbeitet nun deterministisch mit einem im Flash-Speicher gesicherten Tagesstatus. Dies verhindert unvorhersehbares Verhalten durch Verbindungsabbrüche oder ungeplante Reboots.
- **Resume-Fähigkeit (Ausfallsicherheit):** Die gelaufene Bewässerungszeit wird minütlich schonend im RTC-Speicher (Real-Time Clock RAM) gesichert. Nach einem Reboot während des Zyklus (z. B. durch einen HA-Neustart) nimmt der ESP die Bewässerung nahtlos wieder auf, bis die berechnete Zielzeit erreicht ist.
- **Boot-Recovery (Logbuch):** Beim Neustart des ESPs rekonstruiert das System den exakten letzten Status aus dem Speicher, um den Zustand `unknown` in Home Assistant zu verhindern. Im Leerlauf meldet das System nun einmalig `Bereit`.

### Geändert
- **Spam-freies Logging:** Der automatische Statuswechsel auf "Standby" um Mitternacht wurde entfernt. Das Logbuch wird nur noch bei funktionalen Änderungen (Start, Ende, Abbruch) aktualisiert, um unnötiges "Rauschen" zu vermeiden.
- **Dashboard-Optimierung (HACS):** Anstelle der nativen HA-Logbuch-Karte wird nun die HACS-Komponente `logbook-card` empfohlen. Dies blendet systembedingte Netzwerk-Artefakte (`unavailable`, `unknown`) visuell aus und sorgt für ein perfekt sauberes Protokoll im Dashboard.

### Behoben
- **Race Condition (Sonnenaufgang):** Ein Fehler wurde behoben, bei dem die `sun`-Komponente exakt ab der Minute des Sonnenaufgangs bereits die Zielzeit für den Folgetag lieferte (Morgen-Flip), wodurch Zyklen übersprungen wurden. Die Zielzeit wird nun nach Mitternacht sicher gecacht.

## [1.0.1] - 2026-06-02

### Hinzugefügt
- **Bedienkomfort (Offset-Slider):** Beim Verstellen des Sonnenaufgangs-Versatzes im Dashboard wird die Tages-Sperre (`has_run_today`) nun automatisch zurückgesetzt. Dies ermöglicht eine erneute Auslösung am selben Tag, falls die Startzeit in die Zukunft verschoben wird.

### Behoben
- **Logbuch-Fix (Unsichtbares Zeichen):** Das Skript hängt nun an geraden Tagen im Jahr ein unsichtbares Zeichen (Zero-Width Space, `\u200B`) an die Statusmeldungen an. Dadurch erzwingen wir jeden Tag eine echte Statusänderung für Home Assistant, sodass identische Meldungen (z. B. mehrtägiger Regen-Abbruch) zuverlässig im Logbuch protokolliert werden.
- **Mehrfach-Auslösung (Tages-Sperre):** Das Setzen der Tages-Sperre wurde ganz an den Anfang des `start_irrigation_cycle`-Skripts verschoben. Dies verhindert, dass das Skript während der 60 Sekunden, in denen die Startbedingung wahr ist, fälschlicherweise mehrfach ausgelöst wird.

## [1.0.0] - 2026-05-28

### Hinzugefügt
- Initiale Version der intelligenten ESPHome-Bewässerungssteuerung (`ha_irrigation.yaml`).
- Home Assistant Lovelace-Dashboard-Konfiguration mit Mushroom-Cards (`dashboard.yaml`).
- Ausführliche Projektdokumentation (`README.md`) inklusive detaillierter Erklärung des wetterabhängigen Bewässerungsalgorithmus.
- Integration der **MIT-Lizenz** als rechtliche Grundlage für das Repository.

### Geändert
- **Sicherheits-Fix (Skript-Abbruch):** Dem Master-Schalter `ventil_all` wurde in der `turn_off_action` die Aktion `- script.stop: start_irrigation_cycle` hinzugefügt. Dies stellt sicher, dass das Automatik-Skript bei einem manuellen Eingriff sofort hart beendet wird und nicht unsichtbar im Hintergrund weiterläuft.
- **Architektur & Versionierung:** Einführung von zentralen Versionsnummern über ESPHome `substitutions` (`fw_version: "1.0.0"`) zur einfachen Pflege bei zukünftigen Updates.
- **Validierungs-Fix (Namespace):** Anpassung des `project.name` im `esphome`-Block auf das erforderliche Namespace-Format (`<github_name>.ha_irrigation`), um den Validierungsfehler (*project name needs to have a namespace*) der ESPHome-Build-Pipeline permanent zu beheben.
