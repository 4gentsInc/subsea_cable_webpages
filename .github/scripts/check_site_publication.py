"""Check arranged document sources locally or committed output without private sources."""

import argparse
import importlib.util
from html.parser import HTMLParser
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

from mkdocs.config import load_config

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("publication", ROOT / "site/hooks/publication.py")
publication = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publication)


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.links = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        if tag == "a" and "href" in attrs:
            self.links.append(attrs["href"])
        if tag in {"img", "script"} and "src" in attrs:
            self.links.append(attrs["src"])
        if tag == "link" and "href" in attrs:
            self.links.append(attrs["href"])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--site-dir", type=Path, required=True)
    parser.add_argument("--output-only", action="store_true",
                        help="check the prebuilt site without requiring language/export")
    args = parser.parse_args()
    output = args.site_dir.resolve()
    if not (output / "index.html").is_file():
        raise SystemExit("Missing prebuilt index.html; run the local builder and commit build/.")
    errors = []
    if args.output_only:
        config = {"site_dir": str(output)}
    else:
        config = load_config(config_file=str(ROOT / "site/mkdocs.yml"), site_dir=str(output))
        approved = publication.nav_documents(config["nav"])
        sources = Path(config["docs_dir"]).resolve()
        for source in sources.rglob("*.md"):
            name = source.relative_to(sources).as_posix()
            if name not in approved:
                errors.append(f"Unapproved Markdown in export/: {name}; review publication before adding navigation")
            for href in re.findall(r"!?\[[^\]\n]*\]\(([^\s)]+)\)", source.read_text(encoding="utf-8")):
                url = urlsplit(href)
                if url.scheme or url.netloc or not url.path or url.path.startswith("/"):
                    continue
                target = (source.parent / unquote(url.path)).resolve()
                if not target.is_relative_to(sources) or not target.exists():
                    errors.append(f"Broken or external source link in {name}: {href}")
    publication.on_post_build(config)
    pages = {}
    for path in output.rglob("*.html"):
        page = Page()
        page.feed(path.read_text(encoding="utf-8"))
        pages[path.resolve()] = page
    for source, page in pages.items():
        for href in page.links:
            url = urlsplit(href)
            if url.scheme or url.netloc or url.path.startswith("/"):
                continue
            target = (source.parent / unquote(url.path)).resolve() if url.path else source
            if target.is_dir():
                target = target / "index.html"
            if not target.is_relative_to(output) or not target.exists():
                errors.append(f"Broken site link in {source.relative_to(output)}: {href}")
            elif url.fragment and target in pages and unquote(url.fragment) not in pages[target].ids:
                errors.append(f"Missing site anchor in {source.relative_to(output)}: {href}")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"Publication and local links passed for {len(pages)} HTML pages.")


if __name__ == "__main__":
    main()
