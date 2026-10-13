# Messung Datenbank — spalten-244-retest

- Rechner: Mac16,12, Apple M4, 24 GB RAM
- macOS: Version 15.7.3 (Build 24G419)
- Übersetzung: Debug mit `-O` (Release-Tests bauen nicht, Debug-Testhilfen)
- Laufzeit gesamt: 20228 s

## Hinweise

- Freier Platz zu Beginn von S1: 139.366 GB
- Freier Platz zu Beginn von S2: 138.484 GB
- Freier Platz zu Beginn von S1: 139.738 GB
- Freier Platz zu Beginn von S2: 139.060 GB
- Freier Platz zu Beginn von S1: 136.567 GB
- Freier Platz zu Beginn von S2: 135.441 GB

## S1

### Schreiben

| Messpunkt | Median (ms) | Läufe (ms) | Wert | Bemerkung |
|---|---:|---|---|---|
| Aufbau 1 Medium | 132921.4 |  | 7523 Einträge/s | 1000000 Einträge, ein Lauf (nicht wiederholbar) |
| nacheinander 2 × 100000 | 33441.0 |  | 5980 Einträge/s gesamt |  |
| gleichzeitig 2 × 100000 | 36698.2 |  | 5449 Einträge/s gesamt | je Medium: 2746 Einträge/s / 2724 Einträge/s |

### Größe

| Messpunkt | Median (ms) | Läufe (ms) | Wert | Bemerkung |
|---|---:|---|---|---|
| nach Aufbau: Datenbankdatei |  |  | 0.279 GB |  |
| nach Aufbau: WAL |  |  | 0.000 GB |  |
| nach Aufbau: Bytes der Spalten name und slug |  |  | 0.053 GB | name 28505476, slug 28685547 Bytes |
| nach Aufbau: Seiten |  |  | 73073 × 4096 B | frei: 0 |
| nach Aufbau: Tabellen items + item_details |  |  | 0.097 GB |  |
| nach Aufbau: Indizes auf items |  |  | 0.181 GB | items_children 0.051 GB; items_fileid 0.000 GB; items_identity 0.051 GB; items_modified 0.016 GB; items_parent 0.013 GB; items_search 0.049 GB |
| nach Bereinigung: Datenbankdatei |  |  | 0.279 GB |  |
| nach Bereinigung: WAL |  |  | 0.000 GB |  |
| nach Bereinigung: Bytes der Spalten name und slug |  |  | 0.053 GB | name 28505476, slug 28685547 Bytes |
| nach Bereinigung: Seiten |  |  | 73076 × 4096 B | frei: 0 |
| nach Bereinigung: Tabellen items + item_details |  |  | 0.097 GB |  |
| nach Bereinigung: Indizes auf items |  |  | 0.181 GB | items_children 0.051 GB; items_fileid 0.000 GB; items_identity 0.051 GB; items_modified 0.016 GB; items_parent 0.013 GB; items_search 0.049 GB |

### Öffnen

| Messpunkt | Median (ms) | Läufe (ms) | Wert | Bemerkung |
|---|---:|---|---|---|
| Datenbank öffnen ohne quick_check (nach Neuöffnen, OS-Cache warm) | 0.8 | 11, 1, 1, 364, 1 |  |  |
| quick_check allein | 332.2 | 334, 331, 332, 324, 347 |  | mit quick_check gesamt ≈ 333 ms; 5 Läufe; echter Kaltstart ohne `purge` (Root) nicht möglich |

### Spaltenansicht

