"""Exercise publication selection against unapproved pages and raw-file leaks."""

import importlib.util
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest

from mkdocs.exceptions import ConfigurationError
from mkdocs.structure.files import File, Files

HOOK = Path(__file__).resolve().parents[2] / "site/hooks/publication.py"
spec = importlib.util.spec_from_file_location("publication", HOOK)
publication = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publication)


def config(root):
    return {
        "nav": [{"Start": [{"Overview": "README.md"}]}],
        "extra": {"publication_assets": ["LICENSE"],
                  "publication_asset_globs": ["conformance/valid/*.vyg"]},
        "site_dir": str(root / "output"),
    }


class PublicationTests(unittest.TestCase):
    def test_unapproved_markdown_and_raw_sources_never_reach_output(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            candidates = ["README.md", "LICENSE", "conformance/valid/core.vyg",
                          "new-page.md", "AGENTS.md", "confidential/plan.md",
                          "confidential/download.txt", "confidential/nested/leak.html",
                          ".private/brief.md", "site/hooks/publication.py"]
            files = Files([File(p, str(root), str(root / "output"), True)
                           for p in candidates])
            actual = publication.on_files(files, config(root))
            self.assertEqual({f.src_uri for f in actual},
                             {"README.md", "LICENSE", "conformance/valid/core.vyg"})

    def test_theme_assets_survive_without_allowing_unselected_source_assets(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            c = config(root)
            c["docs_dir"] = str(root / "export")
            c["theme"] = SimpleNamespace(dirs=[str(root / "theme")])
            files = Files([File("README.md", str(root / "export"), c["site_dir"], True),
                           File("LICENSE", str(root / "export"), c["site_dir"], True),
                           File("assets/theme.js", str(root / "theme"), c["site_dir"], True),
                           File("assets/unapproved.js", str(root / "export"), c["site_dir"], True)])
            actual = publication.on_files(files, c)
            self.assertEqual({f.src_uri for f in actual}, {"README.md", "LICENSE", "assets/theme.js"})

    def test_selected_file_outside_export_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            c = config(root)
            c["docs_dir"] = str(root / "export")
            files = Files([File("README.md", str(root / "private"), c["site_dir"], True),
                           File("LICENSE", str(root / "export"), c["site_dir"], True)])
            with self.assertRaises(ConfigurationError):
                publication.on_files(files, c)

    def test_confidential_navigation_and_path_escapes_are_rejected(self):
        for path in ("confidential/plan.md", ".private/brief.md", "AGENTS.md",
                     "../confidential/plan.md", "/confidential/plan.md"):
            with self.subTest(path=path), self.assertRaises(ConfigurationError):
                publication.nav_documents([{"Page": path}])

    def test_asset_list_cannot_bypass_markdown_approval(self):
        c = config(Path("."))
        c["extra"]["publication_assets"].append("new-page.md")
        with self.assertRaises(ConfigurationError):
            publication.on_config(c)

    def test_confidential_asset_and_broad_glob_are_rejected(self):
        c = config(Path("."))
        c["extra"]["publication_assets"].append("confidential/download.txt")
        with self.assertRaises(ConfigurationError):
            publication.on_config(c)
        c = config(Path("."))
        c["extra"]["publication_asset_globs"] = ["*.md"]
        with self.assertRaises(ConfigurationError):
            publication.on_config(c)

    def test_missing_approved_source_fails_instead_of_silent_publication(self):
        with tempfile.TemporaryDirectory() as temp:
            c = config(Path(temp))
            with self.assertRaises(ConfigurationError):
                publication.on_files(Files([]), c)

    def test_private_urls_are_rejected_in_html_search_and_sitemap(self):
        for filename in ("index.html", "search/search_index.json", "sitemap.xml"):
            with self.subTest(filename=filename), tempfile.TemporaryDirectory() as temp:
                c = config(Path(temp))
                leaked = Path(c["site_dir"]) / filename
                leaked.parent.mkdir(parents=True)
                leaked.write_text("https://github.com/on-the-ground/subsea_cable_vessel/issues/27", encoding="utf-8")
                with self.assertRaises(ConfigurationError):
                    publication.on_post_build(c)

    def test_output_check_catches_a_late_plugin_leak(self):
        with tempfile.TemporaryDirectory() as temp:
            c = config(Path(temp))
            leaked = Path(c["site_dir"]) / "confidential/download.txt"
            leaked.parent.mkdir(parents=True)
            leaked.write_text("must not publish", encoding="utf-8")
            with self.assertRaises(ConfigurationError):
                publication.on_post_build(c)


if __name__ == "__main__":
    unittest.main()
