# Abschlussbericht — Messung „nachher“ + Schema 0.3 eingefroren (Aufgabe 238)

## 1. Zweck / Kontext

- **196 (vorher):** Baseline auf altem Schema (FTS, `path`, große `item`-Tabelle) — `Werkzeuge/messung/2026-10-11-vorher.md/.json`.
- **230–237:** Umbau auf **Schema V3** (`items` / `item_details`, neue Indizes, parallele Suche, Wartung, Einstellungen in SQLite).
- **238 (nachher):** Gleiche Messlatte wie 196 erneut fahren, automatisch gegen 196 vergleichen, Schwellen urteilen, Schema 0.3 dokumentiert einfrieren.

**Maschine (nachher-Lauf):** Mac16,12, Apple M4, 24 GB RAM; macOS 15.7.3 (24G419).  
**Echte Messung:** `DA_BENCH_SCALE=1` (Default), ein Lauf am 2026-10-12 (~2728 s reine Testzeit für S1+S2+V3-Suche laut xcodebuild; in `*-nachher.json` ist die Laufzeit höher, weil `BenchReport.write` frühere Probeläufe am selben Tag mitaddiert).  
**Freier Platz:** ≥142 GB zu Beginn von S1/S2.

Rohdaten: [`2026-10-12-nachher.md`](2026-10-12-nachher.md), [`2026-10-12-nachher.json`](2026-10-12-nachher.json).  
Vergleich: [`2026-10-12-nachher-vergleich.md`](2026-10-12-nachher-vergleich.md) (Skript `Werkzeuge/messung-vergleich.py`).

## 2. Methode

- **Start:** `./Werkzeuge/db-messung-nachher.sh` bzw.  
  `TEST_RUNNER_DA_BENCH=1 TEST_RUNNER_DA_BENCH_NAME=nachher xcodebuild test … -only-testing:diskindexTests/IndexBenchTests`  
  Debug mit `SWIFT_OPTIMIZATION_LEVEL=-O`, serial, Timeout 7200 s.
- **S1:** 1 Medium, 1 Mio. Einträge; Sonderordner 100 / 5 000 / 50 000 Kinder.
- **S2:** 300 Medien, ~8,6 Mio. Einträge (Plan wie in `IndexBenchTests`); Löschen des größten Mediums + Vacuum; danach Messungen.
- **Abweichungen zu 196:** Kein `path`-SUM, kein FTS-Block; stattdessen `items` + `item_details`, Indizes `items_*`, Suche über V3 (`search` Limit 500, `searchCount` parallel wie produktiv). Zusätzlich optionaler Test **232** schreibt separat `*-v3-suche.md` (nicht Teil des 196-Vergleichs).

**Probe:** `DA_BENCH_SCALE=0.01` und frühere Kurzläufe am selben Tag — nur Werkzeugcheck; Schwellen beziehen sich auf Scale **1**.

## 3. Ergebnisse (Kernzahlen vs. 196)

Vollständige Tabellen: siehe [`2026-10-12-nachher-vergleich.md`](2026-10-12-nachher-vergleich.md). Auszug:

| Kennzahl | S1 vorher → nachher | S2 vorher → nachher |
|---|---|---|
| DB nach Aufbau | 0,749 → **0,278 GB** (−63 %) | 5,652 → **2,444 GB** (−57 %) |
| DB nach Bereinigung | 0,599 → **0,278 GB** (−54 %) | 3,671 → **1,686 GB** (−54 %) |
| Spalten 50k (Median ms) | 172,6 → **224,6** (+30 %) | 175,4 → **211,2** (+20 %) |
| Suche `bil` Liste | 68,9 → **6,1 ms** | 591,3 → **11,0 ms** |
| Suche `bil` Count | 60,0 → **52,5 ms** | 551,2 → **415,7 ms** |

**Hinweise im Lauf:** `pruneToMatch` in S1 und S2 nach **10 min** abgebrochen (677k bzw. 2,8 Mio. zu entfernen; in S2 nur Teilfortschritt). Größe „nach Bereinigung“ reflektiert diesen Abbruch, nicht vollständiges Prune — vergleichbar zur 196-Messung, die ebenfalls zeitlich begrenzt sein kann.

## 4. Schwellen-Urteil (238)

| Kriterium | Urteil |
|---|---|
| Größe ≥20 % kleiner (mind. ein Messpunkt) | **Bestanden** (alle vier DB-Größen deutlich darunter) |
| Abfrage ≥25 % schneller (Spalten 50k oder `bil` Liste/Count) | **Bestanden** (`bil`-Liste S1/S2 stark; Count knapp unter 25 % in S1, Liste reicht) |
| Spalten-Guard (50k alle Seiten, max +10 % vs. vorher) | **Nicht bestanden** (S1 +30 %, S2 +20 %) |
| **Gesamt 238** (Größe **oder** Abfrage **und** Spalten-Guard) | **Nicht bestanden** (wegen Spalten-Guard) |

**Ursache Spalten-Guard (keine Test-Abschwächung):** Median „alle Seiten, 50 000 Kinder“ liegt über 196, vermutlich andere Abfragepfad-Kosten (Pagination/Identität) bei deutlich kleinerer DB und ohne FTS. Suche profitiert massiv vom V3-Design; Spalten-Pagination bleibt Follow-up (0.3.2 / Profiling), nicht Schwellen senken.

## 5. Schema-Einfrieren

- Migration **`0.3.0-schema`** in `SchemaV3.swift` ist die **eingefrorene Basis** (Kommentar „Schema 0.3 eingefroren (238)“).
- **Ab 0.4:** nur Erweiterung — neue Tabellen/Schlüssel, Anbau-Migrationen; **keine** Umbauten bestehender Spalten (README „Nach 0.3 nur noch erweitern“).
- **Tabellen** (`SchemaV3.tableNames`): `storages`, `storage_meta`, `items`, `item_details`, `favorites`, `extensions`, `meta_keys`, `settings`, plus vorbereitet und bewusst noch leer in 0.3: **`item_meta`**, **`item_checksum`**; **`api_queue`** wird seit 0.3.1 genutzt (Fehlerberichte, Versions-Check).

## 6. Offene Risiken / Folge

- Spalten 50k über Guard — gezielt messen/optimieren (Layout 0.3.2).
- `pruneToMatch` bei Millionen-Einträgen: 10-min-Cap im Bench; Produktiv-Wartung (236) separat beobachten.
- Seltenes Wort / Filterkombinationen: in 196 teils FTS-spezifisch; V3-Verhalten dokumentiert in Roh-MD.
- **0.3.1:** `api_queue` / Fehlerbericht-Outbox — **nicht** Teil von 238; inzwischen gebaut und abgenommen.
- **238 löst nicht:** UI-Layout, API-Versand, vollständiges Prune in Bench.

## 7. Kurzverweis für Abnahme

- Implementierung: `IndexBenchTests` (Default `DA_BENCH_NAME=nachher`), `Werkzeuge/db-messung-nachher.sh`, `Werkzeuge/messung-vergleich.py`, dieser Bericht.
- Normale Test-Suite **515/515** ohne `DA_BENCH`; Messlauf separat (~45 min Scale 1).
- Regel 23: Debug-Binary nach Stand 2026-10-12 20:01 neuer als geänderte `.swift` (u. a. `SchemaV3.swift`).
