# Changelog - ha-weather-station

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [3.2.1] - 2026-09-05

Der Kontrollfühler steht bei den Sensoren, nicht bei der Diagnose.

### Achtung beim Update

**Die Entität `1.8 Temperature AM2315` aus V3.2.0 wird durch `Temperature AM2315` ersetzt.** Sie hat rund 20 Minuten existiert, nichts greift darauf zu; der Verlauf dieser Viertelstunde geht verloren.

### Geändert

* **`1.8 Temperature AM2315` heisst neu `Temperature AM2315`** und ist nicht mehr als `entity_category: diagnostic` eingestuft. Er erscheint damit in Home Assistant bei den Sensoren.

### Warum

Die Kapitelnummern `1.x` sind in diesem Repository den Diagnose-Entitäten vorbehalten. Der AM2315 misst aber weiterhin eine echte Umgebungsgrösse und ist kein Diagnosewert des Geräts über sich selbst - er gehört zu den Messwerten. Die abgeleitete Differenz `1.7 Temperature Delta SHT31 - AM2315` bleibt dagegen Diagnose und behält ihre Nummer.

Keine funktionale Änderung: `1.7` rechnet unverändert gegen denselben Fühler, und in keine andere Rechnung geht er ein.

## [3.2.0] - 2026-09-05

Die angezeigte Temperatur kommt jetzt ebenfalls aus dem SHT31; der AM2315 wird zum reinen Kontrollfühler.

### Achtung beim Update

**Der Verlauf von `sensor.temperature_shed` bleibt erhalten, bekommt aber einen Sprung.** Die Entität behält Name, Entity-ID und Langzeitstatistik - ab dem 05.09.2026 stammen ihre Werte jedoch vom SHT31 statt vom AM2315, was einen Versatz von rund **+0.19 K** bedeutet. Vergleiche über dieses Datum hinweg sind um diesen Betrag verschoben.

**Eine Entität kommt hinzu:** `1.8 Temperature AM2315` (Diagnose). Es verschwindet keine.

### Geändert

* **`Temperature Shed` ist eine Kopie des SHT31-Kanals** (`platform: copy`) statt der AM2315-Messwert. Bewusst eine Kopie und keine Umbenennung: Die `unique_id` der ESPHome-Integration lautet `MAC/Subdevice/Domain/Name` - die Quelle kommt darin nicht vor. Bleibt der Name, bleiben Entity-ID, Verlauf und Statistik.
* **Der AM2315 heisst neu `1.8 Temperature AM2315`** und ist als Diagnose eingestuft. Er misst weiter, geht aber in keine Rechnung mehr ein und trägt über `1.7` die einzige Kreuzprüfung der Station. Seine Feuchte wird weiterhin nicht ausgelesen.
* **`Temperature SHT31` bleibt unverändert bestehen** - obwohl es nun denselben Wert zeigt wie `Temperature Shed`. In Home Assistant zeigen drei Verbraucher direkt darauf, die die Temperatur als Einzelpunkt brauchen und nicht als den Ortsmittelwert, in den `Temperature Shed` dort eingeht.

### Warum

Die Wahl fällt nach Datenblatt, nicht nach Messung: SHT31 ±0.2 °C typisch bei 0.04 °C Wiederholbarkeit und < 0.03 °C/Jahr Drift, AM2315 typisch ±0.1 °C aber **max. ±1 °C**, Wiederholbarkeit ±0.2 °C und 0.1 °C/Jahr Drift. Der AM2315 widerspricht sich dabei selbst - genauer als das eigene Rauschen geht nicht -, weshalb mit den ±1 °C zu planen ist. Gemessen liegen die beiden nur 0.19 K auseinander; welcher recht hat, sagt ohne Referenzfühler niemand.

Zusätzlich wird die Anzeige in sich stimmig: Temperatur, Feuchte und Taupunkt stammen seit dieser Version aus demselben Chip, die Spanne Temperatur minus Taupunkt trägt den Versatz der beiden Fühler nicht mehr.

