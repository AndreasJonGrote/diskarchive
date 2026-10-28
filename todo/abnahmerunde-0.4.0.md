# Checkliste Abnahmerunde 0.4.0 (`todo.0.4.040`, Nutzer)

Erst, wenn alle anderen Kennungen von 0.4.0 abgenommen sind (zuletzt Paket 33, Umbau „ein Ordner“). Geschrieben vom Host 25.10. (`todo.0.4.045`). Funde schreibst du einfach in den Chat, der Host macht daraus `bug.0.4.xxx`.

## Vorher

1. Reste von vor dem Umbau „ein Ordner“ (`bug.0.4.208`) löschen. Seitdem liegt alles in `~/Library/Application Support/Disk Archive/`, und Tests schreiben nichts mehr in die Voreinstellungen.
   - Alte Test-Einstellungen: `rm ~/Library/Preferences/app.diskarchive.tests.*.plist`
   - Alter Protokollordner: `rm -r ~/Library/Logs/Disk\ Archive`
   - Danach **den Mac einmal neu starten**. Dann vergisst der Einstellungsdienst (`cfprefsd`) die gelöschten Test-Domänen.
   - `~/Library/Preferences/app.diskarchive.plist` bleibt. Nach dem ersten Start der neuen App stehen darin nur noch Sprache (`AppleLanguages`) und Fensterposition. Zum Nachsehen: `defaults read app.diskarchive`. Steht dort noch ein Schlüssel mit `diskindex.` oder `lastIntegrityCheck`, schreib es in den Chat.
   - Die App setzt nach dem Umbau Pause, Sprache und „Mitteilungen erfragt“ einmal auf den Anfang. Das ist gewollt, es gibt keine Übernahme.
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

- [x] (27.10., Funde → Paket 36) Alle Ansichten gegen `layout/` hell und dunkel (Dashboard, Spalten, Suche, Favoriten, Einstellungen, Details, Dialoge, Menüleiste). Abweichungen per Screenshot.

## 4. Nachtest nach den Paketen 34–36 (27.10.)

Mit der App vom letzten Gesamtlauf (gebaut 27.10. 13:20) und nach einem Neustart der App.
- [ ] **Fortschritt (`bug.0.4.210`):** Nachtest 27.10.: bestanden bis auf 1 % Versatz nach dem Wiedereinstecken → `bug.0.4.222`, abgenommen 27.10. (Paket 37). **Bitte jetzt nachtesten** (App 28.10. 01:35).
  - Stick mitten im Lauf abziehen: kein Sprung auf 100 %, offline derselbe Wert wie zuletzt online.
  - Wieder anstecken: Er beginnt beim gespeicherten Stand, nicht bei 0 %.
  - „Neu indizieren“ beginnt unten, nicht bei 99 %.
- [ ] **Dialoge (`209`, `216`):** Nachtest 27.10.: Fokus nicht bestanden → `bug.0.4.221`, Stapel nicht bestanden → `bug.0.4.223`. Beide wurden am 28.10. mit Paket 38 abgenommen. **Bitte jetzt nachtesten** (App 28.10. 01:35, vorher neu starten).
  - Während du in einer anderen App schreibst, ein Medium einstecken: Der Dialog nimmt den Fokus einmal. Ein Klick zurück in die andere App legt ihn dahinter, danach bleibt der Fokus dort.
  - Zwei oder drei Medien kurz nacheinander: Der älteste Dialog liegt hinten links oben, jeder neue nach rechts unten versetzt darüber. Der neueste liegt vorn und hat den Fokus.
  - Das Hauptfenster liegt hinter der anderen App: Es bleibt dort, nur der Dialog kommt nach vorn.
  - Einen Dialog mit X schließen, das Medium auswerfen und wieder einstecken: Der Dialog erscheint wieder.
- [x] **Ersetzen (`215`):** Nachtest 27.10. bestanden. Stick mit gleichem Namen neu formatieren → zuerst nur „Ersetzt dieses Medium?“.
- [x] **Spaltenansicht (`212`–`214`):** Nachtest 27.10. bestanden.
  - Filter offen, Spalte scrollt.
  - → öffnet einen Ordner, ← geht zurück.
  - Eine ausgewählte Datei im Finder verschieben → Auswahl weg, Ansicht bleibt.
- [x] **Layout (`211`, `217`–`220`), hell und dunkel:** Nachtest 27.10. bestanden.
  - Dashboard-Kacheln gleich breit.
  - Nur die gezogene Spalte ändert ihre Breite, ohne Ruckeln.
  - Seitenleiste, Offline-Leiste und Details in einem Grauton.
  - Fußzeilenpfad bündig mit dem Ordner-Icon, auch nach dem Ziehen der Seitenleiste.
  - Spinner klein (12 pt).

## Danach

Fehlerbericht über die App senden, falls etwas auffiel. Sind alle Funde behoben und abgenommen, ist 0.4.0 der Release-Kandidat.