| Messpunkt | Median (ms) | Läufe (ms) | Wert | Bemerkung |
|---|---:|---|---|---|
| childCount, 100 Kinder | 0.0 | 0, 0, 0, 0, 0 |  |  |
| erste Seite childrenPage (2000), 100 Kinder | 0.5 | 1, 0, 0, 0, 0 |  |  |
| alle Seiten, 100 Kinder | 0.4 | 0, 0, 0, 1, 0 |  | 1 Seiten |
| childCount, 5000 Kinder | 0.1 | 0, 0, 0, 0, 0 |  |  |
| erste Seite childrenPage (2000), 5000 Kinder | 8.9 | 11, 10, 9, 8, 8 |  |  |
| alle Seiten, 5000 Kinder | 20.3 | 20, 20, 20, 21, 20 |  | 3 Seiten |
| childCount, 50000 Kinder | 0.9 | 1, 1, 1, 1, 1 |  |  |
| erste Seite childrenPage (2000), 50000 Kinder | 8.9 | 10, 9, 8, 9, 13 |  |  |
| alle Seiten, 50000 Kinder | 242.3 | 328, 242, 220, 230, 247 |  | 26 Seiten |

### Suche

| Messpunkt | Median (ms) | Läufe (ms) | Wert | Bemerkung |
|---|---:|---|---|---|
| search (Limit 500) 'bil' (häufig, 3 Zeichen), ohne Filter | 9.0 | 9, 7, 9, 7, 9 |  |  |
| searchCount 'bil' (häufig, 3 Zeichen), ohne Filter | 58.4 | 58, 58, 61, 69, 51 |  | Treffer 100342 |
| search (Limit 500) 'bil' (häufig, 3 Zeichen), Dateityp pdf | 24.7 | 24, 26, 24, 25, 25 |  |  |
| searchCount 'bil' (häufig, 3 Zeichen), Dateityp pdf | 54.4 | 60, 50, 54, 54, 54 |  | Treffer 7455 |
| search (Limit 500) 'bil' (häufig, 3 Zeichen), Alter letzter Monat | 131.2 | 144, 133, 127, 131, 130 |  |  |
| searchCount 'bil' (häufig, 3 Zeichen), Alter letzter Monat | 53.3 | 56, 51, 50, 53, 55 |  | Treffer 821 |
| search (Limit 500) 'bil' (häufig, 3 Zeichen), beide | 22.6 | 22, 23, 23, 22, 23 |  |  |
| searchCount 'bil' (häufig, 3 Zeichen), beide | 59.0 | 71, 104, 51, 53, 59 |  | Treffer 8211 |
| search (Limit 500) 'Quartzit' (selten, 8 Zeichen), ohne Filter | 61.6 | 62, 61, 61, 62, 63 |  |  |
| searchCount 'Quartzit' (selten, 8 Zeichen), ohne Filter | 51.1 | 52, 57, 51, 50, 50 |  | Treffer 18 |
| search (Limit 500) 'Quartzit' (selten, 8 Zeichen), Dateityp pdf | 66.6 | 67, 67, 66, 66, 67 |  |  |
| searchCount 'Quartzit' (selten, 8 Zeichen), Dateityp pdf | 53.8 | 54, 54, 49, 50, 55 |  | Treffer 1 |
| search (Limit 500) 'Quartzit' (selten, 8 Zeichen), Alter letzter Monat | 66.1 | 68, 67, 65, 66, 66 |  |  |
| searchCount 'Quartzit' (selten, 8 Zeichen), Alter letzter Monat | 53.0 | 52, 49, 54, 53, 56 |  | Treffer 1 |
| search (Limit 500) 'Quartzit' (selten, 8 Zeichen), beide | 66.7 | 68, 66, 67, 67, 67 |  |  |
| searchCount 'Quartzit' (selten, 8 Zeichen), beide | 54.0 | 53, 54, 60, 57, 52 |  | Treffer 2 |

### Favoriten

| Messpunkt | Median (ms) | Läufe (ms) | Wert | Bemerkung |
|---|---:|---|---|---|
| 753 Favoriten setzen (10 × 100) | 67.8 |  |  |  |
| favorites() bei 753 Favoriten | 141.8 | 143, 139, 140, 145, 142 |  | geliefert 753 |

### Bereinigen

| Messpunkt | Median (ms) | Läufe (ms) | Wert | Bemerkung |
|---|---:|---|---|---|
| pruneToMatch nach Tiefe 5 → 4 | 600097.2 |  |  | zu entfernen 677415, entfernt 0 (0/s), ABGEBROCHEN nach 10 min; keine Schätzung (nichts entfernt) |

