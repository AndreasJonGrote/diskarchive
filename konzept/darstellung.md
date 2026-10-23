# Konzept: Darstellung und Verhältnis zum Layout (Abschnitt 10)

Teil des Konzepts, ausgelagert aus [README.md](../README.md) am 23.10.2026 (gilt unverändert; bei Widerspruch zum Layout gilt das Konzept, außer reine Optik).

## 10. Darstellung
- **Chips werden nie gekürzt (Nutzer 05.10.):** Passt der Text nicht in die Zeile, bricht der Chip um; ist der Text länger als der Behälter, bricht er im Chip um. Gilt für alle Chips (Ausschlüsse, Filter, Medien, Status).
- **Texte ohne Layout-Vorlage (Nutzer 05.10.):** Jeder Text, der nicht im Layout steht, ist ein **Vorschlag** (`ProposalCopy`) und erscheint im **Debug-Build rot** (Debug-Menü „Vorschlagstexte rot“), nicht darstellbare Texte (Mitteilungen, Alerts) mit Präfix „[V] “. Der Nutzer nimmt sie ins Layout auf oder streicht sie. `LayoutCopy` enthält nur Layout-Texte.
- **Zahlen (Nutzer 05.10.):** Tausendertrenner ist der **Punkt** („12.480“, „238.421 Dateien“), wie macOS auf Deutsch (Layout seit 07.10. ebenso).
- **Button-Regeln (Nutzer 05.10.: „es gibt keinen Mix aus Buttons“):** (1) **Zwei Größen, Maße nur aus dem Komponentenkatalog** (`layout/Komponenten.dc.html`, Zusammenfassung `docs/Komponenten-Masse.md`; ersetzt die alten Werte 35/28 pt): **Groß** = 14/600, Innenabstand 10/18, Höhe **38,8**, Radius 8, Rahmen 1 px — für Dialoge, Details, Einstellungen; **Klein** = 12/600, Innenabstand 4/12, Höhe **24,4**, Radius 8 — für Popover, Selectgroups, Filterleiste, Dropdown. (2) **In einer Gruppe nie gemischt:** Alle Knöpfe, die nebeneinander oder untereinander als Auswahl stehen (Details: „Vergessen“, „Neu indizieren“, „Inhalt anzeigen“), haben **dieselbe Größe und dieselbe Höhe**. Die Größe bestimmt das Layout der Sektion, nicht der Knopf. (3) **Breite = Inhalt + Innenabstand**, nie gestreckt und keine Mindestbreite, **Ausnahme** nur, wenn das Layout `flex:1` vorgibt (Dialoge 13 und 14: zwei gleich breite Knöpfe). (4) Der Bestätigungsknopf hält seine Breite in allen Stufen (längster der drei Texte). (5) Neu angelegte Knöpfe nehmen **eine** Stilvorlage (`PrimaryButtonStyle`, `SecondaryButtonStyle`; rote Aktionen über den Bestätigungsknopf; `DestructiveButtonStyle`/`GhostButtonStyle` entfallen, 10.10. ungenutzt) mit Parameter `size: .standard | .compact`, keine eigenen Abstände je Ansicht.
- Hell und Dunkel nach Layout (Rollenfarben, Auswahl #4A4949 dunkel, Schatten immer #2D2B2B). **Farbe bedeutet Zustand, bedient wird in Schwarz.** App-Icon: Kachel 824/1024, Symbol 60 % der Kachel; **das dunkle Icon (Verlauf #575757 nach #1F1F1F, helles Symbol) ist das eine App-Icon in Hell und Dunkel, kein Wechsel nach Erscheinungsbild** (Nutzer 02.10.).

## Verhältnis zum Layout

**Vorschlagstexte (Nutzer 11.10.):** Alle bisher rot markierten Vorschlagstexte gelten als festgelegt; die rote Markierung entfällt. Neue Texte ohne Layout-Vorlage legt der Umsetzer normal an und listet sie zur Prüfung auf.

Maßgeblich für Optik, Farben, Icons, Screen-Struktur und **alle Texte** sind [layout/Disk Index App.dc.html](../layout/Disk%20Index%20App.dc.html) (Sektionen 00–15) und [layout/Farbschema.dc.html](../layout/Farbschema.dc.html). Bei Widerspruch zwischen Layout und Konzept gilt das **Konzept** (außer reine Optik), das Layout wird angepasst. Jede Abweichung der App von Text oder Aufbau des Layouts ist ein Fehler.

Neue Entscheidungen trägt Claude direkt in das Konzept ein (überholte werden ersetzt, nicht angehängt).

---
