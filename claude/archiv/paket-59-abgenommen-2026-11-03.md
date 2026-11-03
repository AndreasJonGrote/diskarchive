# Paket 59 — Zielversion 0.4.3 (freigegeben und abgenommen 03.11.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md). Pfade relativ zu `claude/`; Code, `layout/`, `Werkzeuge/` im Hauptverzeichnis. **Zweites von sechs Paketen für 0.4.3: Medien.** Vorlage: Layout 00 („Speichermedien und Namen“, „Auswerfen“), 04 (Kacheln, 04.07), 05 (Tabelle Speichermedien), 06 (06.01–06.03), 12 (Kontextmenü an Medien), 16, 19 („Kernkonzept“, „Festgelegt“). Konzept: `konzept/medien.md` 2d, `konzept/datenschutz-plattform.md` (Auswerfen).

**Für dieses Paket gilt:**
- **Texte nur aus `layout/App-Layout 20 Texte.json`** (Deutsch und Englisch). Die 7 Schlüssel mit `pendingPackage = 59` in `LayoutCopyTests` werden hier erledigt und aus der Liste genommen. Fehlt ein Text in 20: „Frage:“ (Regel 2).
- **Maße, Abstände, Schriftgrößen** aus dem Layout (Komponentenkatalog `layout/App: Komponenten.dc.html`, Styleguide 19, Zusammenfassung `docs/Komponenten-Masse.md`). Fade-Regel des Nutzers: Text so breit wie möglich, erst am Ende ausblenden – im Layout teils zu früh gesetzt, das nicht übernehmen.
- **Farben:** Türkis für benannte Medien `#00A5A8` (hell) / `#00D3D5` (dunkel und auf ausgewählten, invertierten Zeilen); Violett für Favoriten wie vorhanden `DesignColor.favorite` (`#9D69D2` / `#B98CEA`). Rot Fehler `#E04830` / dunkel `oklch(0.70 0.17 35)` wie vorhanden.
- **Der Medientyp steht nie als Text** (nur das Icon). Danach darf `type.displayName` in keinem sichtbaren Text mehr vorkommen (Test).
- **Icons:** alle Phosphor-Icons 2.1.1 liegen in `Werkzeuge/phosphor/` (Regel 4a); von dort nehmen, nichts laden, nicht fragen.
- Sabotage-Patch (Regel 9) je Verhaltensänderung. Läufe per `Werkzeuge/pruefung.sh schnell …` (ohne `S=`), kein Git.
- **So lassen:** Popover-Status, „Wird geprüft“, Ersetzen-Dialog (Paket 60); Spaltenansicht und Einstellungen › Dateien & Ordner (61); Banner, Über, Update (62). Metadaten und Vorschaubilder gibt es erst ab 0.5/0.6.

**Reihenfolge (HALT am Ende):** `todo.0.4.3.007` → `todo.0.4.3.008` → `todo.0.4.3.009` → `todo.0.4.3.010` → `todo.0.4.3.011`. **HALT.**

## Aufgaben

- **todo.0.4.3.007 — Namen und Farben der Medien überall:**
  - **Benannte Medien** (eigener Name gesetzt): Medien-Icon türkis. In jeder Liste – Popover (03), Seitenleisten (07 ff.), Tabelle Speichermedien (05), Suche (10, Medienkarten und Pfadspalte), Favoriten (11) – stehen beide Namen in einer Zeile: „{Eigener Name} · {Originalname}“, der Originalname leise (Farbe wie im Layout) und er läuft zuerst aus. In der Kachel steht der Originalname klein unter dem Namen (Aufgabe 008).
  - **Favorisierte Medien:** Medien-Icon überall violett (Seitenleisten, Kacheln, Tabellen, Details, Popover).
  - Ist ein Medium benannt **und** Favorit: Violett geht vor (Layout 19; sonst „Frage:“).
  - **Test:** Darstellungsdaten je Ort (Name, Zusatz, Icon-Farbe) für benannt / Favorit / beides / keins; Test, dass kein sichtbarer Text `type.displayName` enthält.
  - **Status:** Bereit zur Prüfung.
    - **Darstellung:** `Medium.listLabel`/`iconRole` (Fehler rot vor Favorit violett vor benannt türkis, auf Auswahl invertiert; `DesignColor.named`/`namedOnSelection`/`favoriteOnSelection`). `FadeMaskText` hat einen leisen Zusatz „ · Originalname“, der zuerst ausläuft; ist der eigene Name zu lang, verschwindet der Zusatz ganz.
    - **Orte:** Popover-Zeile, Seitenleiste (70 %), Tabelle Speichermedien, Suchkarten, Medienspalte in Suche und Favoriten (neu mit Icon 14). `MediumType.displayName` entfernt, `specLine` ohne Typ.
    - **Test:** `MediumListLabelTests` (Zustände, Farben, alle Listen nutzen `listLabel`, kein „HDD/SSD/USB“ als Text). Rot nur über den Patch belegt, der Test entstand nach dem Code. Patch `todo.0.4.3.007.patch`.