## S2

### Schreiben

| Messpunkt | Median (ms) | Läufe (ms) | Wert | Bemerkung |
|---|---:|---|---|---|
| Aufbau 300 Medien | 2265713.4 |  | 3788 Einträge/s | 8583155 Einträge, ein Lauf |
| nacheinander 2 × 100000 | 46216.1 |  | 4327 Einträge/s gesamt |  |
| gleichzeitig 2 × 100000 | 53920.3 |  | 3709 Einträge/s gesamt | je Medium: 1868 Einträge/s / 1854 Einträge/s |

### Größe

| Messpunkt | Median (ms) | Läufe (ms) | Wert | Bemerkung |
|---|---:|---|---|---|
| nach Aufbau: Datenbankdatei |  |  | 2.442 GB |  |
| nach Aufbau: WAL |  |  | 0.000 GB |  |
| nach Aufbau: Bytes der Spalten name und slug |  |  | 0.485 GB | name 259379943, slug 261022249 Bytes |
| nach Aufbau: Seiten |  |  | 640242 × 4096 B | frei: 0 |
| nach Aufbau: Tabellen items + item_details |  |  | 0.886 GB |  |
| nach Aufbau: Indizes auf items |  |  | 1.553 GB | items_children 0.472 GB; items_fileid 0.000 GB; items_identity 0.470 GB; items_modified 0.118 GB; items_parent 0.120 GB; items_search 0.374 GB |
| nach Bereinigung: Datenbankdatei |  |  | 1.685 GB |  |
| nach Bereinigung: WAL |  |  | 0.000 GB |  |
| nach Bereinigung: Bytes der Spalten name und slug |  |  | 0.297 GB | name 159165930, slug 160173734 Bytes |
| nach Bereinigung: Seiten |  |  | 441611 × 4096 B | frei: 0 |
| nach Bereinigung: Tabellen items + item_details |  |  | 0.550 GB |  |
| nach Bereinigung: Indizes auf items |  |  | 1.133 GB | items_children 0.292 GB; items_fileid 0.000 GB; items_identity 0.291 GB; items_modified 0.115 GB; items_parent 0.074 GB; items_search 0.360 GB |

### Öffnen

| Messpunkt | Median (ms) | Läufe (ms) | Wert | Bemerkung |
|---|---:|---|---|---|
| Datenbank öffnen ohne quick_check (nach Neuöffnen, OS-Cache warm) | 1.5 | 4, 1, 1 |  |  |
| quick_check allein | 65629.3 | 65629, 57850, 76482 |  | mit quick_check gesamt ≈ 65630 ms; 3 Läufe; echter Kaltstart ohne `purge` (Root) nicht möglich |

### Spaltenansicht

| Messpunkt | Median (ms) | Läufe (ms) | Wert | Bemerkung |
|---|---:|---|---|---|
| childCount, 100 Kinder | 0.0 | 0, 0, 0, 0, 0 |  |  |
| erste Seite childrenPage (2000), 100 Kinder | 0.4 | 1, 0, 0, 0, 0 |  |  |
| alle Seiten, 100 Kinder | 0.4 | 0, 0, 0, 0, 0 |  | 1 Seiten |
| childCount, 5000 Kinder | 0.1 | 2, 0, 0, 0, 0 |  |  |
| erste Seite childrenPage (2000), 5000 Kinder | 7.7 | 9, 8, 8, 8, 8 |  |  |
| alle Seiten, 5000 Kinder | 20.3 | 20, 20, 19, 20, 21 |  | 3 Seiten |
| childCount, 50000 Kinder | 0.8 | 28, 1, 1, 1, 1 |  |  |
| erste Seite childrenPage (2000), 50000 Kinder | 8.9 | 25, 9, 9, 8, 9 |  |  |
| alle Seiten, 50000 Kinder | 215.9 | 216, 219, 218, 214, 215 |  | 26 Seiten |

### Suche

