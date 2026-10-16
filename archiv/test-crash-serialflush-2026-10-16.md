# Test-Host-Crash: serialFlushWhileBlockedReadsBothFolders (16.10.2026)

## Kurz

| Feld | Wert |
|------|------|
| **Prozess** | `Disk Archive` + `diskindexTests` (Xcode-Test-Host, kein Nutzerstart) |
| **Zeit** | 2026-10-16 09:06 und 09:11 (CEST) |
| **Builds** | `202610160903`, `202610160908` |
| **Exception** | `EXC_BAD_ACCESS` / `SIGSEGV` @ `0x10` |
| **Incident-IDs** | `3F3ACBF3-7320-4039-9F0C-5F24AD3F9510`, `6F7D798E-A177-44CA-96A7-4BF9D87E76EF` |
| **Produkt-App** | **Nicht betroffen** |

## Auslöser

Test `WatcherFlushReproTests.serialFlushWhileBlockedReadsBothFolders` (Repro Flush bei blockiertem ersten `listDirectory`).

**Stack (Thread 0):** `objc_msgSend` → `Dictionary._Variant.lookup` → Closure in `WatcherFlushReproTests.swift:90` → `waitUntil` (`SurfaceTestSupport.swift:313`) → Swift Testing.

## Ursache

**Data Race** in `GatedMapAccess`: Der MainActor pollt in `waitUntil` das Dictionary `listCount`, während `ChangeWatcherEngine` parallel in `listDirectory` dasselbe Dictionary ohne Synchronisation schreibt. Unter Suite-Last → korruptes Dictionary → Absturz beim Lookup.

Nebenthreads zeigen erwartetes `ChangeWatcher.flush` / `processPending` (Watcher-Logik), nicht die Crash-Ursache.

## Fix (16.10.2026)

1. **`GatedMapAccess`:** `listCountStorage` + `NSLock`, Lesen über `listCount(for:)`.
2. **`waitUntil`:** Nach Timeout `return false` (kein erneuter `condition()`-Aufruf → kein Hänger).
3. **Test-Setup:** `globalAutoIndexPaused = false`, DEBUG-Delays zurücksetzen, längere Timeouts.
4. **Nachzüger:** `MapAccess` gleiche Lesesperre; `isBlockingFirstList` unter Lock.

## Verifikation

- Seriell 610/610, 2× Parallel grün (nach Fix).
- Keine neuen `Disk Archive*.ips` nach grünen Läufen.

## Bezug Roadmap

Test-Infrastruktur zu **bug.0.4.019/022** (Watcher-Flush-Repro), **kein** neues `bug.*` für Produktcode.
