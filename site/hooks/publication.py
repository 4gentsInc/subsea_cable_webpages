"""Publish only explicitly selected source documents and supporting files."""

from pathlib import Path, PurePosixPath
from fnmatch import fnmatchcase
import re
from urllib.parse import urlsplit

from mkdocs.exceptions import ConfigurationError
from mkdocs.structure.files import File

BLOCKED_ROOTS = {"confidential", ".private", ".git", ".github"}


def source_path(value):
    path = PurePosixPath(value)
    if (not value or path.is_absolute() or ".." in path.parts
            or "\\" in value or path.as_posix() != value
            or path.parts[0] in BLOCKED_ROOTS or value == "AGENTS.md"):
        raise ConfigurationError(f"Not a publishable source path: {value}")
    return value


def nav_documents(nav):
    selected = set()
    if isinstance(nav, list):
        for item in nav:
            selected.update(nav_documents(item))
    elif isinstance(nav, dict):
        for item in nav.values():
            selected.update(nav_documents(item))
    elif isinstance(nav, str) and not urlsplit(nav).scheme:
        path = source_path(nav)
        if not path.endswith(".md"):
            raise ConfigurationError(f"Site navigation must select Markdown: {path}")
        selected.add(path)
    return selected


def publication_selection(config):
    documents = nav_documents(config["nav"])
    assets = {source_path(p) for p in config["extra"].get("publication_assets", [])}
    if any(p.endswith(".md") for p in assets):
        raise ConfigurationError("Markdown must be approved through site navigation")
    globs = config["extra"].get("publication_asset_globs", [])
    for pattern in globs:
        source_path(pattern)
        if not pattern.startswith("conformance/") or not pattern.endswith("/*.vyg"):
            raise ConfigurationError("Only conformance fixture globs are supported")
    return documents, assets, globs


def on_config(config):
    publication_selection(config)
    if config.get("config_file_path"):
        expected = (Path(config["config_file_path"]).parent / "../language/export").resolve()
        if Path(config["docs_dir"]).resolve() != expected:
            raise ConfigurationError("Site sources must be the arranged ../language/export directory")
    return config


def on_files(files, config):
    documents, assets, globs = publication_selection(config)
    selected = documents | assets
    available = {f.src_uri for f in files if f.inclusion.is_included()}
    missing = selected - available
    if missing:
        raise ConfigurationError("Selected site sources are missing or excluded: "
                                 + ", ".join(sorted(missing)))
    source_root = Path(config["docs_dir"]).resolve() if config.get("docs_dir") else None
    theme_roots = [Path(p).resolve() for p in getattr(config.get("theme"), "dirs", [])]
    for file in list(files):
        path = file.src_uri
        fixture = any(fnmatchcase(path, pattern) for pattern in globs)
        source = Path(file.abs_src_path).resolve()
        theme_asset = any(source.is_relative_to(root) for root in theme_roots)
        if path in selected or fixture:
            if source_root and not source.is_relative_to(source_root):
                raise ConfigurationError("Selected source escapes export/: " + path)
        elif not theme_asset:
            files.remove(file)
    # Theme CSS belongs to the public builder, not to the language originals.
    if config.get("config_file_path"):
        site = Path(config["config_file_path"]).parent
        files.append(File("stylesheets/extra.css", str(site), config["site_dir"],
                          config["use_directory_urls"]))
    return files


def on_post_build(config):
    for path in Path(config["site_dir"]).rglob("*"):
        if path.is_file() and path.suffix in {".html", ".json", ".xml"}:
            content = path.read_text(encoding="utf-8")
            if re.search(r"https://github\.com/on-the-ground/(?:subsea_cable_language|subsea_cable_vessel)(?:/|[\"\s<])", content):
                raise ConfigurationError("Private repository URL found in generated output: " + path.name)
            if "https://on-the-ground.github.io/subsea_cable_language" in content:
                raise ConfigurationError("Retired site URL found in generated output: " + path.name)
        parts = path.relative_to(config["site_dir"]).parts
        if any(part in BLOCKED_ROOTS for part in parts) or "AGENTS" in parts:
            raise ConfigurationError("Excluded source found in site output: "
                                     + "/".join(parts))
