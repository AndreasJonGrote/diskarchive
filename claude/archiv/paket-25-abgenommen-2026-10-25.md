# Paket 25 — Zielversion 0.4.0 (freigegeben 25.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln). Volltexte und Abnahme von Paket 24: [archiv/paket-24-abgenommen-2026-10-25.md](paket-24-abgenommen-2026-10-25.md).

**Reihenfolge (HALT am Ende):** `bug.0.4.198`. **HALT.**

## Entscheidung des Nutzers 25.10.

- **bug.0.4.198 — Text der Einstellung „Auf Updates hinweisen“ ohne „in der Menüleiste“ (niedrig).** Der Hinweis auf eine neue Version ist der Dialog im Hauptfenster (`todo.0.4.047`), nicht die Menüleiste. Im `Localizable.xcstrings` den Schlüssel `copy.settings.updates.text` ändern: de **„Disk Archive weist dich darauf hin, sobald eine neue Version verfügbar ist.“**, en **„Disk Archive lets you know as soon as a new version is available.“** Sonst nichts ändern (Titel UPDATES, Schalter, Lage im Tab Erweitert bleiben). Konzept: `konzept/datenbank.md` (Update-Modal). **Test:** ein bestehender oder neuer Texttest prüft beide Sprachen wortgleich (vorher rot im Status belegen); Pixeltests des Tabs Erweitert, falls vorhanden, nachziehen. Kein Patch nötig (nur Text; im Status begründen).
  **Status:** Bereit zur Prüfung. Neuer Test `L10nTests/updatesSettingTextDoesNotMentionTheMenuBar` prüft de und en wortgleich, vorher rot (13:45, 2 Befunde: alter Wortlaut mit „Menüleiste“/„menu bar“). Danach `copy.settings.updates.text` in `Localizable.xcstrings` geändert (sonst nichts) → grün; mit grün sind `UpdateDialogTests/advancedTabTogglesTheSameSetting` hell/dunkel und `LayoutCopyTests` (13:50). Der Tab Erweitert hat keinen Pixeltest auf den Text, im Layout steht der Satz nicht.
  Debug und Release 0 Warnungen; App des Nutzers 13:56:38, Signatur gültig, 0.4.0, neuer Text de/en im Bundle. Kein Patch: nur Text, der Texttest ist der Nachweis. Kein Gesamtlauf (Vorgabe).

**Paketende (Host 25.10., nur Text, Nutzer spielt nebenher):** 0 Warnungen Debug und Release, die betroffenen Tests (Texttest, Tab Erweitert) grün, App des Nutzers gebaut. **Keinen Gesamtlauf** (seriell/parallel) – den macht der Host später auf ruhigem Rechner.

## Vorprüfung Host 25.10. (13:58–14:01, Nutzer spielt)

Diff gelesen: nur `copy.settings.updates.text` (de/en) und ein neuer Test in `L10nTests`, alter Wortlaut nirgends mehr im Code, Konzept oder Layout. `pruefung.sh schnell`: Debug 0 Warnungen; `L10nTests`, `LayoutCopyTests`, `WindowTestGroup/UpdateDialogTests` grün. **Offen für die Abnahme:** `pruefung.sh voll` auf ruhigem Rechner.

## Abnahme Host 25.10. (Gesamtlauf 14:05–14:32, ruhiger Rechner)

`Werkzeuge/pruefung.sh voll`: Debug und Release 0 Warnungen, seriell **1104/1104** grün, Parallel 1–3 **grün** (je 1098 bestanden, 6 übersprungen), keine neuen `.ips`, keine Patches (nur Text, begründet), App des Nutzers 14:32:10, Signatur gültig, Version 0.4.0.

- **Abgenommen:** `bug.0.4.198`.
