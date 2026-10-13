# Journal and custom map integration

The historical catalog contains 75 records: 7 in Clime I, 13 in II, 16 in III, 14 in IV, 10 in V, none in VI, and 15 in VII. The journal is the authority for catalog membership and historical prose. The supplied Google My Maps KMZ is the authority for modern focus coordinates. Historical image positions are reviewed separately against the English scan and converted through the existing alignment grid for Arabic display.

## Modern map

The KMZ contains 81 points. Of these, 74 have explicit links to historical catalog records. Its extra Clime I points and the Kashgar/Navakat points in Clime IV remain visible in the Google custom map without becoming invented journal entries. Barqa has no matching custom point; it opens the overview with a message instead of introducing a marker from another source.

Both modern-map entry points share the same iframe and Google map ID. A selected city supplies a center and zoom from the exported custom point. Opening a second city creates the iframe with that city's URL, fixing the previous factory closure that could retain the first center. Google controls its own marker selection and popups; the app does not add a competing marker layer.

Some custom points are regional substitutes rather than exact equivalents of the historical site. These source names remain visible in the modern modal:

| Historical entry | Custom map reference | Interpretation |
| --- | --- | --- |
| Kūshah | Wadi Halfa | Source choice, not a claim that the two settlements are identical |
| Mamlakat al-Habasha | Ethiopia | Broad modern region |
| Uman / Dhofar | Oman | Broad modern region |
| Bijar / Bayhar | Bijar, Iran | Journal also proposes Baylaqan in Azerbaijan |
| Gothia | Narbonne / southern France | Journal also discusses Crimean Gothia |
| Thule | Shetland reference | Journal retains Iceland as an alternative |

The embed displays the live Google map. The KMZ snapshot supplies focus coordinates; another export/import is necessary if those coordinates are edited in Google My Maps.

## Journal content

Historical prose is organized into readable sections, retaining the journal's qualifiers and conjectures. Cartographic navigation instructions and manuscript coordinate calculations are not placed in the history panel. Clime VII's modern significance passages appear in a separate Legacy tab. Bibliographic references and links remain attributed to the journal.

The journal does not supply expanded historical prose for al-Ghamra, Mecca, Bilad al-Samrani, Zaranj, Alexandria, Kairouan, or Tangier. These seven retain the existing catalog histories and have an explicit source note. No new prose is invented to fill these gaps. The journal's detailed gazetteer, rather than the KMZ's layer titles or raw modern latitude, determines historical clime membership.

## Historical pins

All 75 records have bundled defaults and reset restores all of them. The evidence CSV distinguishes 45 printed-label placements, 17 regional references, and 13 estimates across the whole catalog. These classes describe placement evidence, not independent verification of the journal's historical identifications.

The 15 Clime VII defaults consist of six label placements, seven regional references, and two estimates:

| Entry | Placement evidence |
| --- | --- |
| Atil | Visible city symbol at the Volga mouth |
| Bulgar | Visible Bulgar symbol on the Volga |
| Kyiv | Visible Kiau symbol on the Dnieper |
| Samandar | Visible symbol on the western Caspian shore |
| Thule | Approximate northern Atlantic position; no secure inscription identified |
| Saqalibah | Representative Slavic/Rus region |
| Khazar | Named Khazar region near the lower Volga |
| Yajuj and Majuj | Printed frontier territory; separate catalog record from Clime V |
| Kimak | Printed Kimak territory |
| Volga islands | Representative delta location near Atil |
| Caspian islands | Representative printed island; no claim of exact Ashuradeh identification |
| Maragha | Visible al-Maraga symbol by Lake Urmia |
| Bab al-Abwab | Visible symbol at Derbent's coastal pass |
| Bijar / Bayhar | Approximate Iranian highland position for the KMZ candidate |
| Gothia | Narbonne represents the western candidate chosen in the KMZ |

Regional and approximate placements are identified in the reading panel, with the detailed evidence in its Sources tab. Their permanent default coordinates remain editable through browser overrides. A region's representative pin is not a boundary, and a mythic frontier reference is not a verified modern archaeological location.

## Learning interface

The clime guide is an ordinal belt diagram with a north-up/south-up switch. It is deliberately schematic: the historical scan is distorted and the journal groups some entries outside their present-day latitude belts. Reversing the guide teaches orientation without implying a valid geographic projection. Selecting a populated belt filters the historical map; Clime VI can be studied but has no city filter action.

## Reproducibility

`tool/import_journal_sources.py` imports the two supplied source files, writes structured histories and explicit modern links, and produces `tool/journal_import_report.json`. It checks the reviewed source hashes before using paragraph and point mappings. `tool/apply_historical_pin_defaults.py` then applies the evidence CSV through the inverse alignment grid, validating that every catalog record has one row and lies on both maps. Updating the sources requires reviewing the mappings and source hashes before rerunning the import.