- **todo.0.4.3.008 — Kacheln neu (Layout 04, 04.07) mit bug.0.4.3.002:**
  - Aufbau laut 04: oben links Medien-Icon, oben rechts der eine Status-Chip; darunter Name, bei eigenem Namen klein darunter der Originalname; unten „{Kapazität} · {n} Dateien“ (ohne Typ; `Medium.specLine`, `dashboardSpecLine`), darunter „Zuletzt gesehen“ und bei angeschlossenen Medien die Belegung. Offline-Kacheln blasser, Fehler-Kacheln roter Rahmen, nichts bricht um. Pixelgenau nach 04.
  - **bug.0.4.3.002:** „Kein Zugriff, in den Systemeinstellungen freigeben“ entfällt als Kachel- und Popover-Zeile. Bei Fehler ohne Lücke steht „Fehler · erneut versuchen“; **„erneut versuchen“ ist ein Link** (Textfarbe, beim Hover unterstrichen, Hand-Cursor), der die Indizierung sofort neu startet wie „Erneut versuchen“ im Indizierungsfehler (14). Klick auf den Rest der Kachel öffnet weiter die Spaltenansicht. Bei „Fehler, offline“ kein Link. Popover-Zweitzeile bei Fehler laut 03/20.
  - „1 Dateien“ in der Ladeansicht (Paket 58, Frage 4): wieder aus Teilen mit „1 Datei“ aus 20 zusammensetzen.
  - **Test:** Zeilen je Zustand (online, offline, Fehler mit/ohne Lücke, ausstehend ohne Dateien), Link startet Neuindizierung, kein Link bei offline. Sabotage-Patch für bug.0.4.3.002.
  - **Status:** Bereit zur Prüfung.
    - **Kachel neu nach 04:** Innenabstand 12, Abstand 8, Rahmen `divider`, `--shadow-md`; Titel 17 fett, darunter der Originalname 11/50 %; „{Kapazität} · {n} Dateien“ 13/80 %; unten links Uhr „Zuletzt gesehen“ · Belegung. „Zuletzt indiziert“ entfällt in der Kachel, ausstehend ohne Dateien zeigt „0 Dateien“.
    - **bug.0.4.3.002:** „Kein Zugriff …“ entfällt (Kachel und Popover; Popover jetzt „Speichermedium fehlerhaft“ aus 03/20). Bei Fehler ohne Lücke „Fehler · erneut versuchen“; der Link (Hover unterstrichen) startet die Indizierung neu (`AppState.retryIndexing`). Bei „Fehler, offline“ kein Link.
    - **Ladeansicht:** „1 Datei“ aus den Teilen von 20 zusammengesetzt.
    - **Test:** `DashboardTileTests` grün 08:06; Patch `bug.0.4.3.002.patch`. `copy.medium.no_access` und `not_indexed_yet` gelöscht; `copy.indexed.line/never` gehören jetzt zu Paket 60 (nur noch Popover).

