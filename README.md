# Al-Idrisi Map Explorer

A Flutter Web app for exploring historical map images, browsing 75 historical city and region records, and placing pins. This repository targets browsers only.

## Live site

Each push to `main` verifies and publishes the app at [laheri72.github.io/IDRISI_CILMES_MAP/](https://laheri72.github.io/IDRISI_CILMES_MAP/) using GitHub Pages. Pull requests run the checks and build without publishing.

## Run locally

Install Flutter with web support and a supported browser. Add Flutter's `bin` directory to your PATH, then open a terminal in this repository:

```powershell
flutter pub get
flutter run -d chrome
```

The local launch opens Chrome automatically. In the Flutter terminal, press `r` for hot reload, `R` for hot restart, and `q` to stop the app.

## Verify

```powershell
flutter analyze
flutter test
flutter build web --release
```

The web release output is in `build/web`. The repository ignores build output; the CI workflow builds and deploys it to GitHub Pages. To preview a local release build, run `python -m http.server 8080 --bind 127.0.0.1 --directory build/web` from the project directory.

## Data and saved pins

Bundled city and clime records are in `assets/data`. All 75 records have default historical pins, including 15 records from the supplied journal's Clime VII gazetteer. `tool/historical_pin_evidence.csv` records each position on the English scan and whether it comes from a printed label (45), a regional reference (17), or an estimate (13). Estimated placements are review candidates, not verified city inscriptions. Both map images show the geography in the same orientation, but their borders and local scan geometry differ. Pins are stored in normalized Arabic-sheet coordinates and positioned on the English sheet through a measured alignment grid. To regenerate the grid after replacing either image, install `opencv-python-headless`, `numpy`, and `scipy`, then run `python tool/calibrate_map_alignment.py --write`. A pin cannot be placed in an image border with no matching area on the other sheet.

Map pins, the city atlas, the reading panel, and the filter legend share seven clime colors. Each pin carries its clime number, so its category remains identifiable without relying on color alone. Clime 6 remains empty, consistent with the journal's explanation that the epistle gives no gazetteer for it. The clime guide offers selectable schematic belts and an orientation switch between modern north-up and historical south-up views. These belts are a learning aid, not an overlay or a latitude projection onto the historical scan. Catalog membership follows the journal, including regions whose modern reference points fall outside the astronomical belt.

Pin edits are saved in browser storage for the current site; they do not edit the bundled JSON or sync between browsers. All trial pins saved by earlier app versions are retired. The app bar has direct buttons for the modern map reference, pin editor, and **Restore default pin positions**. Reset clears saved edits and reloads all 75 bundled pins. After adjusting the evidence CSV, run `python tool/apply_historical_pin_defaults.py` to convert English scan pixels through the map alignment grid and update the bundled JSON.

City details use a scrollable reading panel with History, Legacy (where supplied), and Sources tabs and a persistent **View modern location** action. Historical prose is imported from the supplied V9 journal, preserving conjectures and alternative identifications. Seven entries without expanded historical prose retain their existing catalog account with a source note. Sources listed in the journal are attributed; the app does not imply independent verification of those claims.

Both modern-map entry points open the same custom Google My Maps embed. `assets/data/modern_reference.json` preserves all 81 point coordinates from `ikhwan climes.kmz`; 74 historical records are explicitly linked to those custom points. Barqa is absent from the export, so its action shows the custom map overview with an explanatory message. Selected views center the iframe using the KMZ point rather than a separate geocoder or street-map marker. Google controls marker rendering and popups inside its iframe. Live edits to the Google map can change its markers; refresh the KMZ import after changing point coordinates to keep the focus coordinates synchronized.

To reproduce the journal/KMZ import, keep the supplied `Ikhwan_al_Safa_Climes_Journal_FINAL_V9.docx` and `ikhwan climes.kmz` in the repository directory, run `python tool/import_journal_sources.py`, then `python tool/apply_historical_pin_defaults.py`. Source hashes and explicit mappings prevent a changed document or reordered custom layer from being silently applied to the wrong city. Review those mappings when updating either source. [Source review](docs/source_review.md) describes the assumptions and ambiguous links.

## Map image loading

The app opens with a 2048-pixel WebP overview for each map (about 0.6 MB). When a user zooms in, it loads only the nearby 1024-pixel WebP tiles at the source image's native resolution. The large JPEGs in `assets/maps` are retained as source material but are not bundled into the app. This keeps the initial map download small and avoids asking the browser to render a single 11,000+ pixel image.

To rebuild the derived assets after changing either source map:

```powershell
python -m pip install Pillow
python tool/generate_map_assets.py
```

The overview and tile coordinates preserve the source image geometry, so saved normalized pin positions continue to refer to the same points.
