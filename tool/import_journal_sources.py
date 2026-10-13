"""Import the supplied V9 journal and Google My Maps export without geocoding.

Uses standard-library OOXML/KML readers. Explicit source headings and matches
make ambiguous identifications reviewable instead of fuzzy-matching names.
Run from the repository: python tool/import_journal_sources.py
"""
import hashlib
import json
import re
from pathlib import Path
from xml.etree import ElementTree as ET
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
JOURNAL = ROOT / "Ikhwan_al_Safa_Climes_Journal_FINAL_V9.docx"
KMZ = ROOT / "ikhwan climes.kmz"
W = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
K = {"k": "http://www.opengis.net/kml/2.2"}
SOURCE_HASHES = {
    JOURNAL.name: "9753c112e1d790e340a8907a0517b5cb99408dcc6944b11f8d99b942ce43e596",
    KMZ.name: "16f4b61aece1d5086b2014137d20893b8e563bc0f29fdd741385ea14abaff8a1",
}

RANGES = {
    1: [("jarma", 64, 68), ("habasha", 68, 72), ("dongola", 72, 76),
        ("kosha", 76, 80), ("chaul", 80, 84), ("al_mayd", 84, 88),
        ("uman_dhofar", 88, 92)],
    2: [("medina", 110, 113), ("gwalior", 113, 117), ("ghogha", 117, 121),
        ("al_ghamra", 121, 123), ("berbera", 123, 127), ("debal", 127, 130),
        ("diyar_tali", 130, 133), ("yamama", 133, 136), ("taif", 136, 139),
        ("mecca", 139, 141), ("akhmim", 141, 144), ("ifriqiya", 144, 147),
        ("bilad_samrani", 147, 149)],
    3: list(zip(["guangzhou", "kandahar", "kabul", "zaranj", "barqa", "sirjan",
        "shiraz", "ahvaz", "basra", "kufa", "damascus", "jerusalem", "fustat",
        "alexandria", "kairouan", "tangier"],
        [168,174,181,187,193,199,205,213,219,226,236,242,248,266,271,276],
        [174,181,187,193,199,205,213,219,226,236,242,248,266,271,276,281])),
    4: list(zip(["samarkand", "balkh", "herat", "merv", "nishapur", "jurjan",
        "amol", "rayy", "daylam_gilan", "isfahan", "hamadan", "baghdad", "mosul", "aleppo"],
        [365,383,402,419,439,453,470,486,504,522,538,554,572,589],
        [383,402,419,439,453,470,486,504,522,538,554,572,589,607])),
    5: list(zip(["rome", "macedonia", "malatya", "akhlat", "ardabil", "taraz",
        "bilad_khaqan", "khwarazm", "isbijab", "yajuj_majuj"],
        [617,622,627,632,637,642,646,651,656,662],
        [622,627,632,637,642,646,651,656,662,667])),
    7: list(zip(["atil", "bolghar", "kyiv", "samandar", "thule", "saqalibah",
        "khazar", "yajuj_majuj_7", "kimak", "volga_islands", "caspian_islands",
        "maraghah", "bab_al_abwab", "bijar", "gothia"],
        [743,785,810,837,873,905,937,975,1009,1038,1066,1105,1139,1176,1221],
        [785,810,837,873,905,937,975,1009,1038,1066,1105,1139,1176,1221,1272])),
}


def read_journal():
    with ZipFile(JOURNAL) as archive:
        root = ET.fromstring(archive.read("word/document.xml"))
    blocks = []
    for index, node in enumerate(root.find("w:body", W)):
        if node.tag.endswith("}p"):
            style = node.find("w:pPr/w:pStyle", W)
            blocks.append({"index": index, "type": "paragraph",
                "style": style.get("{" + W["w"] + "}val") if style is not None else "",
                "text": "".join(t.text or "" for t in node.findall(".//w:t", W)).strip()})
        elif node.tag.endswith("}tbl"):
            rows = []
            for row in node.findall("w:tr", W):
                rows.append(["\n".join("".join(t.text or "" for t in p.findall(".//w:t", W))
                    for p in cell.findall("w:p", W)) for cell in row.findall("w:tc", W)])
            blocks.append({"index": index, "type": "table", "rows": rows})
    return blocks


def split_sections(paragraphs, default_title):
    sections = []
    title, body = default_title, []
    for text in paragraphs:
        if text.endswith(":") and len(text) < 110:
            if body:
                sections.append({"title": title, "paragraphs": body})
            title, body = text.rstrip(":"), []
        else:
            body.append(text)
    if body:
        sections.append({"title": title, "paragraphs": body})
    return sections


