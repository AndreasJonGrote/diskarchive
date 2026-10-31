# Lokalisierung (DE / EN)

Stand: 06.10.2026. Ziel: **macOS-App-Standard** (String Catalogs, `InfoPlist`-Lokalisierung, App-Sprache unabhängig von der Systemsprache nach Nutzerwahl).

## Ist-Zustand

| Bereich | Status |
|--------|--------|
| **Erststart** | `AppDisplayLanguage.resolveFromOperatingSystem()` — bevorzugte Systemsprache `de*` → Deutsch, `en*` → Englisch, sonst Englisch. Wert wird in `AppSettings.displayLanguage` gespeichert. |
| **Anwendung** | `AppLanguagePolicy` setzt `UserDefaults` › `AppleLanguages` und **`activeDisplayLanguage`** für `L10n`. Catalog-UI **sofort**; System-/Bundle-Reste ggf. nach **Neustart** (Layout 05). |
| **Einstellungen** | `SettingsLanguagePicker` über **`Binding.appSettingsField(\.displayLanguage)`** (Struct-Rückschreiben in `AppSettings`). Speichern **sofort** bei Sprachwechsel (`syncFromSettings`). |
| **UI-Texte** | **`LayoutCopy`** → **`Localizable.xcstrings`**. **`L10n`** nutzt `AppLanguagePolicy.resolvedDisplayLanguage()`. Hauptfenster + Popover: **`.id(displayLanguage)`** für Neuaufbau. |
| **System-Dialoge** | `InfoPlist.xcstrings` — `NSRemovableVolumesUsageDescription` DE/EN. |
| **Xcode** | `LOCALIZATION_PREFERS_STRING_CATALOGS`, `SWIFT_EMIT_LOC_STRINGS`, `STRING_CATALOG_GENERATE_SYMBOLS` bereits aktiv. |
| **Hilfs-API** | `L10n.string` / `L10n.format` / `L10n.locale(for:)`; `Binding.appSettingsField` für Einstellungs-Bindings. |

## Ablauf beim Start (Reihenfolge)

1. `AppState.init(defaults:)` ruft **`AppLanguagePolicy.bootstrap`** auf.
2. `AppSettings.load` — fehlt die JSON-Datei → neues `AppSettings()` mit OS-Erkennung.
3. Fehlt die gespeicherte Datei → **`save`** (Erstinstallation persistiert Sprache sofort).
4. **`applyAppleLanguages`** schreibt `AppleLanguages`.
5. `noteActiveDisplayLanguage` — `L10n` kennt die Sprache ohne erneutes Lesen aus der Platte.

## Ablauf Nutzer ändert Sprache

1. Einstellungen › Allgemein › Sprache (Deutsch / English).
2. Picker schreibt **`appSettings.displayLanguage`** über `appSettingsField` → `AppState`-`didSet`.
3. **`AppLanguagePolicy.syncFromSettings`:** `activeDisplayLanguage`, `AppleLanguages`, **`AppSettings.save`** (nicht debounced).
4. Fenster/Popover **`id(displayLanguage)`** — sichtbare Catalog-Texte wechseln sofort.
5. **Neustart** empfohlen laut Layout-Hinweistext (Menüs außerhalb von `LayoutCopy`, ggf. System-Strings).

## Vorbereitung bilingual (Mac-Standard) — Roadmap

### Phase 1 — Infrastruktur (erledigt)

- [x] `AppDisplayLanguage` + Persistenz in `AppSettings`
- [x] OS-Erkennung Erststart
- [x] `AppleLanguages`-Policy
- [x] `Localizable.xcstrings` (alle `LayoutCopy`-Texte, 169 Keys; Generator: `Werkzeuge/generate_localizable.py`)
- [x] `InfoPlist.xcstrings` (Volume-Nutzung)
- [x] Projekt-Region **`de`** in `knownRegions`
- [x] `L10n`-Hilfen

### Phase 2 — String Catalog (Hauptarbeit, Kern erledigt 06.10.)

1. **Xcode:** `knownRegions`: **de**, **en** (Projekt).
2. **Erledigt:** semantische Keys `copy.*` in `Localizable.xcstrings`; `LayoutCopy` ist dünne Schicht über `L10n`.
3. **Quelle DE:** Layout-HTML + Catalog; **EN:** Übersetzungen im Catalog (Review bei Claude-Freigabe).
4. **`LayoutCopyTests`:** prüft Layout-HTML gegen Catalog-DE + `LayoutCopy.swift`; **`L10nTests`** stichprobenartig DE/EN.
5. **Offen:** `ProposalCopy` / `EmptyStateCopy`, restliche View-Literale (Audit `prompt.md` 111/118); optional Generated Symbols statt String-Keys.

### Phase 3 — Formatierung & Pluralisierung

- Datums-/Zahlenformat: `DisplayNumberFormat` / `ByteCountFormatter` an `L10n.locale(for: appSettings.displayLanguage)` koppeln.
- Pluralregeln: String Catalog **Variablen** (`%lld`) statt manueller `ELEMENT`/`ELEMENTE`-Verzweigung, wo sinnvoll.

### Phase 4 — Qualität

- Screenshot-Plan: je Screen **`-hell` / `-dunkel`** für **de** und **en** (Ordner suffix z. B. `-en`).
- UI-Tests mit `-AppleLanguages (en)` Launch-Argument (optional).
- Freigabe: Claude Review gegen Layout + englische Parität.

## Dateien (Referenz)

| Datei | Rolle |
|-------|--------|
| `Models/AppDisplayLanguage.swift` | Enum, OS-Erkennung, Locale-/Apple-Codes |
| `Localization/AppLanguagePolicy.swift` | Bootstrap, `AppleLanguages` |
| `Localization/L10n.swift` | Übergangs-API |
| `Localization/Localizable.xcstrings` | UI-String-Catalog (wächst) |
| `Localization/InfoPlist.xcstrings` | Info.plist-Lokalisierung |
| `Models/AppSettings.swift` | `displayLanguage` (wird **nicht** von „Voreinstellungen anwenden“ zurückgesetzt) |

## Tests

- `AppDisplayLanguageTests` — Zuordnung `preferredLanguages` → DE/EN.
- `AppLanguagePolicyTests` — Erststart speichert Sprache; `AppleLanguages` gesetzt.

## Hinweise

- **Tests:** `bootstrap` läuft mit dem App-Zustand im Speicher, ohne `UserDefaults`-Suite und ohne `.standard` (`bug.0.4.208`, `konzept/architektur.md` „Speicherung“).
- **Menüleiste & Launch Agent:** gleiche Bundle-ID. Die Sprache folgt der Anzeigesprache in `app-state.plist`; `AppleLanguages` bleibt in `app.diskarchive.plist`, weil macOS es von dort liest (`bug.0.4.208`).
- **ProposalCopy** (rote Vorschlagstexte): bleibt bis Layout-Freigabe getrennt; EN parallel planen.
