# Disk Archive (vormals Disk Index) — README

**Diese Datei enthält das aktuell gültige Konzept.** Rollen und Workflow: [AGENTS.md](AGENTS.md). Offene Aufgaben: [TODO.md](TODO.md) · Erledigt: [DONE.md](DONE.md). Erledigte Aufgaben: [archiv/prompt-verlauf-bis-2026-09-28.md](archiv/prompt-verlauf-bis-2026-09-28.md). Älterer Entscheidungsverlauf: [archiv/readme-verlauf-bis-2026-10-02.md](archiv/readme-verlauf-bis-2026-10-02.md).

## Name, Systemvoraussetzung, Veröffentlichung (Nutzer 09.10.)

- **Produktname: „Disk Archive“** (Website https://diskarchive.app/). Die App zeigt überall **„Disk Archive“** (das neue Layout ist bereits umbenannt; Nutzer 09.10.: Layout-Altstände nicht anfassen, große Layout-Änderungen folgen). Interne Namen (Xcode-Projekt `diskindex`, Typnamen wie `DiskIndexLog`) bleiben, sie sind für Nutzer unsichtbar.
- **Bundle-ID `app.diskarchive`** (umgekehrte Domain), Launch-Agent `app.diskarchive.launcher`, Log-Subsystem `app.diskarchive`. Datenordner `~/Library/Application Support/Disk Archive/`, Protokoll `~/Library/Logs/Disk Archive/`. **Keine Übernahme** aus „Disk Index“ (Nutzer 09.10.: Alpha, einziger Nutzer, alte App samt Daten gelöscht).
- **Mindest-macOS 14.0** (Nutzer: „wenn unser Code es zulässt“). Claude-Probebau 09.10. mit 14.0: nur `pointerStyle` (2 Stellen, ab 15) und `CGSize: Hashable` (ab 15) fehlen → mit Ausweichweg für 14 lösbar.
- **Fehlerbericht-Ziel (Nutzer 09.10., Doku `http://localhost:8888/disk-archive/api/docs/`):** `POST …/api/issues/`, JSON Schema 2 (Felder wie heute in der App: `schema`, `id`, `kind`, `createdAt`, `app{version,build,config}`, `system{macOS,model}`, `runtimeSeconds`, `signature`, `crash{signal,stack}`, `actions`, `logTail`, `inventory{media,items,dbBytes}`), höchstens 256 KB. **Erfolg = jedes 201; das Feld `id` ist optional (Nutzer 16.10., `todo.0.4.037`), sonst entstehen beim erneuten Senden Doppel.** Debug: `http://localhost:8888/disk-archive/api/issues/`, Release: `https://diskarchive.app/api/issues` (live seit 09.10.). `GET …/api/version/` liefert die aktuelle Version (noch nicht genutzt).
- **Systemfreigaben (Claude geprüft 09.10.):** nur **Wechselmedien** (und **Netzlaufwerke**, falls gelesen) und **Mitteilungen**; Autostart erzeugt nur den macOS-Hinweis „Hintergrundobjekt“. Keine Bedienungshilfen, kein voller Festplattenzugriff. Tests dürfen keine Systemrechte auslösen (TODO Regel 21).
- **Weitergabe außerhalb des App Store:** ab **1.0** Signatur „Developer ID Application“ + Notarisierung durch Apple (Bezahl-Mitgliedschaft im Apple Developer Program nötig). **Betas (bis 0.9) gehen ohne Notarisierung** an einen kleinen Kreis (Nutzer 18.10.); die Download-Seite erklärt das Öffnen (in „Programme“ ziehen, Systemeinstellungen → Datenschutz & Sicherheit → „Trotzdem öffnen“).

## Konzept nach Thema (seit 23.10.2026 aufgeteilt)

Das Konzept steht in Themendateien unter `konzept/`. **Nur die Datei zum Thema lesen.** Verweise wie „README Abschnitt 4“ oder „README „Datenbank““ meinen die Datei in dieser Tabelle. Der Host pflegt Entscheidungen direkt in der Themendatei.

| Datei | Thema | Größe |
|---|---|---|
| [konzept/roadmap.md](konzept/roadmap.md) | Roadmap (Versionen, maßgeblich) | 10 KB |
| [konzept/medien.md](konzept/medien.md) | Medien: Lebenszyklus, Statusmodell, Fehler-Modal, Pausieren (Abschnitte 2, 2a, 2b, 3) | 13 KB |
| [konzept/indizieren.md](konzept/indizieren.md) | Indizieren (Abschnitt 4) | 9 KB |
| [konzept/suche-navigation.md](konzept/suche-navigation.md) | Suchen, Filtern, Navigieren, Spaltenansicht: Scrollen (Abschnitt 5) | 8 KB |
| [konzept/einstellungen-start.md](konzept/einstellungen-start.md) | Einstellungen, Start und Dock (Abschnitte 6, 7) | 6 KB |
| [konzept/datenschutz-plattform.md](konzept/datenschutz-plattform.md) | Fehlerberichte, Datenschutz, Plattform und Sicherheit (Abschnitte 8, 9) | 3 KB |
| [konzept/darstellung.md](konzept/darstellung.md) | Darstellung und Verhältnis zum Layout (Abschnitt 10) | 3 KB |
| [konzept/offene-entscheidungen.md](konzept/offene-entscheidungen.md) | Offene Entscheidungen (Abschnitt 11) | 1 KB |
| [konzept/regelliste-artefakte.md](konzept/regelliste-artefakte.md) | Regelliste Artefakte (Spezifikation) | 7 KB |
| [konzept/datenbank.md](konzept/datenbank.md) | Datenbank (seit 0.3, Schema eingefroren) | 8 KB |
| [konzept/architektur.md](konzept/architektur.md) | Architektur (Aufbau der Software) | 4 KB |

# Konzept (aktuell gültig)

**Eine Stelle für alle konzeptionellen Entscheidungen, nach Thema sortiert.** Hier steht, wie die App **sein soll**. Das Layout zeigt, wie sie **aussieht**. Die chronologische Entstehung steht in [README.md](README.md) (Verlauf), die offenen Arbeiten in [TODO.md](TODO.md) · Erledigt: [DONE.md](DONE.md).

**Pflege:** Claude trägt jede Entscheidung des Nutzers hier ein. Überholte Entscheidungen werden **ersetzt**, nicht angehängt.
- Stand: 08.10.2026, Layout gelesen mit Stand 08.10. 08:33; offene Widersprüche stehen in Abschnitt 11. Markierung **[offen]** = noch nicht entschieden, **[Annahme]** = von Claude angenommen, bestätigt vom Nutzer noch nicht.

---

## 1. Produkt
- Disk Index kümmert sich **nur um externe Speichermedien** (USB-Sticks, externe SSDs/HDDs, SD-Karten). Keine Netzlaufwerke, keine Systemplatte, keine Disk-Images.
- Die App läuft **dauerhaft in der Menüleiste**. Jedes je angeschlossene und zur Indizierung freigegebene Medium behält seinen **Index**, auch offline bleibt der Inhalt durchsuchbar.
- **Eine Suche** findet Medien und Objekte (Dateien und Ordner) zugleich. Treffer öffnen die Spaltenansicht an genau der Stelle. Wichtige Objekte lassen sich als **Favoriten** markieren.

