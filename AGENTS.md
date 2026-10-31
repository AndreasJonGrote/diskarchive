# AGENTS.md — Einstieg Disk Archive

Alle Anweisungen liegen in [`claude/`](claude/). **Lies zuerst [claude/AGENTS.md](claude/AGENTS.md)** (Rollen Host/Worker, Git-Verbot, Befundstufen, Quellen der Wahrheit) und halte dich daran.

- **Sprache: Deutsch.** Englisch nur in Bezeichnern, Befehlen und Zitaten.
- **Rolle** („Host“ oder „Worker“) sagt der Nutzer bei der Übergabe; ohne Angabe fragen, bevor etwas geändert wird.
- **Kein Git, das etwas verändert** (kein commit, push, add, checkout …); committen tut nur der Nutzer.
- **Worker:** Auftrag in [claude/PROMPT.md](claude/PROMPT.md), Regeln in [claude/todo/regeln.md](claude/todo/regeln.md).
- **Host:** Ablauf in [claude/abnahme-ablauf.md](claude/abnahme-ablauf.md), Stand in [claude/TODO.md](claude/TODO.md).
- Liegt hier eine `UEBERGABE.md`, liest ein neuer Host sie zuerst.

Hauptverzeichnis: `claude/` (Anweisungen), `layout/` (Design), `Werkzeuge/` (Skripte), `builds/` (letzte App und DMG, nicht in Git), Xcode-Projekt `diskindex/` (ab Paket 57 `DiskArchive/`).