def extract_content(blocks, clime, start, end):
    heading = next(b for b in blocks if b["index"] == start)
    if heading.get("style") != "CityHeading":
        raise ValueError(f"Journal structure changed at {start}")
    paragraphs = [b for b in blocks if start < b["index"] < end and b["type"] == "paragraph"]
    history, legacy, sources = [], [], []
    active = clime in (1, 2, 5)
    mode = "history"
    for block in paragraphs:
        text, style = block["text"], block["style"]
        if not text:
            continue
        urls = re.findall(r"https?://[^\s]+", text)
        if urls:
            for url in urls:
                url = url.rstrip(".,;)") if not "(" in url else url.rstrip(".,;")
                sources.append({"label": re.sub(r"https?://", "", url).replace("en.wikipedia.org/wiki/", "Wikipedia · ").replace("_", " "), "url": url})
            if text.startswith(("Read more", "http")):
                continue
        if "Academic Sources" in text:
            active = False
            mode = "sources"
            continue
        if clime == 4 and "Historical & Economic Significance" in text:
            active, mode = True, "history"
            continue
        if clime == 7:
            if re.match(r"3\. Historical Significance", text):
                active, mode = True, "history"
                continue
            if re.match(r"4\. Modern Significance", text):
                active, mode = True, "legacy"
                continue
        if clime == 3 and re.match(r"Historical significance\s*:", text, re.I):
            active, mode = True, "history"
            text = text.partition(":")[2].lstrip("- ").strip()
        if mode == "sources" and not urls:
            sources.append({"label": text, "url": None})
        if not active or mode == "sources" or style.startswith("Reference"):
            continue
        if text.startswith(("Longitude:", "Latitude:", "Modern Coordinates:",
                "Manuscript Abjad", "How to Locate", "Mathematical", "Scribal Errors")):
            continue
        if clime == 1:
            text = re.sub(r"^(Historical Evidence & Philological Identification|Role in Regional Trade Networks):\s*", "", text)
        if style.startswith("Heading"):
            text = text + ":"
        text = re.sub(r"\[\d+\]", "", text)
        (legacy if mode == "legacy" else history).append(text)
    return (split_sections(history, "Historical significance"),
            split_sections(legacy, "Legacy today"), sources)


