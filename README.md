# Al-Idrisi Map Explorer

A Flutter Web app for exploring historical map images, browsing 60 city records, and placing city pins. This repository targets browsers only.

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

Bundled city and clime records are in `assets/data`. All 60 records have default historical pins. `tool/historical_pin_evidence.csv` records each position on the English scan and whether it comes from a printed label, a named region, or an estimate. The 11 estimated placements are review candidates, not verified city inscriptions. Both map images show the geography in the same orientation, but their borders and local scan geometry differ. Pins are stored in normalized Arabic-sheet coordinates and positioned on the English sheet through a measured alignment grid. To regenerate the grid after replacing either image, install `opencv-python-headless`, `numpy`, and `scipy`, then run `python tool/calibrate_map_alignment.py --write`. A pin cannot be placed in an image border with no matching area on the other sheet.

Map pins, the city atlas, the city detail panel, and the filter legend share seven clime colors. Each pin also carries its clime number, so its category remains identifiable without relying on color alone. The current data assigns cities only to Climes 1–5; Climes 6 and 7 appear as empty, disabled categories in the legend until city records are added.

Pin edits are saved in browser storage for the current site; they do not edit the bundled JSON or sync between browsers. All trial pins saved by earlier app versions are retired. The app bar has direct buttons for the modern map reference, pin editor, and **Restore default pin positions**. Reset clears saved edits and reloads the 60 bundled pins. After adjusting the evidence CSV, run `python tool/apply_historical_pin_defaults.py` to convert English scan pixels through the map alignment grid and update the bundled JSON.

City details show historical significance and a **View modern location** action. That action opens an in-app map centered on the city's present-day reference point, marked with a highlighted pin. This view loads OpenStreetMap tiles when opened and displays map attribution. The app-bar reference button still opens the existing Google My Map layer.

## Map image loading

The app opens with a 2048-pixel WebP overview for each map (about 0.6 MB). When a user zooms in, it loads only the nearby 1024-pixel WebP tiles at the source image's native resolution. The large JPEGs in `assets/maps` are retained as source material but are not bundled into the app. This keeps the initial map download small and avoids asking the browser to render a single 11,000+ pixel image.

To rebuild the derived assets after changing either source map:

```powershell
python -m pip install Pillow
python tool/generate_map_assets.py
```

The overview and tile coordinates preserve the source image geometry, so saved normalized pin positions continue to refer to the same points.