### Folgen

* **`Heater Source: Ambient` ist kein Rückfall auf den zweiten Fühler mehr.** Beide Quellen hängen am SHT31. Fällt er aus, liefert keine einen gültigen Sollwert und der Failsafe hält die Heizung aus - die sichere Richtung, aber bewusst so entschieden.
* **Einmal pro Woche steht die angezeigte Temperatur rund 17 Minuten still**, solange der SHT-Wartungszyklus läuft und nachwirkt. Für Feuchte und Taupunkt war das schon vorher so.

## [3.1.0] - 2026-09-05

Der Taupunkt nimmt Temperatur und Feuchte aus demselben Chip.

### Geändert

* **Die Taupunktrechnung verwendet die Temperatur des SHT31 statt die des AM2315.** Die Feuchte kam schon immer von dort; sie wird damit bei ihrer eigenen Messtemperatur ausgewertet. Keine Entität kommt hinzu oder fällt weg, kein Name und keine Entity-ID ändert sich - `sensor.dew_point_shed` behält seinen Verlauf.

### Warum

`1.7 Temperature Delta SHT31 - AM2315` hat seit V2.2.0 gemessen, was die gemischte Rechnung kostet. Ausgewertet über 169 Stunden (29.08.-05.09.2026, sechs vollständige Tagesgänge mit 10.6 bis 14.4 K Hub):

* Die Differenz zerfällt in einen **konstanten Versatz von +0.19 K** und einen **Nachlauf von rund 3 Minuten**. Der Nachlauf zeigt sich als Abhängigkeit von der Temperaturrampe (−0.046 K je K/h) und machte über die beobachtete Spanne von −2.6 bis +3.7 K/h **0.34 K** aus. Ein Tages- oder Strahlungsterm ist mit −0.04 K nicht nachweisbar.
* **Der SHT31 ist der trägere der beiden Fühler** - entgegen der Erwartung aus dem mechanischen Aufbau. Seine Metallhülse mit Sinterkappe hat mehr Wärmekapazität als das grössere Kunststoffgehäuse des AM2315.
* Ein Temperaturversatz geht zu **95 %** in den Taupunkt. Die Umstellung verschiebt ihn im Mittel um **+0.17 K**, äusserstenfalls um **+0.51 K**. Als Feuchtefehler ausgedrückt, den die gemischte Rechnung machte: im Mittel 0.75 %RH, Extremwert 2.0 %RH - bei einer Herstellergenauigkeit von ±2 %RH.

Die Umstellung entfernt den Nachlauf vollständig. **Der konstante Versatz bleibt** und wird nur gegen den Offset des anderen Exemplars getauscht; ohne Referenzfühler ist er nicht auflösbar. Für die Heizungsregelung sind beide Beträge klein - 0.17 K auf 3.0 K Überhöhung.

Die angezeigte `Temperature Shed` kommt weiterhin vom AM2315. Ein Wechsel wäre nach Datenblatt begründbar (±0.2 K gegen max. ±1 K, Drift 0.03 gegen 0.1 K/Jahr), kostet aber den Verlauf der Entität in Home Assistant und ist deshalb ein eigener Schritt. Bestückt bleibt der AM2315 in jedem Fall: `1.7` ist die einzige Kreuzprüfung, mit der eine driftende oder abgehängte Messung überhaupt auffiele.

## [3.0.0] - 2026-08-31

Die Flankenerkennung aus V2.1.0 ist wieder entfernt.

### Achtung beim Update

**Zwei Entitäten verschwinden:** `Rain Slope Threshold [Hz⁄min]` und `1.6 Weather Station Frequency Slope`. Die ESPHome-Integration räumt sie samt Verlauf selbst aus der Registry. Auf beide greift in Home Assistant nichts zu - weder Automation, Skript, Szene, Helper noch Dashboard.

