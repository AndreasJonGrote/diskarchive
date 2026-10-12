#!/usr/bin/env python3
"""
Aufgabe 238 — Vergleich nachher vs. 196-vorher (Schwellen ROADMAP / datenbank-konzeption).
Usage: messung-vergleich.py [path/to/nachher.json]
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
MESSUNG = ROOT / "Werkzeuge" / "messung"
VORHER = MESSUNG / "2026-10-11-vorher.json"

SIZE_DB_LABELS = (
    "nach Aufbau: Datenbankdatei",
    "nach Bereinigung: Datenbankdatei",
)
COLUMN_50K = "alle Seiten, 50000 Kinder"
SEARCH_LIST = "search (Limit 500) 'bil' (häufig, 3 Zeichen), ohne Filter"
SEARCH_COUNT = "searchCount 'bil' (häufig, 3 Zeichen), ohne Filter"


def load_rows(path: Path) -> dict[tuple[str, str, str], dict[str, Any]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    rows: dict[tuple[str, str, str], dict[str, Any]] = {}
    for m in data.get("messungen", []):
        key = (m["szenario"], m["gruppe"], m["messpunkt"])
        rows[key] = m
    return rows


def parse_gb(wert: str) -> float | None:
    match = re.search(r"([\d.]+)\s*GB", wert or "")
    return float(match.group(1)) if match else None


def pct_change(before: float, after: float) -> float:
    if before == 0:
        return 0.0
    return (after - before) / before * 100.0


def median_ms(row: dict[str, Any] | None) -> float | None:
    if not row:
        return None
    ms = row.get("medianMs")
    return float(ms) if ms is not None else None


def find_nachher_json(arg: str | None) -> Path:
    if arg:
        return Path(arg)
    candidates = sorted(MESSUNG.glob("*-nachher.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not candidates:
        sys.exit("Keine *-nachher.json in Werkzeuge/messung")
    return candidates[0]


def main() -> None:
    nachher_path = find_nachher_json(sys.argv[1] if len(sys.argv) > 1 else None)
    if not VORHER.is_file():
        sys.exit(f"Referenz fehlt: {VORHER}")

    vorher = load_rows(VORHER)
    nachher = load_rows(nachher_path)

    lines: list[str] = []
    lines.append(f"# Vergleich Messung (238)\n")
    lines.append(f"- Vorher: `{VORHER.name}`")
    lines.append(f"- Nachher: `{nachher_path.name}`\n")

    size_pass = False
    lines.append("## Größe (Datenbankdatei)\n")
    lines.append("| Szenario | Messpunkt | Vorher (GB) | Nachher (GB) | Δ % | ≥20 % kleiner |")
    lines.append("|---|---|---:|---:|---:|---|")
    for scenario in ("S1", "S2"):
        for label in SIZE_DB_LABELS:
            key = (scenario, "Größe", label)
            b = parse_gb(vorher.get(key, {}).get("wert", ""))
            a = parse_gb(nachher.get(key, {}).get("wert", ""))
            if b is None or a is None:
                lines.append(f"| {scenario} | {label} | — | — | — | — |")
                continue
            delta = pct_change(b, a)
            ok = delta <= -20.0
            if ok:
                size_pass = True
            lines.append(
                f"| {scenario} | {label} | {b:.3f} | {a:.3f} | {delta:+.1f} | {'ja' if ok else 'nein'} |"
            )
    lines.append("")

    query_pass = False
    lines.append("## Latenz (Median ms)\n")
    lines.append("| Szenario | Messpunkt | Vorher | Nachher | Δ % | ≥25 % schneller |")
    lines.append("|---|---|---:|---:|---:|---|")
    latency_points = [
        ("Spaltenansicht", COLUMN_50K),
        ("Suche", SEARCH_LIST),
        ("Suche", SEARCH_COUNT),
    ]
    for scenario in ("S1", "S2"):
        for gruppe, messpunkt in latency_points:
            key = (scenario, gruppe, messpunkt)
            b = median_ms(vorher.get(key))
            a = median_ms(nachher.get(key))
            if b is None or a is None or b == 0:
                lines.append(f"| {scenario} | {messpunkt} | — | — | — | — |")
                continue
            delta = pct_change(b, a)
            ok = a <= b * 0.75
            if ok:
                query_pass = True
            lines.append(
                f"| {scenario} | {messpunkt} | {b:.1f} | {a:.1f} | {delta:+.1f} | {'ja' if ok else 'nein'} |"
            )
    lines.append("")

    column_guard_ok = True
    lines.append("## Spalten-Guard (±10 %)\n")
    lines.append("| Szenario | Vorher | Nachher | Δ % | innerhalb ±10 % |")
    lines.append("|---|---:|---:|---:|---|")
    for scenario in ("S1", "S2"):
        key = (scenario, "Spaltenansicht", COLUMN_50K)
        b = median_ms(vorher.get(key))
        a = median_ms(nachher.get(key))
        if b is None or a is None or b == 0:
            lines.append(f"| {scenario} | — | — | — | — |")
            continue
        delta = pct_change(b, a)
        ok = a <= b * 1.10
        if not ok:
            column_guard_ok = False
        lines.append(f"| {scenario} | {b:.1f} | {a:.1f} | {delta:+.1f} | {'ja' if ok else 'NEIN'} |")
    lines.append("")

    overall = (size_pass or query_pass) and column_guard_ok
    lines.append("## Schwellen-Urteil\n")
    lines.append(f"- **Größe (≥20 % kleiner, mind. ein Treffer):** {'**bestanden**' if size_pass else '**nicht bestanden**'}")
    lines.append(f"- **Abfrage (≥25 % schneller, mind. ein Kernpunkt):** {'**bestanden**' if query_pass else '**nicht bestanden**'}")
    lines.append(f"- **Spalten (50k alle Seiten, max +10 %):** {'**bestanden**' if column_guard_ok else '**nicht bestanden**'}")
    lines.append(f"- **Gesamt 238 (Größe ODER Abfrage, und Spalten-Guard):** {'**bestanden**' if overall else '**nicht bestanden**'}")
    lines.append("")

    out_text = "\n".join(lines)
    print(out_text)

    stem = nachher_path.stem
    compare_path = nachher_path.with_name(stem + "-vergleich.md")
    compare_path.write_text(out_text, encoding="utf-8")
    print(f"(geschrieben: {compare_path.relative_to(ROOT)})", file=sys.stderr)


if __name__ == "__main__":
    main()
