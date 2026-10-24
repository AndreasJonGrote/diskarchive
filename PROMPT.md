⚠ Worker: Rolle Worker. Minimum Sonnet 5.5 Medium – läuft die Sitzung darunter, sofort melden und anhalten.

Du bist Worker (AGENTS.md). **Wiederaufnahme von Paket 19** nach Abbruch (Commit `b59d991` „Abbruch nach Auth Issues“). Lies nur: `todo/regeln.md` (verbindlich) und `todo/paket-19.md`. Kein Git außer lesend.

**Stand laut Host (24.10., Prüfung `schnell` + `sabotage` auf `b59d991`):** Code und Tests zu `bug.0.4.177`, `178`, `179`, `180` (a–d) liegen vor. Debug mit Testziel 0 Warnungen; `EjectDuringRunTests`, `MountedMediumCheckTests`, `ScanDepthColumnLoadTests` grün; 9 Sabotage-Patches (177-a–d, 178, 179-a/b, 180-c/d) alle rot ✓. **Alle Status-Felder in `todo/paket-19.md` sind leer**, Rot-Belege und Selbstprüfung fehlen, Paketende-Läufe sind nicht gelaufen.

Zu tun, der Reihe nach (nichts neu bauen, was schon steht – erst lesen, dann ergänzen):
1. `diskindex/diskindex/Indexing/DirectoryIndexer.swift.orig` löschen (Patch-Rest, gehört nicht ins Repository).
2. Je Aufgabe 177 → 178 → 179 → 180 den Stand gegen die Vorgabe in `todo/paket-19.md` abgleichen und Lücken schließen. Bekannt offen: 177 dritte Gegenprobe (Auswurf während der Teil-Prüfsummen-Lesung mit leerem Einhängeordner → Favorit bleibt) – Test benennen oder schreiben; 178 Ursache im Status festhalten (App-Fehler oder Testaufbau) und Beleg „Suite 20× parallel grün“; 180 (a) und (b) haben noch **keinen Sabotage-Patch** – für (b) nachreichen (Verhaltensänderung), für (a) begründen, falls nur Testaufbau. `ColumnOpenAtSelectionTests` lief im gezielten Lauf nicht mit (verschachtelte Suite unter `WindowTestGroup`) – mit dem richtigen Filter laufen lassen.
3. Je Aufgabe: Rot-Beleg (Patch rot), Selbstprüfung per Subagent mit den fünf Fragen (Regel 12), mittlere und hohe Befunde beheben; dann Status (höchstens 5 Zeilen) mit „Bereit zur Prüfung“. Kann ein Test nicht rot werden: „Frage:“, nicht „Bereit“.
4. Paketende (Regel 13/14): Debug mit Testziel und Release 0 Warnungen, seriell und dreimal parallel grün, `Werkzeuge/pruefung.sh sabotage` alle rot, keine neuen `Disk Archive*.ips`, zum Schluss die App des Nutzers bauen.

HALT nach `bug.0.4.180`. Zum Schluss: Bericht mit Prompt für den Host und Commit-Nachricht (Regel 15); dann diese Datei durch die Kurzmeldung `Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.` ersetzen.
