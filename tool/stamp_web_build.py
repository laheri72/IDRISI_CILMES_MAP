"""Give GitHub Pages entry scripts a unique URL for each deployment."""

import argparse
import re
from pathlib import Path


def stamp(build_dir: Path, revision: str) -> None:
    if not re.fullmatch(r"[0-9a-f]{7,40}", revision):
        raise ValueError("revision must be a Git commit SHA")

    index_path = build_dir / "index.html"
    bootstrap_path = build_dir / "flutter_bootstrap.js"
    index = index_path.read_text(encoding="utf-8")
    bootstrap = bootstrap_path.read_text(encoding="utf-8")

    script_tag = '<script src="flutter_bootstrap.js" async></script>'
    main_path = '"mainJsPath":"main.dart.js"'
    if index.count(script_tag) != 1 or bootstrap.count(main_path) != 1:
        raise ValueError("Flutter web output changed; review the cache stamp")

    index = index.replace(
        script_tag,
        f'<script src="flutter_bootstrap.js?v={revision}" async></script>',
    )
    index = index.replace(
        "</head>", f'  <meta name="app-build" content="{revision}">\n</head>', 1
    )
    bootstrap = bootstrap.replace(
        main_path, f'"mainJsPath":"main.dart.js?v={revision}"'
    )

    index_path.write_text(index, encoding="utf-8")
    bootstrap_path.write_text(bootstrap, encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("build_dir", type=Path)
    parser.add_argument("revision")
    args = parser.parse_args()
    stamp(args.build_dir, args.revision)