- **todo.0.4.3.009 — Benennen nur im Details-Fenster (`konzept/medien.md` 2d, Layout 06.02, 12):**
  - Das Bearbeiten an Ort und Stelle in Kachel und Seitenleiste (Paket 55: `MediumNameEditor` inline, `MediumNamingPlace.dashboardCard`/`.columnSidebar`) entfällt. „Benennen“ im Kontextmenü (nur an Speichermedien) öffnet überall das Details-Fenster **direkt im Benennungsmodus**: Fokus im Namensfeld, Text ganz markiert.
  - Namensfeld laut 06.02: ohne Rahmen, Stift direkt am Namen; Enter oder Häkchen übernimmt, Esc oder X bricht ab, leeres Feld stellt den Originalnamen wieder her. Klick auf den Stift startet den Modus ebenso.
  - Nicht mehr benutzten Code und Texte entfernen.
  - **Test:** Kontextmenü an Kachel, Seitenleiste, Tabelle, Suche → Details offen mit Fokus; Enter/Esc/leer. Sabotage-Patch.
  - **Status:** Bereit zur Prüfung.
    - **Entfernt:** `MediumNameEditor`, `MediumCustomNameField`, `MediumNamingPlace` und `namingPlace` im Kontextmenü, die Bearbeitung in Kachel und Seitenleiste, `copy.detail.custom_name`.
    - **Neu:** „Benennen“ ruft `beginNaming` auf: Details-Fenster offen, `namingMediumID` gesetzt. `MediumDetailNameEditor` (06.02): blauer Rand mit Ring, ✓/✗ (26 pt), Enter/✓ übernimmt, Esc/✗ bricht ab, leeres Feld stellt den Originalnamen her; Stift am Namen startet den Modus.
    - **Fenster zu im Modus:** endet ohne Übernahme.
    - **Test:** `MediumNamingTests` neu, 6 Tests: Menü, Enter, Esc, leer, kein Feld außerhalb des Modus, Sperre. Den Stift selbst klickt der Test nicht, er nutzt dieselbe Funktion. Patch `todo.0.4.3.009.patch` (2 Tests rot).

- **todo.0.4.3.010 — Details-Fenster neu (Layout 06.01, 06.03):**
  - Statt der Tabelle: Kennzahl-Flächen „Gesamt“, „Belegt“, „Frei“ (dreispaltig) und „Dateien“, „Ordner“ (zweispaltig); darunter die graue Index-Box mit dem Balken „Indiziert“ ({n} %) und „Soll indiziert werden“ (Ja/Nein); ganz unten „Zuletzt gesehen“ und „Zuletzt indiziert“ als zwei Flächen nebeneinander. Kopf: Icon auf Höhe des Namens, Chip rechts; keine zweite Kopfzeile (Paket 58 hatte „Online/Offline“ übergangsweise – laut 06 entfällt sie).
  - **Balken „Metadaten“ und „Vorschaubilder“ in 0.4.3 nicht zeigen** (kommen mit 0.5 und 0.6).
  - **06.03 Fehlergrund:** Solange der Status „Fehler“ ist, steht der Grund aus 14.03 dauerhaft unter dem Balken „Indiziert“; bei unbekanntem Grund keine Zeile. Der Grund muss dafür am Medium gespeichert sein (heute nur im Dialog/der Mitteilung) – in `storage_meta` oder vorhandenem Zustand, keine neue Tabelle.
  - „Ordner“-Anzahl aus dem Index; Knöpfe „Vergessen“, „Neu indizieren“, „Inhalt anzeigen“ wie bisher.
  - **Test:** Werte der Flächen, Fehlerzeile mit/ohne Grund, kein Typ. Sabotage-Patch für den gespeicherten Fehlergrund.
  - **Status:** Bereit zur Prüfung.
    - **Aufbau nach 06.01:** Kopf mit Icon auf Höhe des Namens, Chip und ✗ rechts, ohne zweite Kopfzeile (`connectionDescription` entfernt). Flächen Gesamt/Belegt/Frei und Dateien/Ordner, Index-Box mit Balken „Indiziert“, „Soll indiziert werden“, unten „Zuletzt gesehen“ und „Zuletzt indiziert“. Ohne Metadaten und Vorschaubilder.
    - **06.03 Fehlergrund:** als `storage_meta`-Schlüssel `failureReason`, geschrieben in `IndexingService.finish`: bei Fehler der Grund, bei gelungenem Lauf gelöscht. Eingelesen in `Medium.failureReason`, Zeile nur bei „Fehler“ und bekanntem Grund.
    - **Test:** `MediumDetailHeaderTests` (Werte, Fehlerzeile, gespeicherter Grund nach Neuladen). Patch `todo.0.4.3.010.patch`. Nicht getestet ist der Weg vom echten Lauf zu `setFailureReason`; das ist Stufe 3.

