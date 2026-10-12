# Vergleich Messung (238)

- Vorher: `2026-10-11-vorher.json`
- Nachher: `2026-10-12-nachher.json`

## Größe (Datenbankdatei)

| Szenario | Messpunkt | Vorher (GB) | Nachher (GB) | Δ % | ≥20 % kleiner |
|---|---|---:|---:|---:|---|
| S1 | nach Aufbau: Datenbankdatei | 0.749 | 0.278 | -62.9 | ja |
| S1 | nach Bereinigung: Datenbankdatei | 0.599 | 0.278 | -53.6 | ja |
| S2 | nach Aufbau: Datenbankdatei | 5.652 | 2.444 | -56.8 | ja |
| S2 | nach Bereinigung: Datenbankdatei | 3.671 | 1.686 | -54.1 | ja |

## Latenz (Median ms)

| Szenario | Messpunkt | Vorher | Nachher | Δ % | ≥25 % schneller |
|---|---|---:|---:|---:|---|
| S1 | alle Seiten, 50000 Kinder | 172.6 | 224.6 | +30.1 | nein |
| S1 | search (Limit 500) 'bil' (häufig, 3 Zeichen), ohne Filter | 68.9 | 6.1 | -91.2 | ja |
| S1 | searchCount 'bil' (häufig, 3 Zeichen), ohne Filter | 60.0 | 52.5 | -12.5 | nein |
| S2 | alle Seiten, 50000 Kinder | 175.4 | 211.2 | +20.4 | nein |
| S2 | search (Limit 500) 'bil' (häufig, 3 Zeichen), ohne Filter | 591.3 | 11.0 | -98.1 | ja |
| S2 | searchCount 'bil' (häufig, 3 Zeichen), ohne Filter | 551.2 | 415.7 | -24.6 | nein |

## Spalten-Guard (±10 %)

| Szenario | Vorher | Nachher | Δ % | innerhalb ±10 % |
|---|---:|---:|---:|---|
| S1 | 172.6 | 224.6 | +30.1 | NEIN |
| S2 | 175.4 | 211.2 | +20.4 | NEIN |

## Schwellen-Urteil

- **Größe (≥20 % kleiner, mind. ein Treffer):** **bestanden**
- **Abfrage (≥25 % schneller, mind. ein Kernpunkt):** **bestanden**
- **Spalten (50k alle Seiten, max +10 %):** **nicht bestanden**
- **Gesamt 238 (Größe ODER Abfrage, und Spalten-Guard):** **nicht bestanden**
