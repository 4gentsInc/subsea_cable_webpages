"""Exercise publication selection against unapproved pages and raw-file leaks."""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock
from urllib.error import HTTPError, URLError

from mkdocs.exceptions import ConfigurationError
from mkdocs.structure.files import File, Files

HOOK = Path(__file__).resolve().parents[2] / "site/hooks/publication.py"
spec = importlib.util.spec_from_file_location("publication", HOOK)
publication = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publication)


CHECKER = Path(__file__).with_name("check_site_publication.py")
spec = importlib.util.spec_from_file_location("checker", CHECKER)
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


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

    def test_output_allowlist_rejects_unknown_pages_and_files(self):
        for filename in ("unknown/index.html", "assets/unapproved.txt", "other/download.txt"):
            with self.subTest(filename=filename), tempfile.TemporaryDirectory() as temp:
                c = config(Path(temp))
                leaked = Path(c["site_dir"]) / filename
                leaked.parent.mkdir(parents=True)
                leaked.write_text("unexpected plugin output", encoding="utf-8")
                with self.assertRaisesRegex(ConfigurationError, "Unapproved file"):
                    publication.on_post_build(c)

    def test_output_allowlist_accepts_selected_documents_and_support(self):
        with tempfile.TemporaryDirectory() as temp:
            c = config(Path(temp))
            for filename in ("index.html", "LICENSE", "conformance/valid/core.vyg", "search/search_index.json", "sitemap.xml"):
                path = Path(c["site_dir"]) / filename
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("public content", encoding="utf-8")
            publication.on_post_build(c)

    def test_output_check_catches_a_late_plugin_leak(self):
        with tempfile.TemporaryDirectory() as temp:
            c = config(Path(temp))
            leaked = Path(c["site_dir"]) / "confidential/download.txt"
            leaked.parent.mkdir(parents=True)
            leaked.write_text("must not publish", encoding="utf-8")
            with self.assertRaises(ConfigurationError):
                publication.on_post_build(c)


class RepositoryLinkTests(unittest.TestCase):
    def test_repository_extraction_covers_pages_search_and_sitemap(self):
        samples = {
            "index.html": '<a href="https://github.com/Example/Public/issues/1">link</a>',
            "search/search_index.json": json.dumps({"text": r"https:\/\/github.com\/example\/search-only.git"}),
            "sitemap.xml": "https://github.com/example/xml-only?x=1&amp;y=2",
        }
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            for filename, text in samples.items():
                path = output / filename
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding="utf-8")
            self.assertEqual(checker.repository_references(output),
                             {"example/public", "example/search-only", "example/xml-only"})

    def test_public_repository_check_uses_no_authentication(self):
        with mock.patch.object(checker, "urlopen") as request:
            request.return_value.__enter__.return_value.read.return_value = b'{"private":false}'
            with mock.patch.dict("os.environ", {"GH_TOKEN": "must-not-be-used"}):
                self.assertEqual(checker.public_repository_errors({"example/public"}), [])
            self.assertIsNone(request.call_args.args[0].get_header("Authorization"))
            self.assertEqual(request.call_args.args[0].full_url,
                             "https://api.github.com/repos/example/public")

    def test_unavailable_repositories_fail(self):
        with mock.patch.object(checker, "urlopen", side_effect=HTTPError("url", 404, "Not Found", {}, None)):
            errors = checker.public_repository_errors({"example/unavailable"})
            self.assertTrue(any("not publicly accessible" in error for error in errors))

    def test_private_metadata_fails(self):
        with mock.patch.object(checker, "urlopen") as request:
            request.return_value.__enter__.return_value.read.return_value = b'{"private":true}'
            self.assertTrue(checker.public_repository_errors({"example/unavailable"}))

    def test_network_failures_do_not_claim_repositories_are_private(self):
        for error in (URLError("offline"), HTTPError("url", 403, "Rate limit", {}, None)):
            with self.subTest(error=error), mock.patch.object(checker, "urlopen", side_effect=error):
                errors = checker.public_repository_errors({"example/public"})
                self.assertTrue(any("Could not verify" in message for message in errors))
                self.assertFalse(any("not publicly accessible" in message for message in errors))

    def test_output_only_checks_do_not_load_document_sources(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            c = config(root)
            output = Path(c["site_dir"])
            output.mkdir()
            (output / "index.html").write_text("<html></html>", encoding="utf-8")
            (root / "site").mkdir()
            (root / "site/mkdocs.yml").write_text(checker.yaml.safe_dump(c), encoding="utf-8")
            argv = ["check", "--site-dir", str(output), "--output-only", "--check-repositories"]
            with mock.patch.object(checker, "ROOT", root), mock.patch("sys.argv", argv), \
                    mock.patch.object(checker, "load_config") as load, \
                    mock.patch.object(checker, "public_repository_errors", return_value=[]) as verify, \
                    contextlib.redirect_stdout(io.StringIO()):
                checker.main()
                load.assert_not_called()
                verify.assert_called_once_with(set())


if __name__ == "__main__":
    unittest.main()
