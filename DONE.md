# DONE.md — von Claude abgenommene Aufgaben und Fehler

Kennungen: bis 233b alte Aufgabennummern; ab 12.10. `todo.<Version>.<Nr>` (Aufgabe) und `bug.<Version>.<Nr>` (Fehler), Tabelle unten.


Ältere Zeilen (alte Nummern bis 233b, Kennungen bis 0.3.9): [archiv/done-bis-0.3.9.md](archiv/done-bis-0.3.9.md). Prüfzeichen: A = Gesamtlauf seriell grün, B = Symbole verifiziert, C = Code gelesen.

## Ab 0.4 (Paket 9 ff.)

| Kennung | früher | Inhalt | Abgenommen | Prüfung |
|---|---|---|---|---|
| todo.0.3.9.001 | – | `MARKETING_VERSION` 0.3.9 (4 Stellen), Versions-Tests angepasst | 18.10. Host (seriell 840/840, parallel 3/3, 0 Warnungen, App 0.3.9) | A C (Prüf-Agenten) |
| bug.0.4.063 | – | Nur-Lesen-Sperre verdrahtet: Läufe, Regel-Abgleich und Überwachung stoppen beim Einrasten, nach dem Entsperren läuft alles wieder an; Tests über die echte Kette (Nachholen unterbrochener Abgleiche: `bug.0.4.073`) | 18.10. Host (seriell 840/840, parallel 3/3, 0 Warnungen, App 0.3.9) | A C (Prüf-Agenten) |
| bug.0.4.064 | – | Notfall-Zeitgeber beim Beenden: erst Antwort und Ausstieg, dann Protokoll auf eigener Queue (höchstens 250 ms Wartezeit) | 18.10. Host (seriell 840/840, parallel 3/3, 0 Warnungen, App 0.3.9) | A C (Prüf-Agenten) |
| bug.0.4.065 | – | „Frisch installiert“ hängt an der Medienzahl bei der ersten API-Antwort (Feinschliff „nur indizierte Medien“: `bug.0.4.072`) | 18.10. Host (seriell 840/840, parallel 3/3, 0 Warnungen, App 0.3.9) | A C (Prüf-Agenten) |
| bug.0.4.066 | – | Zählphase: Merker zu Beginn des Vorlaufs, kein erneutes Indizieren beim Fortsetzen (Trigger-Test), Halt vor Zählbeginn zählt neu | 18.10. Host (seriell 840/840, parallel 3/3, 0 Warnungen, App 0.3.9) | A C (Prüf-Agenten) |
| bug.0.4.067 | – | Größenformat wie im Finder: unter 1.000 Byte als Bytes, Null als Ziffer, darüber FormatStyle; Tests sprachunabhängig | 18.10. Host (seriell 840/840, parallel 3/3, 0 Warnungen, App 0.3.9) | A C (Prüf-Agenten) |
| bug.0.4.068 | – | Kleinkram: unbekannte Pausen-Spanne, Ladehinweis-Test, Aushängen-Pfad, `loadUnaligned`, Rauchtest gekennzeichnet, Symlinks im FileManager-Weg per `lstat` | 18.10. Host (seriell 840/840, parallel 3/3, 0 Warnungen, App 0.3.9) | A C (Prüf-Agenten) |
| todo.0.4.026 | – | „Für dieses Medium merken“ ausgewertet: ohne Haken fragt der Dialog beim nächsten Anschließen wieder (Änderung in 05/06: `bug.0.4.075`) | 18.10. Host (seriell 840/840, parallel 3/3, 0 Warnungen, App 0.3.9) | A C (Prüf-Agenten) |
| todo.0.4.027 | – | Abgelaufene Pause beim Start meldet einmal „Medien werden wieder indiziert.“ | 18.10. Host (seriell 840/840, parallel 3/3, 0 Warnungen, App 0.3.9) | A C (Prüf-Agenten) |
| todo.0.4.028 | – | Versions-Check nach Kalenderzeit (Zeitpunkt gespeichert, Start/Aufwachen/stündlich; Sperre beim Start: `bug.0.4.074`) | 18.10. Host (seriell 840/840, parallel 3/3, 0 Warnungen, App 0.3.9) | A C (Prüf-Agenten) |
| todo.0.4.029 | – | Jedes 201 gilt als Erfolg, `id` optional | 18.10. Host (seriell 840/840, parallel 3/3, 0 Warnungen, App 0.3.9) | A C (Prüf-Agenten) |
| bug.0.4.072 | – | „Frisch installiert“ zählt nur Medien mit Index (`firstIndexedAt`); Tests über die echte Erkennung | 18.10. Host (seriell 866/866, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.073 | – | Nach dem Entsperren werden unterbrochene Abgleiche nachgeholt; Test über die echte Kette, eigener Test für `stopAllForVersionLock` | 18.10. Host (seriell 866/866, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.074 | – | Versions-Sperre beim Start synchron vor der Erkennung (`StoreLaunchSequence`), alter Versions-Check-Code samt prozessweiter Variable entfernt | 18.10. Host (seriell 866/866, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.075 | – | Änderung der Entscheidung in 05/06 gilt als gemerkt; Tests ohne Handaufruf | 18.10. Host (seriell 866/866, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.076 | – | Kleinkram: Einzahl im Größenformat, `>= 2` im Lookup-Test, Startreihenfolge im Pausen-Test, Flush-Reste nach der Sperre | 18.10. Host (seriell 866/866, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| todo.0.4.023 | – | Fehlerbericht mit echten Protokollzeilen über die echte Kette getestet (letzte 100 Zeilen, Schwärzung, ≤ 256 KB); Feinschliff: `bug.0.4.078`/`079` | 18.10. Host (seriell 866/866, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.077 | – | Natürliche Namensordnung über die Seitengrenze: Index `items_search_natural` (eigene Migration), Name/Medium natürlich in SQL, Vergleich auf UTF-8-Bytes ohne Speicheranlegen (Gleichwertigkeit alt/neu getestet); Nachmessung Host +5,2 % Indizierzeit, +15,35 % Größe (hingenommen) | 18.10. Host (seriell 872/873, parallel je 1 rot nur `bug.0.4.081`, 0 Warnungen) | A C (Prüf-Agenten), Messung |
| bug.0.4.078 | – | Schwärzung: `$s`/`$S` nur auf echten Stapelrahmen, übrige Zeilen normal geschwärzt (Feinschliff: `bug.0.4.082`) | 18.10. Host (seriell 872/873, parallel je 1 rot nur `bug.0.4.081`, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.079 | – | Kürzung des Fehlerberichts behält mindestens 20 Protokollzeilen, ≤ 256 KB (Reihenfolge: `bug.0.4.083`) | 18.10. Host (seriell 872/873, parallel je 1 rot nur `bug.0.4.081`, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.080 | – | Kleinkram: wartende Starts zusammengefasst, Entsperren geordnet, `flushInFlight` mit Nummer, Marke bei unbekanntem Medium, Testordner aufgeräumt (Rest: `bug.0.4.084`, `085`) | 18.10. Host (seriell 872/873, parallel je 1 rot nur `bug.0.4.081`, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.086 | – | Ein Datenbank-Pool je Prozess (`ArchiveDatabase`), Öffnen und Migration im Hintergrund, Fehlerbericht und Warteschlange teilen ihn (Test-Nacharbeit: `bug.0.4.093`, Reste `094`) | 20.10. Host (seriell 894/894, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.087 | – | Details-Spalte scrollt wieder in die Sicht; zählt nur die Spalte der Auswahl | 20.10. Host (seriell 894/894, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.088 | – | Ignorieren blendet an Ort und Stelle aus, kein Ladezustand, Warteschlange leert nichts (Reste: `bug.0.4.096`, `097`, `099`) | 20.10. Host (seriell 894/894, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.089 | – | Trennlinie zwischen Spalten in jedem Zustand, zentral im Spalten-Overlay | 20.10. Host (seriell 894/894, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.090 | – | Spaltenkennung je Medium, kein hängender Ladehinweis nach Medienwechsel | 20.10. Host (seriell 894/894, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.091 | – | Rollbalken-Platz reserviert (`ScrollbarGutter`) in Einstellungen, Suche, Favoriten, Dashboard (offen: Frage leere Leiste, `bug.0.4.100`) | 20.10. Host (seriell 894/894, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.092 | – | Reine Filtersuche ohne Medien-Kacheln (toter Code: `bug.0.4.102`) | 20.10. Host (seriell 894/894, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.081 | – | Sortierköpfe über die ganze Spaltenbreite klickbar (`TableSortHeader`), Test aus echter Inhaltsbreite | 20.10. Host (seriell 894/894, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.082 | – | Schwärzung: Zeilenumbrüche im Protokoll maskiert, Rahmen-Ausnahme nur für das Symbol | 20.10. Host (seriell 894/894, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.083 | – | Kürzung: Brotkrumen → Rahmen bis 0 → Protokoll bis 20 → Aktionen (Testlücke: `bug.0.4.102`) | 20.10. Host (seriell 894/894, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.084 | – | Live-Überwachung startet auch nach gescheitertem Lauf (Schleife: `bug.0.4.095`) | 20.10. Host (seriell 894/894, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.085 | – | Kleinkram: wartender Start verworfen, Bedingung statt Schlafen, Aufräumen, Bytevergleich, Meldung vor Fortsetzen | 20.10. Host (seriell 894/894, parallel 3/3, 0 Warnungen) | A C (Prüf-Agenten) |
| bug.0.4.116 | – | Testfenster außerhalb des Bildschirms, Wächter `NoVisibleTestWindowsTests` (Reste: `bug.0.4.142`) | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.117 | – | Erkennungs-Panels je AppState, Lage statt Test-Ausschluss, nie Key (Reste: `143`, `119`) | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.105 | – | Einstellungen bei Lesefehler oder neuem Feld nie überschrieben (Anzeige: `153`) | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.104 | – | Favoriten verschobener Dateien nach Unterbrechung (eine Reihenfolge; Rest: `141`) | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.103 | – | Warteschlange macht Nachfahren ignorierter Ordner nicht mehr sichtbar | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.126 | – | Abgebrochener Erstlauf öffnet als „ausstehend“ (Rest: `151`) | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.127 | – | Nicht lesbarer Ordner: Lauf endet unvollständig, Nachlesen der Lücke (Rest: `151`) | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.128 | – | Erkennungs-Dialog ändert den Status nicht mehr | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.129 | – | „Neu indizieren“ wird freigegeben, wenn kein Lauf startet (Reste: `152`) | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.137 | – | Versions-Check liest und schreibt im Hintergrund (Nachweis: `144`) | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.138 | – | Tiefer neuer Ordner ohne Vollabgleich (Sortierung: `154`) | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.109 | – | Zeitüberschreitung mit Backoff und Obergrenze (Versions-Check offline: `145`) | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.093 | – | Startkette: Bedienbarkeit während der Migration bewiesen | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.095 | – | Überwachung nach Fehler ohne Wiederhol-Schleife (Kettentest: `155`) | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.096 | – | Favoriten während der Warteschlange ausgeblendet (Reste: `146`) | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.097 | – | Treffer und Favoriten unter ignoriertem Ordner sofort weg | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.131 | – | Offener Pfad folgt Löschen/Umbenennen (Rest: `147`) | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.132 | – | Treffer öffnet die Spaltenansicht an der Stelle (Tasten und Scroll-Aufträge: `148`) | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.133 | – | Typ-Chips ganz klickbar (Baustein doppelt: `149`) | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.100 | – | Rollbalken-Platz ohne leere Leiste, Sortierkopf-Tests (Reste: `150`) | 23.10. Host (seriell 929/929, parallel 3/3, 0 Warnungen, Paket 13) | A C (Prüf-Agenten) |
| bug.0.4.094 | – | Ein Pool je Prozess: Öffnungsfehler gemerkt bis Wiederholen, Namen erst nach dem Verdrahten, toter `openQueuePool()` entfernt | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.098 | – | Rauchtest um 081, 088, 089, 091 ergänzt | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.099 | – | Ausblenden an Ort und Stelle: erstmals ladende Spalten bleiben ladend, Fokus `> cut`, Sperre entfernt; Messung 300.000 → 82 ms (Debug -O) | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.101 | – | Rauchtest ohne `NSApp.activate`, Fenster außerhalb des Bildschirms | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.102 | – | Kleinkram: `searchMediumIDs` entfernt, Kürzungsschritt 3 getestet, Senke-Reihenfolge | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.107 | – | Index-Migrationen mit `foreignKeyChecks: .immediate` | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.108 | – | „Vergessen“ bucht Wartungsschuld | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.110 | – | Backoff-Termin mit Wecker, Abfrage im Hintergrund | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.111 | – | Leak-Wächter: Groß/Klein, Lookaround (Rest: `bug.0.4.162`) | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.112 | – | Benutzername nicht im Protokoll (Lücken im Wächter: `bug.0.4.158`) | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.114 | – | Warteschlange liest im Hintergrund | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.115 | – | Toter Code `DiskIndexLog.report`/`CrashReportText.make` entfernt | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.118 | – | Regel 18 in Live- und Spaltentests | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.119 | – | Regel 18 in Panel-Tests, `NewMediumDetectedDialog.applyChoice` | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.120 | – | Prozessweite Test-Schalter ersetzt (`@TaskLocal`, je `AppState`) | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.121 | – | Leistungsgrenzen nur unter `DA_BENCH` (`BenchGate`) | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.122 | – | Rauchtest Mitteilungen: Schalter im Bild, keine echte Mitteilung | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.123 | – | Regel 20 in Tests: kein `!`, `[i]` hinter `#require` (Rest: `bug.0.4.162`) | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.124 | – | Test-`.plist` aufgeräumt (Rest: `bug.0.4.162`) | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.125 | – | Positive Signale statt Warten, `IssueStub` je Test, Umgebungsvariable statt `/tmp` | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.130 | – | Kein zweiter Vollabgleich nach `cancel`, höchstens einer je Bündel (Rest: `bug.0.4.161`) | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.135 | – | Vergessenes Medium: Pfad und Auswahl zurückgesetzt, kein Zustand in `onAppear` | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.136 | – | Spinner „Wird indiziert“ in `DesignColor.stateOnline` (Nachweis: `bug.0.4.163`) | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.139 | – | Versions-Sperre bricht alle Läufe sofort ab (Test: `bug.0.4.159`) | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.140 | – | FSEvents-Strom öffnet im Hintergrund, Fehlschlag protokolliert (Ereignisfenster: `bug.0.4.157`) | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.141 | – | Favoriten verschobener Dateien nach Unterbrechung erhalten (Reste: `bug.0.4.156`) | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.142 | – | Testfenster immer außerhalb, Wächter | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.143 | – | `prepareForTermination` nicht mehr prozessweit | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.144 | – | Haupt-Thread-Nachweis je Anweisung, Antworten des Versions-Checks der Reihe nach | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.145 | – | Versions-Check offline zählt nicht gegen die Grenze | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.146 | – | Favoritenzahl und Suche während der Warteschlange ohne Ausgeblendetes („–“ bis danach) | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.147 | – | Offener Pfad folgt: Randfall (Pixel-Nachweis: `bug.0.4.163`) | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.149 | – | Ein Chip-Rezept (`ChipButton`) | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.150 | – | Rollbalken ohne leere Leiste: Reste, Breite in Favoriten, Suche, Dashboard | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.151 | – | Lücke getrennt von `firstIndexedAt` (`indexGaps`), Status bleibt `pending` | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.152 | – | „Neu indizieren“ nicht mehr dauerhaft gesperrt | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.153 | – | Unlesbare Einstellungen: Hinweis, Sitzung wie pausiert | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.154 | – | Bündelung tiefer Ordner: Tiefe einmal je Pfad | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.155 | – | Überwachung nach Fehler: Kettentests (Test schwach: `bug.0.4.160`) | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| todo.0.4.043 | – | Favoriten werden geladen: Ladefläche sofort, mindestens 1 s (`MinimumLoadingIndicator`) | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| todo.0.4.044 | – | `MARKETING_VERSION` 0.4.0 (4 Stellen), Versions-Tests angepasst | 23.10. Host (seriell 993/993, eigene Tests parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.148 | – | Scroll-Aufträge der Spaltenansicht: Auftrag bleibt offen, bis der Inhalt steht; Regression aus Paket 14 behoben, Tastenlogik in `AppState` (Rest: `bug.0.4.168`) | 23.10. Host (seriell 1011/1011, parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.134 | – | Live-Änderung scrollt nicht mehr nach rechts (Fenstertests Umbenennen/Löschen) | 23.10. Host (seriell 1011/1011, parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.113 | – | Absturzbericht: Version, Build, Laufzeit und Aktionen aus dem abgestürzten Lauf, auch bei Signal-Absturz (Rest: `bug.0.4.164`) | 23.10. Host (seriell 1011/1011, parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.156 | – | Wiederverbinden: Segmente erst im Rückfall, Lesefehler behält Favorit, Merker je Stapel (Reste: `bug.0.4.165`, `169`) | 23.10. Host (seriell 1011/1011, parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.157 | – | FSEvents: Ereignis-Stand synchron in `changes()`, kein Verlust vor dem Öffnen | 23.10. Host (seriell 1011/1011, parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.158 | – | Fehlertexte in allen Log-Wegen nur als `errorSummary`, Wächter erweitert | 23.10. Host (seriell 1011/1011, parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.159 | – | Versions-Sperre räumt alle abgebrochenen Läufe auf, Test mit zwei Medien (Rest: `bug.0.4.166`) | 23.10. Host (seriell 1011/1011, parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.160 | – | Überwachung nach Fehler: Lauf startet wirklich, positives Signal (Rest: `bug.0.4.166`) | 23.10. Host (seriell 1011/1011, parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.161 | – | Vollabgleich-Merker fällt beim Start des Abgleichs | 23.10. Host (seriell 1011/1011, parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.162 | – | Kleinkram aus Prüfung 14 (a–j; Nachweis f: `bug.0.4.167`) | 23.10. Host (seriell 1011/1011, parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.163 | – | Nachweise aus Paket 14 (Pixel, Chip, Mindestdauer je `AppState`; Reste b, d: `bug.0.4.167`) | 23.10. Host (seriell 1011/1011, parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.164 | – | Absturzbericht: alte `CRASH`-Zeile zählt nicht, Abschnitt endet an der nächsten Startzeile, `"?"` statt leer (Rest: `bug.0.4.170`) | 23.10. Host (seriell 1021/1021, parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.165 | – | Wiederverbinden: Merker nur bei Bedarf und angehängt, Positivtest, `storageID`, Datenbankfehler weitergereicht (Rest: `bug.0.4.171`) | 23.10. Host (seriell 1021/1021, parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.166 | – | Tests zu 159/160: Fehler-Ende mit Pause/Sperre, Reihenfolge des Abbruchs nachgewiesen | 23.10. Host (seriell 1021/1021, parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.167 | – | Nachweise: Abgleichlauf für `scratchRestartPending`, `observedDocument`, Datenschutz-Wächter mehrzeilig (Rest: `bug.0.4.172`) | 23.10. Host (seriell 1021/1021, parallel 3/3, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten) |
| bug.0.4.169 | – | Teil-Prüfsumme außerhalb der Transaktion ohne Datenverlust: fehlender Vorab-Wert = unlesbar, Zeitgrenze je Datei und gesamt, Lauf-Zustand bis nach dem Schreiben (Reste: `bug.0.4.174`–`176`) | 24.10. Host (seriell 1032/1032, parallel 3/3, Sabotage 15/15, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten, Sabotage-Patches) |
| bug.0.4.168 | – | Scroll zur Details-Spalte auch während der Indizierung anderer Medien (ohne globalen Zähler, Signatur mit Namen der Auswahl; Rest: `bug.0.4.173`) | 24.10. Host (seriell 1032/1032, parallel 3/3, Sabotage 15/15, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten, Sabotage-Patches) |
| bug.0.4.170 | – | Absturzbericht: abgestürzter Lauf über `crashedRunRange`, Grenze 6 h, Absturzabschnitt nur aus diesem Lauf | 24.10. Host (seriell 1032/1032, parallel 3/3, Sabotage 15/15, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten, Sabotage-Patches) |
| bug.0.4.171 | – | Wiederverbinden: Datenbankfehler im Rückfall weitergegeben, Merker an der Grenze gekürzt | 24.10. Host (seriell 1032/1032, parallel 3/3, Sabotage 15/15, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten, Sabotage-Patches) |
| bug.0.4.172 | – | Spinnerfarbe gegen feste sRGB-Referenz, Kommentar `IndexingService`, Wächter ohne Klammern in Zeichenketten | 24.10. Host (seriell 1032/1032, parallel 3/3, Sabotage 15/15, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten, Sabotage-Patches) |
| bug.0.4.175 | – | Wiederverbinden nur bei wirklich eingehängtem Medium (`MountedMediumCheck`: Einhängepunkt und Volume passen), sonst behalten (Reste: `bug.0.4.177`, `179`) | 24.10. Host (seriell 1041/1041, eigene Tests parallel 3/3, Sabotage 9/9, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten, Sabotage-Patches) |
| bug.0.4.174 | – | Abbruch während des Abschlusses widerruft den wartenden nächsten Lauf | 24.10. Host (seriell 1041/1041, eigene Tests parallel 3/3, Sabotage 9/9, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten, Sabotage-Patches) |
| bug.0.4.173 | – | Scroll-Auftrag: leere Namensliste beim Beginn gilt als unbekannt (Suchtreffer in zwischengespeichertem Ordner; Rest: `bug.0.4.180`) | 24.10. Host (seriell 1041/1041, eigene Tests parallel 3/3, Sabotage 9/9, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten, Sabotage-Patches) |
| bug.0.4.176 | – | Kleinkram: Merker am Laufende gekürzt, hängender Lesevorgang je Medium, Kommentar, tote Prüfung, heller Spinner | 24.10. Host (seriell 1041/1041, eigene Tests parallel 3/3, Sabotage 9/9, 0 Warnungen, App 0.4.0) | A C (Prüf-Agenten, Sabotage-Patches) |

**Doku erledigt (Claude 14.10.):** REPORT 38 (kein Fix, nur Zeitstempel), 40 (Messbericht), 41 (Layout-Reminder), README „Architektur“ und Abschnitt „Datenbank“ neu, ROADMAP abgeglichen, `datenbank-konzeption.md` und `todo-audit.md` aufgelöst (Archiv: `archiv/datenbank-konzeption-bis-2026-10-14.md`, `archiv/todo-audit-2026-10-13.md`), REPORT in `archiv/report-audit-2026-10-13.md`.

**0.3.8 abgenommen (Host 17.10.):** alle Kennungen der Pakete 4, 5a, 5b, 5c; Kriterien 1–6 und 8 erfüllt (seriell 645/645, parallel 3/3, 0 Warnungen, keine neuen `.ips`, Regel 23). Kriterium 7 (Stick-Test) folgt gesammelt in `todo.0.4.040`. Version setzt `todo.0.3.8.001`.

**0.3.9 abgenommen (Host 18.10.):** alle Kennungen der Pakete 6, 7, 8a, 8b; Kriterien 1–6 und 8 erfüllt (seriell 805/805, parallel 3/3 in drei Prüfungen hintereinander, 0 Warnungen, keine neuen `.ips`, Regel 23). Version setzt `todo.0.3.9.001`.

**Offen:** siehe [TODO.md](TODO.md).
