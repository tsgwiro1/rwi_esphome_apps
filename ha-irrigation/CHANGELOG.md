# Changelog

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/)
und dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

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
