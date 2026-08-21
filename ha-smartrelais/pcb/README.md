# Platinendaten — ha-smartrelais

Exporte aus EasyEDA, je Revision ein Ordner. Das Projekt dort ist kontogebunden
und deshalb nicht verlinkt — massgeblich sind diese Dateien.

Zum Zustand der Revisionen siehe [HARDWARE.md](../HARDWARE.md).

| Datei | Inhalt |
| :--- | :--- |
| `schaltplan.png` | Schaltplan (PDF-Export von EasyEDA war fehlerhaft) |
| `layout-top.pdf` | Oberseite mit Bemassung |
| `layout-bottom.pdf` | Unterseite mit Siebdruck |
| `bom.csv` | Stückliste |
| `gerber.zip` | Fertigungsdaten wie an JLCPCB übergeben |
| `easyeda-schaltplan.json` | Quellexport Schaltplan |
| `easyeda-layout.json` | Quellexport Layout |

Beide Revisionen sind vollständig.

**`rev1.0/bom.csv` bildet den Stand vor dem Rework ab** und führt `R3` mit
220 Ω; die Spalte `Hinweis` nennt den tatsächlichen Wert 150 Ω. `R7` teilt sich
die Zeile und bleibt bei 220 Ω.

Die JSON-Quellen öffnet man über *Datei → Öffnen → EasyEDA*.
