# Changelog

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/)
und dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

## [1.1.2] - 2026-07-28

### Geändert
* **Die neun Konfigurationsregler pollen nicht mehr.** Sie waren als Template-`number` mit `lambda:` gebaut und damit Polling-Komponenten, die ihren Wert im Standardtakt von 60 s bedingungslos neu publizierten - obwohl es reine Konfigurationswerte sind, die sich nur ändern, wenn man den Regler bewegt. Das waren rund **13'000 Meldungen pro Tag**, die in Home Assistant jeweils Datenbankzeilen erzeugten.

  Umgesetzt über `update_interval: never` plus gezieltes Publizieren an genau zwei Stellen:
  * einmalig im `on_boot` (vor dem 10-s-Delay, damit Home Assistant die Werte sofort hat und nicht kurzzeitig `unknown` anzeigt),
  * im jeweiligen `set_action` nach dem Schreiben des Globals.

  Der Publish im `set_action` ist zwingend: `TemplateNumber::control()` publiziert nur bei `optimistic: true`, und diese Regler nutzen `lambda:`, sind also nicht optimistisch. Ohne ihn würde der Regler in Home Assistant nach dem Verstellen auf den alten Wert zurückspringen, weil kein Poll mehr nachliefert.

  Abgesichert ist das dadurch, dass die `conf_*`-Globals ausschliesslich in diesen neun `set_action`-Blöcken geschrieben werden - es gibt keinen anderen Pfad, der einen Wert ändern könnte, ohne dass der Publish mitläuft.

### Nicht geändert
* Bewässerungslogik, State Machine, Resume-Fähigkeit und Sicherheitsmechanismen sind unberührt. Die Regler liefern ihre Werte weiterhin aus denselben neustartfesten Globals.

## [1.1.1] - 2026-07-28

Dieser Eintrag holt Änderungen nach, die bereits auf dem Gerät liefen, aber nie ins Repository zurückgeflossen sind. Die Repo-Fassung beschrieb damit einen Stand, den es real nicht mehr gab.

### Entfernt
* **Projektlokaler Sensor «Firmware Version»** (`fw_version_sensor`). Das gemeinsame Diagnose-Paket liefert die Versionsinformation bereits über `5.0 ESPHome Version` und `5.1 Common Diagnostics Version`; der eigene Sensor war eine Dublette.
* **Projektlokaler Button «Neustart».** Ebenfalls doppelt - das Diagnose-Paket stellt ihn als `6.0 Neustart` bereit, zusätzlich zu `6.1 Safe Mode Neustart`.

### Geändert
* README: Das Dashboard-Beispiel verwies noch auf die alte Entity-ID `button.ha_irrigation_neustart`. Korrigiert auf `button.ha_irrigation_6_0_neustart`, die Entität aus dem Diagnose-Paket.

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
