# Paket 25 — Zielversion 0.4.0 (freigegeben 25.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln). Volltexte und Abnahme von Paket 24: [archiv/paket-24-abgenommen-2026-10-25.md](../archiv/paket-24-abgenommen-2026-10-25.md).

**Reihenfolge (HALT am Ende):** `bug.0.4.198`. **HALT.**

## Entscheidung des Nutzers 25.10.

- **bug.0.4.198 — Text der Einstellung „Auf Updates hinweisen“ ohne „in der Menüleiste“ (niedrig).** Der Hinweis auf eine neue Version ist der Dialog im Hauptfenster (`todo.0.4.047`), nicht die Menüleiste. Im `Localizable.xcstrings` den Schlüssel `copy.settings.updates.text` ändern: de **„Disk Archive weist dich darauf hin, sobald eine neue Version verfügbar ist.“**, en **„Disk Archive lets you know as soon as a new version is available.“** Sonst nichts ändern (Titel UPDATES, Schalter, Lage im Tab Erweitert bleiben). Konzept: `konzept/datenbank.md` (Update-Modal). **Test:** ein bestehender oder neuer Texttest prüft beide Sprachen wortgleich (vorher rot im Status belegen); Pixeltests des Tabs Erweitert, falls vorhanden, nachziehen. Kein Patch nötig (nur Text; im Status begründen).
  **Status:**

**Paketende:** 0 Warnungen Debug und Release, seriell grün, parallel 3× grün, keine neuen `.ips`, App des Nutzers gebaut. Ist ein Lauf nur unter hoher Systemlast rot, Last und Testnamen im Status nennen.
