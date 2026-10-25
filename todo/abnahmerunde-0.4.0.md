# Checkliste Abnahmerunde 0.4.0 (`todo.0.4.040`, Nutzer)

Erst, wenn alle anderen Kennungen von 0.4.0 abgenommen sind (zuletzt Paket 29). Geschrieben vom Host 25.10. (`todo.0.4.045`). Funde schreibst du einfach in den Chat, der Host macht daraus `bug.0.4.xxx`.

## Vorher

1. Alte Test-Dateien löschen (Rest des letzten Testlaufs, harmlos):
   `rm ~/Library/Preferences/app.diskarchive.tests.*.plist`
2. Die App aus `DerivedData/…/Build/Products/Debug/` starten (der Host nennt dir den Stand), Version 0.4.0.
3. **Alle Medien neu indizieren** (Einstellungen → Speichermedien → „Neu indizieren“), damit nichts aus alten Läufen mitspielt.

## 1. Große Platte (rund 2 Mio. HTML-Dateien)

- [ ] Vollständig indizieren. Zeit notieren. Fortschritt steigt stetig, springt nicht zurück, bleibt bis zum Ende unter 100 %.
- [ ] Suchen (Name, Filter), Spaltenansicht in großen Ordnern: flüssig, keine Hänger.
- [ ] Ab- und wieder anstecken: Status Offline, dann Online, kein neuer Volllauf von vorn.
- [ ] Live-Änderung: Datei anlegen, umbenennen, löschen → erscheint bzw. verschwindet.

## 2. Gleichzeitig: SD-Karte, USB-Stick, SSD

- [ ] Alle drei gleichzeitig anstecken: Erkennungsdialoge gestapelt, je Medium einer, ältere nach links oben.
- [ ] Alle drei indizieren lassen, dabei eins abziehen: die anderen laufen weiter, das abgezogene zeigt „x % indiziert, offline“.
- [ ] Großer Ordner auf dem Stick: Pfeiltasten, Mehrfachauswahl, Rechtsklick.
- [ ] Rückfrage „Ersetzt dieses Medium?“ (z. B. Stick neu formatieren, gleicher Name) samt Texten.
- [ ] Ein Volume im Finder umbenennen → Name in der App folgt.
- [ ] **Gegenprobe `bug.0.4.141`:** Datei als Favorit markieren, auf dem Medium in einen anderen Ordner verschieben, während der Abgleich läuft das Medium abziehen, wieder anstecken → Favorit ist noch da.
- [ ] **`bug.0.4.199`:** zuerst im Finder die SSD auswählen → Informationen → unten „Eigentümer auf diesem Volume ignorieren“ **ausschalten** (externe Volumes haben das oft an, dann greift „Keine Rechte“ nicht); dann einen Ordner auf der SSD (APFS oder Mac OS Extended; FAT/exFAT-Sticks kennen keine Rechte) unlesbar machen (Finder → Informationen → Freigabe & Zugriffsrechte: „Keine Rechte“ für alle), neu indizieren → Chip „Fehler“, Grund „Einige Ordner … nicht gelesen“, Details „Indiziert 99 %“; Rechte zurück, abziehen und anstecken → Online, „Indiziert 100 %“; danach „Eigentümer ignorieren“ wieder so einstellen wie vorher.

## 3. Layout-Durchgang

- [ ] Alle Ansichten gegen `layout/` hell und dunkel (Dashboard, Spalten, Suche, Favoriten, Einstellungen, Details, Dialoge, Menüleiste). Abweichungen per Screenshot.

## Danach

Fehlerbericht über die App senden, falls etwas auffiel. Sind alle Funde behoben und abgenommen, ist 0.4.0 der Release-Kandidat.
