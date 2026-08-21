# Hardware — ha-smartrelais

Eigene Leiterplatte mit Netzteil, Solid-State-Relais und XIAO-ESP32-C6-Sockel,
**230 V führend**. Betriebssicher nur mit den drei Änderungen aus Abschnitt 5.

GPIO-Zuordnung und Steckerbelegung stehen in Abschnitt 3 der
[README](README.md). Hier stehen Netzteil, Lastkreis, die Eingriffe an der
Platine und der Revisionsstand.

---

## Haftungsausschluss

⚠️ **VERWENDUNG AUF EIGENE GEFAHR** ⚠️

Diese Leiterplatte ist ein privates Bastelprojekt. Sie ist **nicht zertifiziert
und nicht geprüft** — weder nach einer Gerätenorm noch auf elektrische
Sicherheit. Rev 1.0 ist zudem **nachweislich fehlerhaft** und läuft nur mit den
Änderungen aus Abschnitt 5; Rev 2.0 wurde nie gefertigt und nie gemessen.

Sie führt **230 V Netzspannung**. Arbeiten daran sind lebensgefährlich und
gehören in die Hand einer **zertifizierten Elektrofachkraft**. Nachbau, Umbau
und Betrieb erfolgen auf eigene Gefahr und eigenes Risiko.

Der Autor übernimmt **keine Haftung, Gewährleistung oder Verantwortung** — weder
für Schäden an Last, Elektroinstallation oder Haustechnik, noch für
Folgeschäden aus Fehlfunktionen, noch für elektrische Unfälle oder
Verletzungen, noch für Richtigkeit und Vollständigkeit dieser Dokumentation.

