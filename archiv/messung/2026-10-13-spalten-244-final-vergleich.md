# Vergleich Messung (238)

- Vorher: `2026-10-11-vorher.json`
- Nachher: `2026-10-13-spalten-244-final.json`

## Größe (Datenbankdatei)

| Szenario | Messpunkt | Vorher (GB) | Nachher (GB) | Δ % | ≥20 % kleiner |
|---|---|---:|---:|---:|---|
| S1 | nach Aufbau: Datenbankdatei | 0.749 | 0.279 | -62.8 | ja |
| S1 | nach Bereinigung: Datenbankdatei | 0.599 | 0.279 | -53.4 | ja |
| S2 | nach Aufbau: Datenbankdatei | 5.652 | 2.443 | -56.8 | ja |
| S2 | nach Bereinigung: Datenbankdatei | 3.671 | 1.686 | -54.1 | ja |

## Latenz (Median ms)

| Szenario | Messpunkt | Vorher | Nachher | Δ % | ≥25 % schneller |
|---|---|---:|---:|---:|---|
| S1 | alle Seiten, 50000 Kinder | 172.6 | 178.5 | +3.4 | nein |
| S1 | search (Limit 500) 'bil' (häufig, 3 Zeichen), ohne Filter | 68.9 | 6.6 | -90.4 | ja |
| S1 | searchCount 'bil' (häufig, 3 Zeichen), ohne Filter | 60.0 | 54.1 | -9.7 | nein |
| S2 | alle Seiten, 50000 Kinder | 175.4 | 159.7 | -9.0 | nein |
| S2 | search (Limit 500) 'bil' (häufig, 3 Zeichen), ohne Filter | 591.3 | 8.8 | -98.5 | ja |
| S2 | searchCount 'bil' (häufig, 3 Zeichen), ohne Filter | 551.2 | 415.4 | -24.6 | nein |

## Spalten-Guard (±10 %)

| Szenario | Vorher | Nachher | Δ % | innerhalb ±10 % |
|---|---:|---:|---:|---|
| S1 | 172.6 | 178.5 | +3.4 | ja |
| S2 | 175.4 | 159.7 | -9.0 | ja |

## Schwellen-Urteil

- **Größe (≥20 % kleiner, mind. ein Treffer):** **bestanden**
- **Abfrage (≥25 % schneller, mind. ein Kernpunkt):** **bestanden**
- **Spalten (50k alle Seiten, max +10 %):** **bestanden**
- **Gesamt 238 (Größe ODER Abfrage, und Spalten-Guard):** **bestanden**