**Die Nummer 1.6 bleibt frei.** Ein Nachrücken von `1.7` würde deren Entity-ID und damit den laufenden Verlauf der Temperatur-Delta-Beobachtung kosten.

### Entfernt

* **Die Flankenerkennung über die Frequenzsteigung**, samt Ringpuffer, Regler und Diagnosesensor. `Regen kürzlich` schaltet wieder allein über die Absolutmessung ein, und die Haltezeit zählt ab der letzten Nässe. `Regen Shed` ist unverändert.

### Warum

Am 30.08.2026 löste die Flanke zweimal ohne Regen aus, 06:21-07:07 und 23:59-00:59, belegt gegen Wetterradar und Frequenzverlauf. Die Auswertung ergab:

* Das Rauschen der Steigung liegt im Trockenen bei **σ = 338 Hz/min** (111 Minutenwerte). Die Schwelle −1000 lag damit bei **3.0 σ** - nicht bei den 4.3 σ der Auslegung vom 23.08.2026, die an einem anderen, ruhigeren Schätzer aus 60-s-Werten der HA-Historie ermittelt worden waren (σ = 234). Die Auslegungsreserve ist in der Implementierung verlorengegangen.
* Gemessene Fehlalarmrate: **zwei in 41 trockenen Stunden**, je 45-60 Minuten «Regen kürzlich».
* Höher legen geht nicht: ab **−2408 Hz/min** (0.926 × Trockenfrequenz) verlangt die Flanke binnen einer Minute mehr Abfall, als die Absolutschwelle insgesamt braucht - sie käme damit nie zuerst. Zwischen 5 σ (≈ −1690) und dieser Grenze liegt ein Faktor 1.4.
* Zum Vergleich das echte Ereignis vom 31.08.2026, 02:57 Uhr: die Steigung erreichte **−9007 Hz/min**, das 27-fache von σ. Dieselbe Nacht zeigte erstmals auch den vollständigen Nass-Pfad: «Regen Shed» ein 02:57:25, aus 03:31:05, «Regen kürzlich» aus 04:13:05 - exakt 45 min nach der letzten Nässe.

Die Fähigkeit selbst ist damit nicht widerlegt, nur der Weg dorthin: eine Benetzung senkt den Pegel und **hält** ihn dort, die Steigung sieht dasselbe Signal nur eine Minute lang und ist als Differenz zweier Mittel um √2 lauter. Ein Test auf den geglätteten Pegel läge bei rund 6 σ; gebaut ist er nicht, die offene Zahl dazu steht in README Abschnitt 2.

## [2.2.1] - 2026-08-29

### Geändert

* **Der Schrägstrich im Namen von `Rain Slope Threshold [Hz/min]` ist durch den Bruchstrich U+2044 ersetzt.** ESPHome nimmt diese Ersetzung seit jeher selbst vor, weil der Schrägstrich als Pfadtrenner reserviert ist, und warnt seit 2026.8.1 darüber; ab **ESPHome 2027.7.0 wird daraus ein Fehler**. In Home Assistant stand der Bruchstrich damit ohnehin schon - der angezeigte Name, die Entity-ID und der gespeicherte Reglerwert bleiben deshalb unverändert, und der Verlauf der Entität bleibt erhalten. Die Änderung macht nur explizit, was vorher stillschweigend geschah.

Keine funktionale Änderung.

## [2.2.0] - 2026-08-29

Die Feuchtemessung ist gegen das SHT3x-Datenblatt und die Sensirion Application Notes durchgesehen worden.

### Achtung beim Update

**`1.3 SHT Defog Status` und `1.4 SHT Defog Cycle Active` heissen neu `1.3 SHT Wartungsstatus` und `1.4 SHT Wartungszyklus aktiv`.** Die ESPHome-Integration legt sie damit als neue Entitäten an; die bisherigen verschwinden samt Verlauf und die Entity-IDs ändern sich. Vor der Umbenennung wurde geprüft, dass weder Automation, Skript, Szene, Helper noch Dashboard auf sie zugreift.