Vollständiger Wortlaut in der [README](README.md#haftungsausschluss-disclaimer).

---

## 1. Revisionsstand

| Revision | Zustand |
| :--- | :--- |
| **Rev 1.0** | Gefertigt im Frühjahr 2026 bei [JLCPCB](https://jlcpcb.com/), im Einsatz. **Nur mit dem Rework aus Abschnitt 5 betriebssicher**; das Board im Einsatz ist vollständig umgebaut. |
| **Rev 2.0** | Schaltplan und Layout fertig, nie produziert. Kein Exemplar, keine Messung. **Nicht verifiziert.** |

Beide: 50.8 × 50.8 mm, Revision im Siebdruck der Unterseite, gefräster
Trennschlitz zwischen Netzteil und Kleinspannungsseite.

> [!WARNING]
> `pcb/rev1.0/schaltplan.png` und `bom.csv` zeigen Rev 1.0 **vor** dem Rework.
> Wer danach aufbaut und Abschnitt 5 weglässt, riskiert, dass das SSR beim
> Einschalten einer Last mit hohem Anlaufstrom **dauerhaft leitend wird**: Die
> Last lässt sich dann weder über den Wandschalter noch über Home Assistant
> abschalten, und das SSR kann dabei zerstört werden.

Fertigungs- und Quelldaten: [`pcb/`](pcb/).

---

## 2. Netzanschluss und Speisung

Klemmenblock `J1`, abgesichert mit einer Feinsicherung 1 A träge (5×20 mm) in
den Halteklammern `F1`/`F2`, Varistor `R1` (275 V). Kleinspannung aus `U2` (**IRM-01-5**, 1 W, 5 V) mit `C1`/`C2`;
Testpunkte `TP1`/`TP2` auf 5 V und GND. Das XIAO wird über 5 V gespeist und
erzeugt die 3.3 V selbst.

| `J1` | Netz | Führt zu |
| :---: | :--- | :--- |
| 1 | **L** | `F1`/`F2` → `R1`, `U2` AC/L, `U3` Pin 6 **und** Pin 5 |
| 2 | **N** | `R1`, `U2` AC/N, `R2` (oberes Pad) |
| 3 | **Lastausgang** | `U3` Pin 8, `C3` |

Die Belegung steht im Siebdruck der Unterseite: `L`, `N`, `OUT`.

---

## 3. Lastkreis

`U3` = **AQH3213A**, PhotoTRIAC-SSR mit Nulldurchgangserkennung. Steuerseite
(Pins 1–4) galvanisch von der Lastseite (Pins 5–8) getrennt.

| Pin | Seite | Beschaltung nach Rework |
| :---: | :--- | :--- |
| 2 | Steuer-LED | über `R3` (150 Ω) an `GPIO21` |
| 1, 3, 4 | Steuer-LED | GND |
| 5 | Zero-Cross | **freigebogen, kein Kontakt zur Platine** |
| 6 | Triac | L nach Sicherung |
| 8 | Triac | Lastausgang `J1-3` |

Snubber `R2` (47 Ω) + `C3` (10 n / 275 VAC, X2) parallel zum Triac — **diese
Parallelschaltung stellt erst der Rework her**, siehe 5.3.

---

## 4. Kleinspannungsseite

Stecker `J2`–`J6` und GPIOs: Abschnitt 3 der [README](README.md). `U4`
(DS18B20) sitzt mit `R6` und `C4` am 1-Wire-Bus, thermisch am SSR.

Auch diese Stecker sind im Siebdruck der Unterseite beschriftet:
`REL`/`SDA`/`SCL`/`1W`, `D10`/`D1`/`D2`, `3.3V`/`GND`, `LED+`/`LED−`. Nachsehen
in `pcb/rev1.0/layout-bottom.pdf` statt Gehäuse öffnen.

---

## 5. Die drei Modifikationen an Rev 1.0

Drei Layoutfehler. Bei Lasten mit hohem Anlaufstrom — typisch: LED-Leuchtmittel
— kann das SSR dadurch dauerhaft leitend bleiben und die Last nicht mehr
abschalten (Thermal Latch-up), oder es wird zerstört. An jedem Exemplar
auszuführen.

**Material:** Lötkolben, Skalpell oder feiner Seitenschneider, isolierte
Schaltlitze für 230 V AC, Widerstand 150 Ω in Bauform `R3`, Multimeter.

### 5.1 Steuerstrom — `R3` auf 150 Ω

Das SSR braucht 10–15 mA; der Schaltplanwert 220 Ω liefert bei 3.3 V zu wenig.
`R3` mit **150 Ω** bestücken → rund 14 mA.

### 5.2 Zero-Cross isolieren — Pin 5 freibiegen

Das Layout legt Pin 5 in den Laststromkreis und übersteuert damit die interne
Logik.

**Vor dem Einlöten von `U3`:** Pin 5 um 90 Grad nach aussen biegen, dann die
übrigen sieben Pins verlöten. Pin 5 darf weder Pad noch Lötzinn berühren.

### 5.3 Snubber — `R2` umhängen

Das RC-Glied liegt parallel zur Einspeisung statt parallel zum Triac und ist so
wirkungslos.

1. Leiterbahn vom **oberen Pad `R2`** zu `J1-2` (N) auf der Oberseite
   durchtrennen, Kupfer vollständig wegkratzen.
2. Schaltlitze an dieses obere Pad von `R2` löten.
3. Anderes Ende direkt an **Pin 6** des SSR.

---

## 6. Abschlussprüfung

**Vor dem ersten Anlegen der Netzspannung**, Durchgangsprüfer:

| Prüfung | Erwartung |
| :--- | :--- |
| Wert an `R3` | rund 150 Ω |
| Pin 5 gegen sein Lötpad | **kein** Durchgang |
| Oberes Pad `R2` gegen `J1-2` (N) | **kein** Durchgang |
| Oberes Pad `R2` gegen Pin 6 | Durchgang (Litze) |
| Unteres Pad `C3` gegen Pin 8 | Durchgang (bestehendes Layout) |

---

## 7. Elektrische Besonderheiten

**230 V** auf `J1`, `F1`, `R1`, `R2`, `C3`, der Lastseite von `U3` und der
Primärseite von `U2`.

**Steuerstrom.** Mit `R3` = 150 Ω an 3.3 V fliessen rund 14 mA aus `GPIO21`.

**`C3` nur gegen einen X2-Typ tauschen**, nie gegen einen gewöhnlichen
Folienkondensator.

---

## 8. Abgleich mit der Firmware

| Signal | GPIO | Besonderheit |
| :--- | :---: | :--- |
| SSR | `GPIO21` | über `R3` (150 Ω) an Pin 2 von `U3`, aktiv HIGH |
| Wandschalter | `GPIO18` | interner Pull-up, invertiert, 50 ms entprellt |
| DS18B20 | `GPIO16` | 1-Wire, `address: 0` als Wildcard — nur ein Sensor am Bus |
| Status-LED | `GPIO0` | über `R7` (220 Ω) gegen +3.3 V, aktiv LOW |
| RF-Switch | `GPIO3` | `on_boot`, Priorität 800 |
| Antennenwahl | `GPIO14` | LOW = interne Keramikantenne |

---

## 9. Rev 2.0

Behebt die drei Fehler im Entwurf und baut zusätzlich die SSR-Ansteuerung um.

| | Rev 1.0 (mit Rework) | Rev 2.0 |
| :--- | :--- | :--- |
| Speisung Steuer-LED | `GPIO21` → `R3` 150 Ω → Pin 2 | **+5 V** → `R3` **180 Ω** → Pin 2 |
| Gegenseite | Pin 1, 3, 4 auf GND | Pin 3 → Drain `Q3`; Pin 1 und 4 unbeschaltet |
| Schaltelement | keines, GPIO treibt direkt | **`Q3` SI2302DS**, Gate an REL, `R8` 10 K Pulldown |
| Pin 5 | von Hand freigebogen | im Entwurf nicht angeschlossen |
| Snubber | von Hand auf Pin 6 umgehängt | Pin 6 ↔ Pin 8 im Layout |
| Bestückung | nur Oberseite | zusätzlich `Q3`, `R8` **auf der Unterseite** |

Boardmass, Lochbild und `J1` bleiben gleich. Der ESP32 trägt den LED-Strom nicht
mehr, und `R8` hält das SSR aus, solange `GPIO21` beim Boot hochohmig ist. **Die
Firmware bleibt unverändert**, REL ist weiterhin aktiv HIGH.

Vor einer Fertigung zu prüfen:

* LED-Strom gegen das Datenblatt — 180 Ω an 5 V ergibt rund 21 mA statt 14 mA.
* Schaltet der SI2302DS bei 3.3 V Gate-Pegel sicher durch?
* Trennabstände und Kriechstrecken um die neu bestückte Unterseite.
* Bestückung beidseitig einplanen.
* Erstmuster an ohmscher Last, danach an LED-Last.

---

## 10. Fotos

Von der umgebauten Platine und vom Gehäuse gibt es keine Aufnahmen. Wer
nachbaut, ergänzt sie selbst.