- **todo.0.4.3.011 — Auswerfen (`konzept/datenschutz-plattform.md`, Layout 04, 05, 12, 19) und Fehlerdialog 16:**
  - **Wo:** Kachel – beim Hover rechts neben dem Chip ausfahrender Eject-Knopf (Rahmen, beim Hover gefüllt, Textfarbe, nie grau); Tabelle Speichermedien – beim Zeilen-Hover links vom Chip; Kontextmenü an angeschlossenen Medien „Auswerfen“. **Nur bei angeschlossenen Medien**, nie in Seitenleisten und Medienspalten, **nie automatisch**.
  - **Was:** ein laufender Lauf des Mediums wird zuerst abgebrochen wie beim Abziehen, dann `NSWorkspace.unmountAndEjectDevice` (oder DiskArbitration). Danach ist das Medium offline wie nach dem Abziehen.
  - **Schreibschranke:** `ReadOnlyMediaGuardTests` verbietet `unmountAndEjectDevice`/`DADiskEject`/`DADiskUnmount`. Genau eine erlaubte Stelle (eigene Datei, z. B. `App/MediumEject.swift`) in die Ausnahme des Wächters aufnehmen, alle anderen Stellen bleiben verboten.
  - **Fehler:** Lehnt macOS ab (Medium in Benutzung), bleibt es angeschlossen und die App zeigt den **Dialog 16 „Unerwarteter Fehler“** (rotes Icon, Titel, Beschreibung, „Schließen“, optional Aktion rechts – Aufbau wie 15). Den Dialog jetzt als allgemeine Komponente bauen; Paket 62 nutzt ihn weiter. **Beschreibungstext für das Auswerfen fehlt in 20** → bis der Nutzer ihn ergänzt, „Frage:“ und Platzhalter-Schlüssel im Katalog, Vorschlag Host: „„{1}“ konnte nicht ausgeworfen werden. Ein anderes Programm benutzt es gerade.“ / „“{1}” couldn’t be ejected because another app is using it.“
  - **Test:** Auswerfen bricht Lauf ab und ruft genau die eine Stelle; offline/Seitenleiste ohne Knopf; Fehler zeigt 16; Wächter. Sabotage-Patch.
  - **Status:** Bereit zur Prüfung.
    - **Auswerfen:** einzige Stelle `App/MediumEject.swift` (`@concurrent`, `unmountAndEjectDevice`, nur auf Klick); Ausnahme im Wächter nur für diese Muster in dieser Datei. Icon `IconEjectSimple`, mit Erlaubnis des Nutzers von unpkg geladen.
    - **Ablauf:** `AppState.ejectMedium` bricht zuerst den Lauf ab (`onCancelBeforeEject` = `onWillUnmount`), wirft dann aus; ein Doppelklick wirft nicht doppelt aus. Lehnt macOS ab, erscheint Dialog 16 (`UnexpectedErrorDialog`, allgemein).
    - **Orte:** `EjectButton` an der Kachel (beim Hover rechts vom Chip, ausfahrend) und in der Tabelle (beim Zeilen-Hover links vom Chip), nur angeschlossen; im Kontextmenü nach „Als Favorit markieren“, offline ausgegraut.
    - **Test:** `MediumEjectTests` (Reihenfolge, offline, Ablehnung → 16, Doppelklick, Knopf nur an Kachel und Tabelle) und `ReadOnlyMediaGuardTests.ejectIsAllowedOnlyInItsOneFile`. Patch `todo.0.4.3.011.patch`.
    - **Stufe 2 (Selbstprüfung):** Lehnt macOS das Auswerfen während eines Laufs ab, läuft der abgebrochene Lauf erst beim nächsten Anlass weiter.
  - **Läufe:** 785 Tests in 154 Suites 08:38–08:45. 4 waren rot, weil sie Pixel am alten Aufbau maßen (Kachel-Zeitzeile, Seitenleiste mit eigenem Namen, Knopfhöhe im Details-Fenster); auf den neuen Aufbau umgestellt, danach 22 Tests in 6 Suites grün 08:47. Sabotage 08:47–08:50: rot 5/5, Mängel 0. Build 0 Warnungen.
  - **Frage:** Die Schrift Archivo (Kachel- und Fenstertitel 17/800 im Layout) liegt nicht in der App. Ich nehme System 17 fett. Soll Archivo eingebunden werden?
  - **Frage:** Fläche „Belegt“ (06.01): In 20 gibt es nur klein „belegt“/„used“. Vorläufig `copy.medium.used` „Belegt“/„Used“ (`openQuestions`). Bitte in 20 ergänzen?
  - **Frage:** Text für abgelehntes Auswerfen fehlt in 20. Vorläufig der Vorschlag des Hosts (`copy.eject.failed`, `openQuestions`). Bitte ergänzen.
  - **Frage:** Kachel bei Fehler: Die Aufgabe nennt „Fehler · erneut versuchen“, Layout 04 zeigt „Fehler vor {1} Std. · erneut versuchen“. Ich habe die Aufgabe umgesetzt. Welche Fassung gilt?
  - **Frage:** Wert „86 %“ im Details-Fenster (`copy.medium.indexed_value`, Zahlformat) steht nicht in 20 (`openQuestions`). Bleibt der Schlüssel?

