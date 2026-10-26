# Lauf-Lebenszyklus je Medium (Stand nach bug.0.4.204, Host 26.10.2026)

Quelle: `IndexingService.swift` (Stand nach Paket 29) und die Aufrufer in `LiveWiring.swift` und `MediumCoordinator.swift`. Diese Tabelle ist der **Maßstab für Prüf-Agenten** (`archiv/abnahme-ablauf.md` 2.3): Ein Fund zum Ablauf eines Laufs ist eine Abweichung des Codes von dieser Tabelle oder eine Zeile, die hier fehlt. Kommen danach an dieser Stelle noch Befunde, folgt der Umbau zum vollen Zustandsautomaten.

## Grundregel

Je Medium gibt es **höchstens einen** Lebenszyklus „Start → Lauf → Abschluss bzw. Abbruch“ (`lifecycles[id]`). Den Schlussmarker (`closing`) setzen `finish` und `cancel` **vor** der Freigabe des Laufs. Gelöst wird er erst als allerletzter Schritt (`endLifecycle`): Er startet einen wartenden Start und setzt jede wartende Fortsetzung genau einmal fort. `finish` und `cancel` warten nie selbst auf den Marker. In DEBUG prüft ein Wächter die Regel (`guardLifecycle`, `assertionFailure`). Release enthält diese Prüfung nicht.

## Zustände

| Zustand | Erkennbar an | Zusatzmerker, die es nur hier gibt |
|---|---|---|
| **Frei** | kein `lifecycles[id]` | – |
| **Läuft** | `lifecycles[id]`, `closing == false`, `runs[id] == token` | `rerunAfterFinish` (Nachhol-Abgleich); wartender Start nur beim Neustart von vorn |
| **Abschluss** | `closing == true`, in `finish` | wartender Start (`startsWaitingForCancel`), `abortedWhileClosing` |
| **Abbruch** | `closing == true`, in `cancel` | wartender Start, `abortedWhileClosing` |

`isRunActive` ist wahr in Läuft, Abschluss und Abbruch, außerdem bei einem wartenden Start. `activeMediumUUIDs` sind alle Medien mit Lebenszyklus.

## Zustand × Ereignis

**Vor jedem Start gilt:** Die Sperre ist gesetzt → Start abgelehnt (`rejectStart`: Anforderung und „Neu indizieren“ frei).

### 1. Start, Abgleich (Anschließen, Überwachung, Entscheidung „Ja“, Pausenende)

| Zustand | Was passiert |
|---|---|
| Frei | Abgelehnt bei Pause, Schlaf, pausiertem Medium oder Entscheidung ≠ „Ja“. Sonst → **Läuft**. Die Sperre des Vollabgleichs fällt. |
| Läuft | `rerunAfterFinish` merken. |
| Abschluss / Abbruch | Wird wartender Start (zusammengeführt). |

### 2. Start von vorn („Neu indizieren“, Regeländerung)

| Zustand | Was passiert |
|---|---|
| Frei | Wie bei 1 → **Läuft**. |
| Läuft | Wartender Start „von vorn“, dann `cancel` → **Abbruch**. |
| Abschluss / Abbruch | Wird wartender Start; `fromScratch` wird per ODER zusammengeführt. |

### 3. Lauf endet (Indexer fertig, `finish`)

| Zustand | Was passiert |
|---|---|
| Frei | – |
| Läuft | → **Abschluss**. Dabei der Reihe nach: Status aus dem Speicher (sonst aus dem Ergebnis), Hinweis, Überwachung, Nachhol-Abgleich (Einzelheiten unter der Tabelle). Danach → **Frei**. |
| Abschluss | – |
| Abbruch | Spätes `finish` des abgebrochenen Tasks: `guard runs[id] == token` greift, nichts passiert. |

So läuft der Abschluss im Einzelnen:
- **Status:** Er kommt aus dem Speicher, sonst aus dem Ergebnis. Die Anzeige wird immer neu bestimmt, nie „wird indiziert“ des alten Laufs.
- **Hinweis:** Nur wenn alles zutrifft:
  - Der Lauf endet mit `.error`.
  - Es ist kein stiller Abgleich mit bleibender Lücke.
  - Der Lauf wurde nicht unterbrochen.
  - Die Entscheidung ist „Ja“ und `allowIndexing` ist an.
  - Das Medium ist angeschlossen und eingehängt.