**Der SHT31-Heizzyklus wird nicht mehr von der Luftfeuchte ausgelöst, sondern läuft nach Zeitplan.** Sensirion nennt für diesen Heizer zwei Zwecke: Plausibilitätsprüfung (Datenblatt 4.10) und das Rückgängigmachen kontaminationsbedingter Drift (Handling Instructions 3). Kondensat gehört nicht dazu, und das Kriechen oberhalb 80 %RH bildet sich im Normalbereich von selbst zurück (Datenblatt 1.1, bis +3 %RH nach 60 h). Die Schwelle von 98 % löste in 31 Tagen genau einen Zyklus aus, und dieser korrigierte nichts.

### Hinzugefügt

* **`SHT Maintenance Interval [d]`** (Default 7, 0 = aus) steuert den Zyklus. Bei Regen wartet er, weil der Heizungssollwert über den Taupunkt an der Feuchte hängt.
* **`Temperature SHT31`** - die bisher ungenutzte Temperatur des Feuchtesensors, mit derselben Sperre während des Zyklus wie die Feuchte.
* **`1.7 Temperature Delta SHT31 - AM2315`** (K, Diagnose, 60-s-Takt). Beide dienen einer Beobachtung: Die Taupunktrechnung mischt Temperatur und Feuchte zweier Sensoren, was nur zulässig ist, solange beide dieselbe Temperatur haben. Da der Taupunkt der Sollwert der Sensorheizung ist, wirkt ein Versatz bis in die Regelung.

### Geändert

* **Taupunkt mit den Magnus-Konstanten des Sensorherstellers** (17.62 und 243.12 statt 17.67 und 243.5). Der Unterschied beträgt am Betriebspunkt rund 0.01 K; die Konstanten sind aber die Referenz, gegen die das Datenblatt geschrieben ist.
* **Feuchte wird vor der Rechnung geklemmt**, wie in jedem Sensirion-Beispielcode. Bei 0 % wäre der Logarithmus nicht definiert, über 100 % ergäbe sich ein Taupunkt über der Lufttemperatur und damit ein zu hoher Heizungssollwert.
* **`SHT Recovery Time` startet neu bei 12 min statt 3.** Gemessen am Zyklus vom 22.08.2026 klingt der Heizeffekt mit einer Zeitkonstante von rund 4.5 min ab; bei 3 min lag der erste wieder publizierte Wert gut 1 %RH zu tief, bei 12 min bleiben rund 0.1 %RH. Ein bereits eingestellter Wert bleibt erhalten.
* **Der Status** meldet `Heizt (Wartungszyklus)` statt `Heizt (Kondensationsschutz)`. Auch die internen IDs im Code sprechen nicht mehr von «Defog».

Keine Änderung an der Heizungsregelung oder der Regenerkennung.

## [2.1.0] - 2026-08-29

### Hinzugefügt

* **Flankenerkennung.** Erkannt wird eine Benetzung neu auch am Tempo des Frequenzabfalls, nicht nur am erreichten Pegel. Damit erfasst die Station die Benetzungen, die die Absolutschwelle gar nicht erreicht - in einer Messreihe eines Regenmorgens ein gutes Dutzend, die erste rund eine halbe Stunde vor der Absolutmeldung. Schwelle: **Rain Slope Threshold [Hz/min]** (Default −1000, 0 schaltet ab).
* **`1.6 Weather Station Frequency Slope`** (Hz/min, Diagnose, 60-s-Takt) - die Grösse, gegen die diese Schwelle prüft; zum Beobachten vor dem Nachjustieren.

### Geändert

* **`Regen kürzlich`** geht nun auch bei einer erkannten Benetzung an, die Haltezeit läuft ab dem jeweils späteren Ereignis. **`Regen Shed` bleibt unverändert** die reine Absolutmessung - die Flanke meldet ein Ereignis, keinen Zustand, und soll das schnelle Signal nicht zerhacken.

