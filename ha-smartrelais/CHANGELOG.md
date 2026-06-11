# Changelog - ha-smartrelais

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.0.0] - 2026-06-11

### Erstrelease

* **Timer-Logik (Treppenlicht-Prinzip):** Wandschalter an J3 (GPIO18) löst auf beide Flanken aus (Software-Entprellung 50 ms); das SSR (GPIO21) schaltet für die eingestellte Einschaltdauer (1–120 min, Default 30 min) ein. Nachtriggern per HA-Schalter wählbar (verlängern oder sofort abschalten).
* **Übertemperaturschutz:** DS18B20 am SSR (GPIO16) mit einstellbarem Abschalt-Limit (Default 70°C), Wiedereinschaltsperre mit 10 K Abkühl-Hysterese und Sensor-Watchdog (60 s, 85°C-Power-On-Wert wird als Lesefehler behandelt).
* **Frühwarnung:** Einstellbare Warnschwelle (Default 60°C) mit Binärsensor und Logbuch-Warnung, ohne Abschaltung.
* **Status-LED an J6 (GPIO0):** Dauerlicht = Relais EIN, 2 Hz = Übertemperatur-Sperre, 0.5 Hz = Sensorfehler, Doppelblitz = deaktiviert (Hauptschalter/Tageslimit).
* **Prioritäten-Kaskade (1 s):** Übertemperatur → Sensorfehler → Hauptschalter → Tageslimit → Dauerbetrieb → Timer. Fail-Safe ist immer Relais AUS; WLAN-/API-Ausfall ist bewusst kein Abschaltgrund (lokale Autonomie).
* **Zähler & Diagnose:** Restzeit, Einschaltzeit heute, Betriebsstunden total (restore-fähig, Flash-Schreibintervall 10 min), Schaltspiele heute, SSR-Spitzentemperatur heute (Mitternachts-Reset über HA-Zeitquelle).
* **Bedienung:** HA-Buttons «Manuell starten» / «Sofort stoppen», Hauptschalter, Dauerbetrieb, Tageslimit (0–12 h, Default deaktiviert); Webserver auf Port 80 für den Betrieb ohne HA.
* **Status-Logbuch:** Klartext-Status wird nur bei Zustandswechseln publiziert (genau ein HA-Logbuch-Eintrag pro Ereignis).
* Gemeinsames Diagnose-Paket `common/diagnostics.yaml` (V1.2.1) eingebunden.