def main():
    for source in (JOURNAL, KMZ):
        if hashlib.sha256(source.read_bytes()).hexdigest() != SOURCE_HASHES[source.name]:
            raise ValueError(f"{source.name} changed: review the explicit source links before importing")
    blocks = read_journal()
    cities_path = ROOT / "assets/data/cities.json"
    cities = json.loads(cities_path.read_text(encoding="utf-8"))
    by_id = {city["id"]: city for city in cities}
    table = next(b["rows"] for b in blocks if b["index"] == 738)
    if len(table) != 16:
        raise ValueError("Expected the journal's 15 Clime VII entries")
    for row, (city_id, _, _) in zip(table[1:], RANGES[7]):
        if city_id not in by_id:
            city = {"id": city_id, "name": row[1], "arabicName": row[0], "clime": 7,
                "history": row[2], "idrisiHint": "", "modernLat": float(row[5]),
                "modernLng": float(row[6]), "px": None, "py": None}
            cities.append(city)
            by_id[city_id] = city
        by_id[city_id]["placeType"] = row[4]
    aliases = {"atil": "Ītil / Atil", "bolghar": "Bulghār / Bolghar",
        "kyiv": "Kuyāba / Kyiv", "samandar": "Samandar", "thule": "Tūlī / Thule",
        "maraghah": "Marāghah / Maragheh", "bab_al_abwab": "Jabal Bāb al-Abwāb / Derbent"}
    for city_id, name in aliases.items():
        by_id[city_id]["name"] = name

    import_report = []
    for clime, ranges in RANGES.items():
        for city_id, start, end in ranges:
            city = by_id[city_id]
            history, legacy, sources = extract_content(blocks, clime, start, end)
            fallback = not history
            if fallback:
                history = [{"title": "Historical significance", "paragraphs": [city["history"]]}]
            city["historySections"] = history
            city["legacySections"] = legacy
            city["sources"] = list({source["url"] or source["label"]: source for source in sources}.values())
            city["history"] = "\n\n".join(p for section in history for p in section["paragraphs"])
            city["sourceNote"] = ("The journal lists this entry without an expanded history; the existing catalog account is retained."
                if fallback else "Historical account adapted from the supplied Ikhwan al-Safa Climes Journal, V9. The journal's proposed and disputed identifications are retained.")
            if clime == 7:
                # Preserve the identification before the navigation instructions,
                # especially the alternative candidates for Bijar and Gothia.
                intro = [b["text"] for b in blocks if start < b["index"] < end
                    and b["type"] == "paragraph" and b["style"] == ""
                    and not re.match(r"\d\. ", b["text"])][:2]
                if intro:
                    city["historySections"].insert(0, {"title": "Identity in the journal", "paragraphs": intro})
            import_report.append({"cityId": city_id, "journalBlock": start,
                "historySections": len(history), "retainedCatalogHistory": fallback})

    # Explicit links to the custom map, including its own regional substitutes.
    matches = {
        1: [None,None,None,None,"chaul","al_mayd",None,"jarma","habasha","kosha","dongola","uman_dhofar"],
        2: ["ghogha","gwalior","al_ghamra","berbera","debal","diyar_tali","yamama","taif","mecca","medina","akhmim","ifriqiya","bilad_samrani"],
        3: ["guangzhou","kandahar","kabul","zaranj","sirjan","shiraz","ahvaz","basra","kufa","damascus","jerusalem","fustat","alexandria","kairouan","tangier"],
        4: [None,None,"samarkand","balkh","herat","merv","nishapur","jurjan","amol","rayy","daylam_gilan","isfahan","hamadan","baghdad","mosul","aleppo"],
        5: [row[0] for row in RANGES[5]],
        7: [row[0] for row in RANGES[7]],
    }
    with ZipFile(KMZ) as archive:
        kml_name = next(name for name in archive.namelist() if name.lower().endswith(".kml"))
        root = ET.fromstring(archive.read(kml_name))
    points = []
    for folder in root.findall(".//k:Folder", K):
        folder_name = folder.findtext("k:name", namespaces=K)
        number = int(re.search(r"clime\s*(\d+)", folder_name, re.I).group(1))
        marks = folder.findall("k:Placemark", K)
        if len(marks) != len(matches[number]):
            raise ValueError(f"Custom map layer {number} changed: review explicit city links")
        for index, (mark, city_id) in enumerate(zip(marks, matches[number])):
            coordinates = mark.findtext(".//k:Point/k:coordinates", namespaces=K)
            lng, lat = [float(value) for value in coordinates.strip().split(",")[:2]]
            if not (-180 <= lng <= 180 and -90 <= lat <= 90):
                raise ValueError("Custom map coordinate is outside the geographic range")
            name = mark.findtext("k:name", namespaces=K)
            point_id = f"clime-{number}-{index + 1}"
            points.append({"id": point_id, "cityId": city_id, "name": name,
                "clime": number, "latitude": lat, "longitude": lng,
                "layer": folder_name})
            if city_id:
                by_id[city_id]["modernReferenceId"] = point_id
                by_id[city_id]["modernLat"] = lat
                by_id[city_id]["modernLng"] = lng
    by_id["barqa"]["modernReferenceId"] = None
    if len(cities) != 75 or len(points) != 81:
        raise ValueError("Expected 75 journal catalog records and 81 custom map points")
    linked_ids = [point["cityId"] for point in points if point["cityId"]]
    if len(linked_ids) != 74 or len(set(linked_ids)) != 74:
        raise ValueError("Expected 74 unique custom links; Barqa is absent from the supplied KMZ")
    cities_path.write_text(json.dumps(cities,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    modern = {"mapId":"1XMnqIQnu7SdgRlxMWgl07WWR8DMkz5w", "title":"ikhwan climes",
        "sourceFile":KMZ.name, "sourceSha256":hashlib.sha256(KMZ.read_bytes()).hexdigest(),
        "points":points}
    (ROOT/"assets/data/modern_reference.json").write_text(json.dumps(modern,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    (ROOT/"tool/journal_import_report.json").write_text(json.dumps({
        "sourceFile":JOURNAL.name,"sourceSha256":hashlib.sha256(JOURNAL.read_bytes()).hexdigest(),
        "entries":import_report,"unmatchedModernCityIds":["barqa"]},indent=2)+"\n",encoding="utf-8")
    print(f"Imported {len(cities)} catalog entries, {len(points)} custom points; retained history for "
        + ", ".join(row["cityId"] for row in import_report if row["retainedCatalogHistory"]))


if __name__ == "__main__":
    main()