Getestet mit ESPHome 2026.7.4 (RAM 28.5 %, Flash 54.6 %), per OTA geflasht. Die Flanke selbst ist noch nicht an echtem Regen belegt - der Trockenfall verhält sich wie erwartet.

## [2.0.0] - 2026-08-29

### Achtung beim Update

**Trigger point Rain** und **Rain trigger hysteresis** entfallen. Die ESPHome-Integration entfernt sie beim ersten Reconnect selbst aus der Entitätenregistry, von Hand ist nichts aufzuräumen. Die neuen Regler starten so, dass das Erkennungsverhalten unverändert bleibt - keine Nachjustierung nötig. Automatisierungen und Dashboards, die die alten Entitäten ansprechen, müssen dagegen auf `Rain Threshold Wet` bzw. `Rain Threshold Dry` umgestellt werden.

### Hinzugefügt

* **`Regen kürzlich`** (`device_class: moisture`) neben `Regen Shed`, mit der neuen Haltezeit **Rain Hold Time** (Default 45 min). `Regen Shed` beantwortet «ist der Sensor jetzt nass?», `Regen kürzlich` «hat es in den letzten Minuten geregnet?». Grund: Der beheizte Sensor trocknet zwischen zwei Schauern in Minuten ab, ein Regenereignis zerfällt dadurch in mehrere Meldungen. An zwei Regentagen nachgemessen und mit Schwellen oder einem längeren *Rain Off Delay* nicht behebbar.

### Geändert

* **`Trigger point Rain` und `Rain trigger hysteresis` ersetzt durch `Rain Threshold Wet` und `Rain Threshold Dry`** - zwei unabhängige Anteile der Trockenfrequenz. Bisher hing die Ausschaltschwelle über die Hysterese am Einschaltpunkt: Wer empfindlicher stellte, schob sie mit nach oben, bis sie über der Trockenfrequenz lag und das Gerät nie mehr auf «trocken» zurückgekommen wäre. Diese Kopplung hat die Empfindlichkeit blockiert. Nebeneffekt: Auch die Ausschaltschwelle folgt nun dem Temperaturgang, der die Trockenfrequenz über den Tag verschiebt.
* **Startwerte 0.926 und 0.954** bilden die bewährte Einstellung 0.94/0.03 nach; die Abweichung liegt weit unter dem Rauschen.
* **Mindestabstand der Schwellen** (`wet_band_min`, 0.01). Liegt `Rain Threshold Dry` näher an `Rain Threshold Wet` oder darunter, hebt die Firmware ihn an und warnt im Log - ohne Band gäbe es keine Hysterese mehr.

Keine Änderung an der Heizungsregelung, der Selbstkalibrierung oder den Melderaten. Getestet mit ESPHome 2026.7.4 (RAM 28.4 %, Flash 54.5 %), per OTA geflasht und im Betrieb geprüft.

## [1.1.0] - 2026-08-29

### Hinzugefügt

* **`1.5 Heizung Störung`** (`device_class: problem`) - meldet einen unplausiblen NTC-Wert oder eine Übertemperatur. Ohne diese Entität wäre der neue Failsafe unsichtbar: die Heizung ginge still aus und niemand erführe warum.
* **Übertemperatur-Abschaltung bei 60 °C** (`heater_cutout_temp`). Das Kunststoffteil, in dem der Sensor sitzt, verträgt nicht mehr; die Heizleistung auf dem Keramiksubstrat reicht im Normalfall ohnehin nicht so weit. Wird der Wert dennoch erreicht, stimmt etwas nicht und der Regler bleibt auf `OFF`.

### Behoben

