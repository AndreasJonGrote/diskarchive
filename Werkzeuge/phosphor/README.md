# Phosphor Icons 2.1.1 (alle Icons, alle Stärken)

Quelle: npm `@phosphor-icons/core@2.1.1` (dieselbe Version wie im Layout, `@phosphor-icons/web@2.1.1`), Prüfsumme sha512 aus dem npm-Verzeichnis geprüft. Lizenz: MIT (`LICENSE`). Abgelegt vom Host am 03.11.2026.

- Ordner je Stärke: `regular/`, `bold/`, `fill/`, `duotone/`, `light/`, `thin/` – je 1.512 SVG. Dateiname = Phosphor-Name, Stärke als Endung außer bei Regular (z. B. `regular/eject-simple.svg`, `bold/eject-simple-bold.svg`).
- **Worker:** Braucht ein Paket ein Icon, nimmt er es von hier und legt es wie die vorhandenen als Imageset in `DiskArchive/DiskArchive/Assets.xcassets` an (SVG, „Preserve Vector Data“, Template, Namensregel `Icon…` laut `Resources/Icons/ICON_STRATEGY.md`). **Nichts aus dem Netz laden, nicht fragen.** Welches Icon an welche Stelle gehört, zeigt das Layout (Klassen `ph-…` im HTML).
- Diesen Ordner pflegt nur der Host; der Worker ändert ihn nicht.