## Korrektur Host 03.11. (Gesamtlauf 08:54–09:28 rot)

Build, Release, Sabotage 5/5 und App des Nutzers sind in Ordnung. Rot sind Tests außerhalb der Suites, die der Worker gelaufen ist:

- **K1 `DashboardCardWidthTests.cardsFillTheirCellsWithSixteenPointGaps`** – seriell und parallel 3× rot (68 Meldungen): Abstände zwischen den Kacheln 12–13 pt statt 16, erste Reihe 6,5 statt `DashboardGridLayout.spacing`, Breiten ungleich. **Nutzer sieht:** ungleichmäßige Abstände im Dashboard (Stufe 1). Ursache in der neuen Kachel suchen (z. B. Rahmen, Schatten oder der ausfahrende Auswerfen-Knopf verändern die gemessene Größe). Soll: wieder 16 pt wie in 04, Knopf und Hover-Schatten ändern die Kachelgröße nicht. Den Test **nicht** an die neuen Werte anpassen.
- **K2 `ReindexGateTests.buttonsLookDisabledDuringRun`** – seriell und parallel 3× rot: Im neuen Details-Fenster sehen die Knöpfe während eines Laufs nicht mehr gesperrt aus (`running.detail` 2,31, Ziel unter 1,73). **Nutzer sieht:** „Neu indizieren“ wirkt während einer Indizierung bedienbar (Stufe 1). Soll: gesperrte Knöpfe im neuen Details-Fenster wie bisher gedämpft.
- **K3 `UnreadableFoldersErrorTests.readableAgainOnRetryEndsTheErrorAndWithdrawsTheNotice`** – einmal rot (parallel 1: `indexingFailure?.reason` nil statt `.unreadableFolders`), sonst grün. Prüfen, ob das neue Speichern des Fehlergrunds (`failureReason` in `IndexingService.finish`) mit dem Ende des Fehlers in Konkurrenz steht. Nur beheben, wenn eine echte Ursache im neuen Code liegt (Stufe 2); sonst im Status begründen.
- **Danach** den ganzen Bestand an Pixel- und Layout-Tests laufen lassen, nicht nur die betroffenen Suites: `pruefung.sh schnell DashboardCardWidthTests ReindexGateTests UnreadableFoldersErrorTests` und alle Suites, deren Name `Dashboard`, `Detail`, `Card`, `Registry`, `Column` oder `Pixel` enthält.