* **Ein defekter NTC liess die Heizung dauerhaft mit voller Leistung laufen.** Der bisherige Failsafe prüfte nur die Sollwertquelle (Taupunkt bzw. Umgebungstemperatur) auf `NaN`, nicht den Istwert. Die Fehlerfälle des Fühlers liefern aber keinen `NaN`, sondern eine plausibel aussehende Zahl: sowohl bei Kurzschluss (über `log(0)`) als auch bei offener Leitung (über den sehr grossen Widerstand) landet die Rechnung bei rund −273 °C - **beide laufen also nach unten**. `PIDClimate::update_pid_()` schaltet nur bei `NaN` ab und bildet sonst aus dem riesigen Regelfehler dauerhaft 100 % Stellwert. Der Istwert wird jetzt gegen `ntc_min_plausible` (−30 °C) geprüft; darunter bleibt der Regler zwingend auf `OFF`.
* **Nach einem Neustart entfiel die Wartezeit vor der Selbstkalibrierung.** `time_since_dry` startete mit `0`, wodurch `millis() - time_since_dry` sofort grösser war als jeder eingestellte *Calibration delay*. Ein Reboot kurz nach dem Regen konnte den Sensor damit auf eine noch feuchte Frequenz kalibrieren lassen. Der Wert wird jetzt in `on_boot` auf `millis()` gesetzt.
* **Der Kalibrierstatus flatterte beim Aufheizen.** Die Bedingung «Sensor ist warm» verglich den auf 60 s gemittelten HA-Wert (`Weather Station Sensor Heater`) gegen einen frischen Sollwert. Ein einzelner Minutenmittelwert kippte die Aussage, worauf der Status für genau einen Schleifendurchlauf auf `Heizt auf` sprang - am 14. und 16.08.2026 mehrfach für je 10 s beobachtet. Verglichen wird jetzt der schnelle interne Istwert (2 s). Verschärft wurde das durch eine niedrig eingestellte *Heater Temperature Elevation*: bei 3 K Überhöhung liegt das 2-K-Band knapp unter dem Sollwert.
* **Ehrlicher Status statt `Heizt auf`,** wenn Soll- oder Istwert fehlen. Bisher fiel die Anzeige in beiden Fällen auf `Heizt auf` zurück, obwohl die Heizung zwangsweise **aus** war - `target_temp` ist dann `NaN` und jeder Vergleich dagegen falsch. Neu: `NTC unplausibel - Heizung aus`, `Übertemperatur - Heizung aus` und `Sensordaten fehlen - Heizung aus`.
* **Grenzwert `rain_stop` einheitlich.** Die Nässe-Erkennung verwendete `<`, die Statusermittlung `<=`; bei exakt `f == rain_stop` meldeten Logik und Status Verschiedenes.

### Geändert

* **Startwerte der Regenschwellen auf `Trigger point Rain: 0.94` und `Rain trigger hysteresis: 0.03`** (vorher 0.80 / 0.12). Die alte Kombination verlangte einen Frequenzeinbruch von 15.4 %, bevor Regen gemeldet wurde, und liess sich nicht entschärfen: `rain_stop` hängt am Trigger point, nicht an der Trockenfrequenz, und wandert ab Trigger point ≈ 0.94 bei Hysterese 0.12 **über** die Trockenfrequenz - das Gerät käme nie mehr auf «trocken» zurück. Die neuen Startwerte laufen seit dem 23.08.2026 im Betrieb: Einschaltschwelle bei 92.6 % statt 84.6 % der Trockenfrequenz, an zwei Regentagen (25. und 28.08.) ohne Fehlalarm, mit rund einer halben Stunde früherer Meldung beim Regenbeginn am 25.08. Die Werte lagen bisher nur im NVS; ein Neuaufbau hätte wieder in der Sackgasse begonnen.

* **Obergrenze von `Heater Max Temperature` von 100 auf 50 °C gesenkt.** Der einstellbare Sollwert muss unter der Übertemperatur-Abschaltung liegen, sonst löste ein regulär eingestellter Wert von z. B. 80 °C die Schutzabschaltung aus und würde als Störung gemeldet. 50 °C lässt 10 K Reserve und war ohnehin der Vorgabewert; für einen Sensor, der nur wenige Kelvin über dem Taupunkt gehalten wird, ist das reichlich.

