"""Check arranged document sources locally or committed output without private sources."""

import argparse
import importlib.util
from html import unescape
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import yaml

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


def json_strings(value):
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        return [text for item in value.values() for text in json_strings(item)]
    if isinstance(value, list):
        return [text for item in value for text in json_strings(item)]
    return []


def repository_references(output):
    """Read rendered pages, search text, and sitemap; return unique GitHub repos."""
    repos = set()
    pattern = r"(?:https?:)?//(?:www\.)?github\.com/([\w.-]+)/([\w.-]+)"
    for path in output.rglob("*"):
        if path.is_file() and path.suffix in {".html", ".json", ".xml"}:
            text = path.read_text(encoding="utf-8")
            if path.suffix == ".json":
                text = "\n".join(json_strings(json.loads(text)))
            text = unquote(unescape(text)).replace("\\/", "/")
            for owner, repo in re.findall(pattern, text, flags=re.IGNORECASE):
                repos.add(f"{owner}/{repo.removesuffix('.git')}".casefold())
    return repos


def public_repository_errors(repos):
    """Verify anonymous access; never use a contributor's source-access token."""
    errors = []
    for repo in sorted(repos):
        request = Request(f"https://api.github.com/repos/{repo}", headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "subsea-cable-public-link-check",
        })
        try:
            with urlopen(request, timeout=20) as response:
                metadata = json.load(response)
            if metadata.get("private") is not False:
                errors.append(f"GitHub repository is not publicly accessible: {repo}")
        except HTTPError as error:
            error.close()
            if error.code == 404:
                errors.append(f"GitHub repository is not publicly accessible: {repo} (HTTP 404)")
            else:
                errors.append(f"Could not verify public GitHub repository: {repo} (HTTP {error.code})")
        except (URLError, OSError, ValueError) as error:
            errors.append(f"Could not verify public GitHub repository: {repo} ({error})")
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--site-dir", type=Path, required=True)
    parser.add_argument("--output-only", action="store_true",
                        help="check the prebuilt site without requiring language/export")
    parser.add_argument("--check-repositories", action="store_true",
                        help="verify anonymous access to GitHub repositories linked in pages, search and sitemap")
    args = parser.parse_args()
    output = args.site_dir.resolve()
    if not (output / "index.html").is_file():
        raise SystemExit("Missing prebuilt index.html; run the local builder and commit build/.")
    errors = []
    if args.output_only:
        config = yaml.safe_load((ROOT / "site/mkdocs.yml").read_text(encoding="utf-8"))
        config["site_dir"] = str(output)
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
    if args.check_repositories:
        repos = repository_references(output)
        errors.extend(public_repository_errors(repos))
        if not errors:
            print(f"Anonymous access verified for {len(repos)} linked GitHub repositories.")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"Publication and local links passed for {len(pages)} HTML pages.")


if __name__ == "__main__":
    main()