**Antworten auf die Fragen:** (5) „86 %“ ist ein Zahlenformat, kein Text – `copy.medium.indexed_value` bleibt in `openQuestions`. (1) Archivo, (2) „Belegt“, (3) Text Auswerfen, (4) Fehlerzeile mit oder ohne Zeit: **warten auf den Nutzer**, nicht ändern; bis dahin so lassen, wie umgesetzt.

- **Status Korrektur:** Bereit zur Prüfung.
  - **K1:** Der neue Schatten der Kachel (`--shadow-md`) färbte Pixel außerhalb der Zelle, dadurch kleinere Abstände und je Zustand andere Breiten. Schatten entfernt, wie in der alten Kachel; Test unverändert und grün. Abweichung vom Layout (`elev-md`), bei Bedarf als Frage.
  - **K2:** Die Knöpfe sind weiter gedämpft (Kontrast frei 2,41, gesperrt und im Lauf 0,96). Rot war meine Änderung am Test in Paket 59: Sie suchte die Knopfzeile von unten und landete unter dem Fenster (y 440 statt 388–412). Die Suite lief in meinem Nachlauf nicht mit, weil sie in `WindowTestGroup` liegt. Jetzt Unterkante des Fensters suchen, 16 pt darüber. Gegenprobe ohne `.opacity(0.45)`: rot.
  - **K3:** echte Ursache im neuen Code. `await store.setFailureReason` stand zwischen Status „Fehler“ und `presentIndexingFailure`; der Test sah „Fehler“ ohne Hinweis. Speichern jetzt nach dem Hinweis. `UnreadableFoldersErrorTests` 20× parallel 11:02: 0 Fehler. Stufe 2, der Nutzer merkt es nicht.
  - **Lauf 10:58–10:59:** 140 Tests in 42 Suites grün (alle mit Dashboard/Detail/Card/Registry/Column/Pixel im Namen, dazu `ReindexGateTests` und `UnreadableFoldersErrorTests`), 0 Warnungen.

## Abnahme Host 03.11. (Gesamtlauf 11:07–11:40)

- Diff gelesen (Paket und Korrektur): Namen und Farben über `Medium.listLabel`/`iconRole` an allen Listen, `MediumType.displayName` entfernt; Kacheln neu mit Link „erneut versuchen“; Benennen nur im Details-Fenster (`MediumDetailNameEditor`); Details-Fenster mit Flächen, Balken „Indiziert“ und gespeichertem Fehlergrund (`storage_meta` `failureReason`); Auswerfen nur in `App/MediumEject.swift`, Wächter-Ausnahme nur dort, Dialog 16 als allgemeine Komponente. Eject-Icon gleich `Werkzeuge/phosphor/regular/eject-simple.svg`. Korrektur: K1 Schatten der Kachel entfernt, K2 Fehler im eigenen Test, K3 Fehlergrund erst nach dem Hinweis gespeichert. Nichts Wesentliches.
- Erster Gesamtlauf 08:54–09:28 rot (K1–K3), zweiter grün: Debug und Release 0 Warnungen, seriell 1286/1286, parallel 3× grün (je 1279, 7 übersprungen), keine `.ips`, 0 neue Dateien in `~/Library/Preferences`, Sabotage 5/5 rot ✓, App des Nutzers 11:39:57, Version 0.4.2.
- **Offen beim Nutzer (nicht blockierend, Stand wie umgesetzt):** Schrift Archivo für Titel; „Belegt“ in 20; Text für abgelehntes Auswerfen in 20 (vorläufig Vorschlag Host, `copy.eject.failed`); Fehlerzeile der Kachel mit oder ohne Zeit („Fehler vor {1} Std. · erneut versuchen“, Layout 04).
- **Stufe 3 (Backlog):** Hover-Schatten der Kachel (Layout 04) entfällt; ließe sich ohne Einfluss auf die Kachelgröße zeichnen.
- Nachtest des Nutzers: Kacheln (benannt, Favorit, Fehler mit Link, offline), Benennen über Kontextmenü, Details-Fenster, Auswerfen (auch mit offener Datei auf dem Medium).