Keine Änderung an Regelverhalten im Normalbetrieb, an der Hysteresemechanik oder an den Melderaten. Getestet mit ESPHome 2026.7.4 (`config` und `compile` fehlerfrei, RAM 28.3 %, Flash 54.5 %).

## [1.0.1] - 2026-07-28

### Geändert

* **Datenrate gegenüber Home Assistant um rund 90 % gesenkt.** Am laufenden Gerät gemessen: 224 der 236 wiederkehrenden Meldungen in 30 s (96 %) stammten von der Climate-Entität - hochgerechnet rund 645'000 Meldungen pro Tag, die in HA jeweils eine neue `states`- plus `state_attributes`-Zeile erzeugten, weil `current_temperature` als Attribut ständig wechselt.
  * `heater_temp_fast` publiziert über `sliding_window_moving_average` (Fenster 20, `send_every: 20`) nur noch alle 2 s statt 10-mal pro Sekunde. Da `PIDClimate` an diesem Sensor-Callback hängt, senkt das zugleich Rechen- und Meldungsrate des Reglers. Der ADC tastet unverändert mit 10 Hz ab, die Mittelung wird dadurch sogar besser.
  * Der PID-Regler wird von der Hauptschleife nur noch angefasst, wenn der Modus wechselt oder sich der Sollwert um ≥ 0.1 K ändert - vorher bei jedem 10-s-Durchlauf.
  * `Weather Station Frequency` und `Weather Station Sensor Heater` mitteln jetzt über 60 s statt 10 s, `1.0 Weather Station Dry Frequency` meldet alle 300 s statt 60 s.
  * Kalibrierstatus und -Flag werden nur noch bei Wertänderung publiziert (vorher alle 10 s identisch).
  * `Regen Shed` und `1.4 SHT Defog Cycle Active` sind von zyklischem Polling auf ereignisgesteuertes Publizieren umgestellt.
* **Reaktionszeit der Regenerkennung in HA verbessert:** von bis zu 60 s (Polling-Intervall des Binärsensors) auf maximal 10 s (Flanke wird direkt aus der Logikschleife gemeldet).
* **Flash-Verschleiss reduziert:** `flash_write_interval` von 1 min auf 10 min. Zusammen mit dem selteneren PID-Aufruf entfallen die bisherigen rund 525'000 NVS-Schreibvorgänge pro Jahr weitgehend.
* **`state_class: measurement`** ergänzt bei Luftfeuchte, Luftdruck, Taupunkt, beiden Frequenz-Sensoren und der Heizungstemperatur. Home Assistant führt für diese Werte damit Langzeitstatistik.

### Behoben

* Driftberechnung der Kalibrierung nutzt `fabsf()` statt `abs()`. Das bisherige Verhalten war korrekt (der Compiler löste nachweislich auf die Fliesskomma-Variante auf), hing aber an Header-Details.

Keine Änderung an Regelverhalten, Schwellenlogik oder Bedienung. Getestet mit ESPHome 2026.7.2 (`config` und `compile` fehlerfrei, RAM 27.9 %, Flash 54.4 %).

> **Nachtrag vom 2026-07-29 — nach 24 Stunden im Betrieb nachgemessen:**
>
> | Entität | vorher/Tag | jetzt/Tag |
> | :--- | ---: | ---: |
> | `climate` Rain Sensor Heater PID | ~645'000 | **0** (zusätzlich im `recorder` ausgeschlossen) |
> | `Weather Station Sensor Heater` | ~8'640 | **1'442** |
> | `Weather Station Frequency` | ~8'640 | **1'442** |
> | `1.0 Dry Frequency` | 1'440 | **288** |
>
> Zur Einordnung, welche Massnahmen tatsächlich Datenbankzeilen gespart haben: Die drei Punkte zur Melderate (`heater_temp_fast`, PID-Aufruf, 60-s-Mittelung) wirken voll, weil sich diese Werte bei jeder Meldung real ändern. Die Entprellung von **Kalibrierstatus, Regensensor und Defog-Flag** senkt dagegen nur Netzwerk- und Event-Bus-Last: Home Assistant verwirft identische Wiederholungen ohnehin, ohne eine Zeile zu schreiben. Die ursprüngliche Formulierung in Abschnitt 7 der README legte das Gegenteil nahe und ist korrigiert.
>
> Funktional bestätigt: Die Selbstkalibrierung arbeitet, der Status steht auf `Kalibriert` und die gelernte Trockenfrequenz ist im ersten Tag von 33'165 auf 32'587 Hz eingelaufen.

