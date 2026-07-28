# Changelog - ha-smartrelais

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.0.1] - 2026-07-28

Dieser Eintrag holt Änderungen nach, die bereits auf dem Gerät liefen, aber nie ins Repository zurückgeflossen sind. Die Repo-Fassung beschrieb damit einen Stand, den es real nicht mehr gab.

### Hinzugefügt
* **Definierter Funkpfad beim Boot:** Neuer `on_boot`-Block mit Priorität 800, der den Onboard-RF-Switch über `GPIO3` aktiviert und mit `GPIO14` fest die **interne Keramikantenne** auswählt (beide über neue GPIO-Ausgänge `rf_switch_enable` und `rf_antenna_select`). Damit ist der Funkpfad unabhängig vom Auslieferungszustand des XIAO-ESP32-C6-Moduls eindeutig festgelegt - dieselbe Behandlung wie bei `wp-fp1-smartblock`. Der `on_boot`-Abschnitt ist dafür auf eine Liste mehrerer Prioritäten umgestellt; die Wiederherstellung der Zählerstände bleibt unverändert auf Priorität -100.

### Geändert
* **Nummerierung der projektlokalen Sensoren** nach dem Schema des Diagnose-Pakets (Kategorie 1.x ist dafür reserviert): `1.0 Betriebsstunden total`, `1.1 Einschaltzeit heute`, `1.2 Schaltspiele heute`, `1.3 Temperatur-Warnung`, `1.4 SSR Spitzentemperatur heute`. Dadurch stehen sie auf der Geräteseite in Home Assistant sauber vor den Diagnose-Entitäten der Kategorien 2.x bis 6.x.

  *Hinweis:* Die Entity-IDs bestehender Installationen bleiben unverändert (HAs Registry hängt an der `unique_id`), es ändern sich nur die Anzeigenamen. Bei einer Neuinstallation ergeben sich dagegen IDs mit dem Nummernpräfix.
* **Zeilenenden auf LF normalisiert.** Die Datei lag im Arbeitsverzeichnis mit CRLF vor, was jeden Diff gegen das Repository unlesbar machte (1'182 vermeintlich geänderte Zeilen bei tatsächlich 38).

### Offen
* Das Gerät war zum Zeitpunkt dieses Commits nicht erreichbar und läuft daher noch mit der vorherigen Firmware. Die gebaute Firmware liegt bereit; nach dem nächsten OTA meldet `5.1 Common Diagnostics Version` dann 1.3.0 statt 1.2.1.

---

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
