# Konzept: Regelliste Artefakte (Spezifikation)

Teil des Konzepts, ausgelagert aus [README.md](../README.md) am 23.10.2026 (gilt unverändert; bei Widerspruch zum Layout gilt das Konzept, außer reine Optik).

# Regelliste Artefakte (Spezifikation)

**Immer ausgeschlossen** (unabhängig von allen Schaltern, nicht Teil der Artefakt-Regelliste): `.Spotlight-V100`, `.fseventsd`, `.Trashes`, `System Volume Information`, außerdem im Code `.TemporaryItems`, `.DocumentRevisions-V100` und `._*`. Grund: Zugriffsfehler, riesige Systembäume, Datenschutz. **Eigene Ausschlüsse** des Nutzers (Chips, Kontextmenü): Voreinstellung leer.


```
KONZEPT: ARTEFAKTDATEIEN IGNORIEREN
Disk Index, Stand 01.10.2026
===================================================================

1. ZIEL
-------------------------------------------------------------------
Eine kuratierte, schreibgeschützte Regelliste ("Artefaktdateien"), die
per Schalter aktiviert wird und typischen Müll (temporäre Dateien,
Backups, Systemreste, Abhängigkeits- und Cache-Ordner) vom Indexieren
ausschließt. Sie ergänzt die individuellen Ausschlüsse des Nutzers,
ersetzt sie aber nicht.

2. GRUNDREGELN
-------------------------------------------------------------------
- "Ignoriert" bedeutet NICHT INDEXIERT. Ein ignorierter Ordner wird
  nicht betreten (ganzer Teilbaum übersprungen). Es gibt keine Zählung,
  keine Größenmessung und keine Statuszeile "x GB übersprungen".
- Keine Regelliste in der UI. Der Schalter erklärt sich über einen
  kurzen Info-Text (siehe Abschnitt 8).
- Eigene Ausschlüsse und Artefaktregeln addieren sich (Vereinigung).
- Ausnahme-Möglichkeit: ein Pfad kann trotzdem eingeschlossen werden,
  damit ein einmal ignorierter Ordner nicht unauffindbar wird.
- Der Artefaktschalter ist standardmäßig AN.
- Nicht Teil der Regelliste: Systemordner, die die App IMMER auslässt, auch
  bei Artefakte aus und Unsichtbare an (.Spotlight-V100, .fseventsd,
  .Trashes, System Volume Information und weitere, siehe README,
  Abschnitt „Immer ausgeschlossen“).

3. ABGLEICH
-------------------------------------------------------------------
- Case-insensitiv durch Kleinschreibung auf BEIDEN Seiten: Dateiname
  aus dem Dateisystem und Muster aus der Regelliste werden vor dem
  Vergleich in Kleinschreibung umgewandelt.
- Unicode-Kleinschreibung, locale-unabhängig (keine Sprachregeln wie
  türkisches i).
- Folge: Die Regelliste enthält pro Eintrag nur eine Schreibweise
  (kleingeschrieben). Das Verhalten ist auf APFS, HFS+, NTFS, exFAT und
  case-sensitiven Volumes identisch.
- Zwei Regeltypen, in der Liste sichtbar unterschieden:
    EXAKT   Name muss vollständig übereinstimmen   (node_modules)
    MUSTER  Platzhalter * am Anfang ODER Ende      (*.tmp, .git*, ._*)
- Wildcard-Regeln (bewusst minimal):
    * steht für beliebig viele Zeichen, auch null.
    Genau ein * pro Muster, nur ganz am Anfang (Endungs-Muster) oder
    ganz am Ende (Präfix-Muster). Kein * in der Mitte, kein ? und
    keine []-Klassen.
    Verglichen wird nur der Datei-/Ordnername, nie der Pfad.
    Endungs-Muster immer MIT Punkt und OHNE Wildcard dahinter:
    *.part trifft, *.part* NICHT verwenden (würde Split-Archive wie
    archiv.part1.rar mitnehmen).
- Regeln gelten für Datei- UND Ordnernamen. Trifft eine Regel einen
  Ordner, wird der gesamte Teilbaum übersprungen.
- Sonderzeichen: "icon" + Wagenrücklauf (\r) muss das Steuerzeichen
  tatsächlich enthalten. In der Anzeige lesbar darstellen, z. B.
  "Icon (Ordnericon)".

4. VERHÄLTNIS ZUM SCHALTER "UNSICHTBARE DATEIEN"
-------------------------------------------------------------------
Dateien/Ordner mit Punkt am Anfang steuert der eigene Schalter
"Unsichtbare Dateien". Die Kategorie "Unsichtbare Artefakte" ist Teil
des Artefaktschalters und greift auch dann, wenn unsichtbare Dateien
eingeschaltet sind:

  Unsichtbare Dateien | Artefaktdateien | Ergebnis
  --------------------+-----------------+--------------------------------
  aus                 | an oder aus     | alle Punkt-Namen draußen
  an                  | an              | Punkt-Namen drin, außer Sammlung
  an                  | aus             | wirklich alles drin

Klarstellung: zwei unabhängige Filter mit unterschiedlichem Ziel
  - "Unsichtbare Dateien auslassen" zielt auf die EIGENSCHAFT:
    Dateien/Ordner, die unsichtbar sind (Punkt am Anfang). Es ist ein
    pauschaler Filter, der jede Datei dieser Art trifft, unabhängig
    davon, was sie ist.
  - "Artefaktdateien (Müll) auslassen" zielt auf BEKANNTE ARTEFAKTE
    nach Best Practice: eine kuratierte Liste, die sichtbare UND
    unsichtbare Einträge enthält (z. B. .tmp, node_modules, .ds_store,
    .git).
  - Es gibt eine gewollte Überschneidung: unsichtbare Artefakte wie
    .ds_store, .git oder .venv werden von BEIDEN Filtern erfasst. Ein
    Element wird ausgelassen, sobald EIN aktiver Filter es trifft.
  - Praktische Folge: Wer "Unsichtbare Dateien" einschaltet, bekommt
    seine eigenen unsichtbaren Dateien (z. B. .env, .vscode), aber
    nicht den bekannten Müll, solange der Müll-Filter an ist.

5. KATEGORIEN UND REGELN
-------------------------------------------------------------------
Hauptschalter schaltet alle Kategorien zusammen. Einzelne Kategorien
abschaltbar zu machen ist optional (für v1 nicht nötig).
Typ: E = exakt, M = Muster

5.1 Temporäre Dateien
  M  *.tmp
  M  *.temp
  M  *.swp
  M  ~$*              (Office-Lockfiles)
  M  *.crdownload     (Chrome)
  M  *.part           (Firefox, Chrome)
  M  *.partial
  M  *.download       (Safari)
  M  *.opdownload     (Opera)
  M  *.log

5.2 Backup- und Autosave-Dateien
  M  *~               (deckt auch *.psd~ und andere Tilde-Backups ab)
  M  *.bak
  M  *.orig
  M  *.autosave

5.3 System-Müll (nicht unsichtbar benannt)
  E  thumbs.db
  E  ehthumbs.db
  E  desktop.ini
  E  $recycle.bin
  E  icon\r           (macOS-Ordnericon-Datei, Name endet auf \r)

5.4 Abhängigkeitsordner
  E  node_modules
  E  pods
  E  __pycache__
  E  deriveddata
  E  lib-cov

5.5 Unsichtbare Artefakte (Punkt-Namen, immer ignoriert)
  Versionsverwaltung:
  M  .git*            (.git, .gitignore, .gitattributes, .gitmodules,
                       .gitkeep; .github wird mitgetroffen, bewusst)
  E  .svn
  E  .hg
  Build und Cache:
  E  .venv
  E  .cache
  E  .next
  E  .nuxt
  E  .gradle
  E  .parcel-cache
  E  .turbo
  E  .pytest_cache
  E  .mypy_cache
  E  .sass-cache
  macOS:
  E  .ds_store
  M  ._*              (AppleDouble-Reste, v. a. auf exFAT/FAT32)
  E  .appledouble
  E  .lsoverride
  M  .trash-*         (Linux-Laufwerke: .Trash-1000)
  E  .trash
  E  .temporaryitems
  E  .documentrevisions-v100

6. BEWUSST NICHT IN DER LISTE
-------------------------------------------------------------------
- *.csv, *.gz, *.dat, *.out: echte Nutzerdaten.
- logs, results (Ordner): zu generisch bzw. projektabhängig. (*.log
  ist dagegen drin, siehe 5.1; npm-debug.log ist dadurch abgedeckt.)
- build, dist, out, target: zu generisch. Falls später gewünscht, nur
  mit Marker-Check (z. B. dist nur neben package.json).
- .env*: Konfiguration/Zugangsdaten, die man beim Aufräumen finden will.
- .vscode, .idea, .github (als Ziel): Projekt-/Nutzerdaten. .github
  wird nur als Nebeneffekt von .git* getroffen.

7. OFFENE PUNKTE
-------------------------------------------------------------------
- Kategorien einzeln abschaltbar (v1 oder später).
- Marker-Check für build/dist/out/target (v1 weglassen empfohlen).

8. TEXTE FÜR DIE SETTINGS
-------------------------------------------------------------------
Schalter-Titel:
  Artefaktdateien ignorieren

Info-Text (eine Zeile, keine Regelliste in der UI):
  Ignoriert temporäre Dateien (.tmp, .part, .log), Backups (~),
  Systemreste (Thumbs.db) und Ordner wie node_modules oder .git.

```

---