- **Überwachung:** Nach einem Lauf bis zum Ende, wenn das Medium eingehängt ist. Sie wird übergeben statt gestartet, wenn ein Start wartet oder `abortedWhileClosing` gesetzt ist. Nach einem gescheiterten Lauf läuft sie mit der Sperre des Vollabgleichs.
- **Nachhol-Abgleich:** Ist `rerunAfterFinish` gesetzt, wird er zum wartenden Start. Die Überwachung läuft neben ihm weiter, bewusst so (Paket 29).
- **Ende:** `endLifecycle` startet einen wartenden Start nur, wenn das Medium eingehängt ist; sonst wird er verworfen.

### 4. Abbruch (Aushängen, Sperre, „Nein“, Vergessen, Umbenennen, Neustart von vorn)

| Zustand | Was passiert |
|---|---|
| Frei | – |
| Läuft | → **Abbruch**: Anforderung und `rerunAfterFinish` fallen weg, der Task wird abgebrochen, der Status davor wird wiederhergestellt (eine unbestätigte Art wird gegen den Speicher geprüft), dann wird auf den Task gewartet. Danach → **Frei**, ein wartender Start nur, wenn das Medium eingehängt ist. |
| Abschluss / Abbruch | `abortWhileClosing`: kein Nachhol-Abgleich, keine Überwachung. Der Endstand bleibt. Gewartet wird, bis der Zustand **Frei** ist. Ein wartender Start bleibt bestehen. |

Was das Ereignis danach tut (`LiveWiring`):

| Ereignis | Danach |
|---|---|
| Aushängen | Vor dem `cancel` den wartenden Start verwerfen (`discardWaitingStart`). |
| Sperre | Einen unterbrochenen Vollabgleich fürs Entsperren merken. |
| „Nein“ | Überwachung stoppen, dann `endFailureAfterDecline` (Konzept 2b). |
| Vergessen | Überwachung stoppen, `cancel`, dann `forget`. |
| Umbenennen | `cancel`, wenn ein Lauf aktiv ist, dann neu starten mit dem neuen Volume. |

### 5. Pause an (global)

| Zustand | Was passiert |
|---|---|
| Frei | – (ein späterer Start wird abgelehnt) |
| Läuft | Das Medium kommt in `pauseIDs`. Der Indexer hält an (`.pause`), dann `finish` mit „unterbrochen“: Der Status bleibt, kein Hinweis. |
| Abschluss / Abbruch | `abortWhileClosing`. |

### 6. Pause aus

| Zustand | Was passiert |
|---|---|
| Frei | `resumePausedRuns`: Für jedes angeschlossene, nicht pausierte Medium ohne Task wird der Speicher gelesen, dann Start wie bei 1. |
| Läuft | – |
| Abschluss / Abbruch | Der Start aus `resumePausedRuns` wird zum wartenden Start. |

### 7. Kabel gezogen (ohne `willDisappear`)

| Zustand | Was passiert |
|---|---|
| Frei | – |
| Läuft | Der Lauf endet bzw. scheitert, dann `finish`. `isStillMounted` ist falsch: kein Hinweis, keine Überwachung. |
| Abschluss / Abbruch | `endLifecycle` verwirft den wartenden Start (`isStillMounted` ist falsch). |

### 8. App beenden

In jedem Zustand werden zuerst wartende Starts, Neustarts von vorn und `rerunAfterFinish` gelöscht. Dann:

| Zustand | Was passiert |
|---|---|
| Frei | – |
| Läuft | Der Lebenszyklus endet sofort (`.terminates`), Wartende laufen weiter. Der Task wird abgebrochen. |
| Abschluss / Abbruch | `abortedWhileClosing`; der Lebenszyklus endet von selbst. |

## Übergabe Lauf → Überwachung

`onRunIndexed` → `LiveWiring.startWatching`. Vor dem Lesen des Speichers prüft es Sperre und Pause. Aus dem Speicher prüft es die Entscheidung „Ja“. Nach dem letzten `await` (K5, Paket 29) prüft es gegen den aktuellen `AppState`:
- Sperre
- Pause
- Medium bekannt
- Entscheidung „Ja“ und `allowIndexing`
- angeschlossen

Den Flush der Überwachung hält `isRunActive` zurück, solange ein Lebenszyklus oder ein wartender Start besteht.

**Offen (Paket 30, `bug.0.4.205`):** Die beiden anderen Startwege der Überwachung, `ChangeWatcher.applyPause` (Pausenende) und `restartWatchIfConnected`, prüfen nach dem `await` noch nicht gegen den `AppState`. Nach Paket 30 gibt es eine Prüfstelle für alle drei Wege.