| Messpunkt | Median (ms) | Läufe (ms) | Wert | Bemerkung |
|---|---:|---|---|---|
| search (Limit 500) 'bil' (häufig, 3 Zeichen), ohne Filter | 10.3 | 215, 11, 10, 10, 10 |  |  |
| searchCount 'bil' (häufig, 3 Zeichen), ohne Filter | 4415.2 | 5657, 4649, 4415, 4344, 4353 |  | Treffer 877230 |
| search (Limit 500) 'bil' (häufig, 3 Zeichen), Dateityp pdf | 25.2 | 419, 43, 25, 23, 25 |  |  |
| searchCount 'bil' (häufig, 3 Zeichen), Dateityp pdf | 5251.5 | 5315, 5017, 5635, 5251, 5123 |  | Treffer 76251 |
| search (Limit 500) 'bil' (häufig, 3 Zeichen), Alter letzter Monat | 7397.2 | 9493, 8735, 7397, 7373, 7320 |  |  |
| searchCount 'bil' (häufig, 3 Zeichen), Alter letzter Monat | 5182.1 | 6290, 5345, 4701, 4956, 5182 |  | Treffer 6574 |
| search (Limit 500) 'bil' (häufig, 3 Zeichen), beide | 24.4 | 469, 37, 23, 24, 22 |  |  |
| searchCount 'bil' (häufig, 3 Zeichen), beide | 5315.0 | 5318, 5315, 5083, 5256, 5442 |  | Treffer 82259 |
| search (Limit 500) 'Quartzit' (selten, 8 Zeichen), ohne Filter | 11574.5 | 10608, 12583, 11640, 11574, 10009 |  |  |
| searchCount 'Quartzit' (selten, 8 Zeichen), ohne Filter | 5979.7 | 7857, 5848, 5632, 5980, 6653 |  | Treffer 155 |
| search (Limit 500) 'Quartzit' (selten, 8 Zeichen), Dateityp pdf | 10105.5 | 9962, 10305, 10106, 9463, 10166 |  |  |
| searchCount 'Quartzit' (selten, 8 Zeichen), Dateityp pdf | 6325.2 | 6256, 6704, 5862, 6703, 6325 |  | Treffer 28 |
| search (Limit 500) 'Quartzit' (selten, 8 Zeichen), Alter letzter Monat | 16228.3 | 13715, 16228, 17985, 14835, 24351 |  |  |
| searchCount 'Quartzit' (selten, 8 Zeichen), Alter letzter Monat | 5263.6 | 27776, 4918, 5240, 9373, 5264 |  | Treffer 0 |
| search (Limit 500) 'Quartzit' (selten, 8 Zeichen), beide | 10008.8 | 20290, 36152, 10009, 8576, 8550 |  |  |
| searchCount 'Quartzit' (selten, 8 Zeichen), beide | 4979.7 | 5665, 4426, 4980, 4985, 4793 |  | Treffer 28 |

### Favoriten

| Messpunkt | Median (ms) | Läufe (ms) | Wert | Bemerkung |
|---|---:|---|---|---|
| 883 Favoriten setzen (10 × 100) | 100.7 |  |  |  |
| favorites() bei 883 Favoriten | 9690.2 | 9993, 9538, 9633, 9778, 9690 |  | geliefert 883 |

### Löschen

| Messpunkt | Median (ms) | Läufe (ms) | Wert | Bemerkung |
|---|---:|---|---|---|
| deleteMedium (3000000 Einträge) | 222904.4 |  |  |  |
| incremental_vacuum + Checkpoint | 19475.3 |  |  |  |
| Dateigröße vor / nach Löschen / nach Vacuum |  |  | 2.442 GB / 2.442 GB / 1.757 GB | WAL: 0.000 GB / 0.971 GB / 0.000 GB |

### Bereinigen

| Messpunkt | Median (ms) | Läufe (ms) | Wert | Bemerkung |
|---|---:|---|---|---|
| pruneToMatch nach Tiefe 6 → 5 | 600419.4 |  |  | zu entfernen 2805525, entfernt 288163 (479/s), ABGEBROCHEN nach 10 min; Schätzung gesamt ≈ 5845 s |