## [1.0.0] - 2026-07-28

### Erstrelease

* **Messwerte:** Temperatur (AM2315 über die `am2320`-Plattform), Luftfeuchte (SHT31, `0x44`), Luftdruck (BMP280, `0x76`, mit einstellbarer Höhenkorrektur) und daraus berechneter Taupunkt (Magnus-Formel) auf einem gemeinsamen I²C-Bus (GPIO21/GPIO22).
* **Regenerkennung (GPIO32):** Frequenzbasierter Sensor über `pulse_counter` (1 s Fenster, 2 µs Glitch-Filter, exponentielle Glättung). Auslösung relativ zur gelernten Trockenfrequenz mit Hysterese - Regen schaltet sofort EIN, das Zurücksetzen auf «trocken» erfordert eine durchgehende Trockenphase (Default 3 min).
* **Selbstkalibrierung der Trockenfrequenz:** Gleitender Mittelwert (1/16-Gewichtung), der nur bei trockenem und aufgeheiztem Sensor, nach abgelaufener Wartezeit (Default 30 min) und innerhalb eines engen Driftfensters (Default 4 %) nachgeführt wird. Der jeweils blockierende Grund wird im Klartext als Diagnose-Entität publiziert.
* **PID-geregelte Sensorheizung (GPIO27):** Nativer ESPHome-PID-Regler (kp 0.157, ki 0.040, kd 0.039) auf LEDC-PWM mit 2 kHz. Sollwert wahlweise über Taupunkt oder Umgebungstemperatur plus Überhöhung, geklemmt zwischen Min- und Max-Temperatur. Failsafe: Bei ungültigen Sensorwerten (`NaN`) wird der Regler zwingend auf `OFF` gesetzt.
* **Temperaturmessung der Heizung (GPIO36):** Vierstufige NTC-Kette aus ADC → `resistance` (680 Ω) → `ntc` (B = 3750, 1 kΩ @ 25 °C) → Glättung. Schneller interner Wert (100 ms) für den Regler, 10-s-Mittelwert für Home Assistant.
* **Anti-Kondensations-Zyklus für den SHT31:** Ab 98 % Luftfeuchte wird der interne Sensorheizer per I²C-Kommando für eine einstellbare Zeit aktiviert; während Heiz- und Abkühlphase werden die Feuchtewerte verworfen, damit keine verfälschten Werte nach Home Assistant gelangen.
* **Status-LEDs:** RGB-LED (GPIO16/17/18) mit grün = API verbunden, blau = nur WLAN, rot = kein WLAN; separate Activity-LED (GPIO15), die den Durchlauf der Hauptlogik im 10-s-Takt anzeigt.
* **Bedienung:** Zwölf in Home Assistant einstellbare Konfigurationswerte (Heizungsquelle, Sollwertgrenzen, Regenschwellen, Kalibrierparameter, Defog-Zeiten, Luftdruckkorrektur), alle neustartfest; Webserver auf Port 80 für den Betrieb ohne HA.
* Gemeinsames Diagnose-Paket `common/diagnostics.yaml` (V1.2.1) eingebunden.
* Zugangsdaten (API-Key, OTA-Passwort, Fallback-AP) über `!secret` ausgelagert.

Getestet mit ESPHome 2026.7.2 (`esphome config` und `esphome compile` fehlerfrei, RAM 27.9 %, Flash 54.3 %).
