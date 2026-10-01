#!/usr/bin/env python3
"""Tests for labels.py and finding.py."""
import contextlib
import io
import importlib.util
import json
import os
import unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
FORM = HERE.parent / "ISSUE_TEMPLATE" / "finding.yml"

try:
    import yaml
except ImportError:  # pragma: no cover - CI installs PyYAML for issue-form validation
    yaml = None


def load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


labels = load("labels")
finding = load("finding")


class LabelsTest(unittest.TestCase):
    def test_repository_file_is_valid(self):
        self.assertEqual(labels.validate(labels.load()), [])

    def test_remote_operations_require_an_explicit_repository(self):
        for command in ("diff", "sync"):
            with self.subTest(command=command), contextlib.redirect_stderr(io.StringIO()):
                with mock.patch.object(labels, "remote_labels") as remote:
                    with self.assertRaises(SystemExit) as exited:
                        labels.main([command])
                    self.assertEqual(exited.exception.code, 2)
                    remote.assert_not_called()

    def test_rejects_case_insensitive_duplicate(self):
        bad = [{"name": "finding", "color": "d93f0b", "description": "a"},
               {"name": "Finding", "color": "d93f0b", "description": "b"}]
        self.assertTrue(any("duplicate" in e for e in labels.validate(bad)))

    def test_rejects_bad_color_and_unknown_prefix(self):
        bad = [{"name": "finding", "color": "#D93F0B", "description": "a"},
               {"name": "misc", "color": "ffffff", "description": "b"}]
        errs = labels.validate(bad)
        self.assertTrue(any("color" in e for e in errs))
        self.assertTrue(any("prefix" in e for e in errs))

    def test_plan_creates_updates_and_keeps_unmanaged(self):
        want = [{"name": "finding", "color": "d93f0b", "description": "x"},
                {"name": "area:docs", "color": "c5def5", "description": "y"}]
        remote = {"finding": {"name": "finding", "color": "D93F0B", "description": "old"},
                  "bug": {"name": "bug", "color": "ffffff", "description": ""}}
        create, update, unmanaged = labels.plan(want, remote)
        self.assertEqual([l["name"] for l in create], ["area:docs"])
        self.assertEqual([u[0] for u in update], ["finding"])
        self.assertEqual(unmanaged, ["bug"])

    def test_apply_sends_json_requests(self):
        sent = []

        class Resp:
            def __enter__(self):
                return self

            def __exit__(self, *exc):
                return False

            def read(self):
                return b"{}"

        def fake_urlopen(req):
            sent.append(req)
            return Resp()

        create = [{"name": "area:docs", "color": "c5def5", "description": "y"}]
        update = [("triage:needs owner", {"name": "triage:needs-owner", "color": "b60205",
                                          "description": "z"})]
        with mock.patch.object(labels.urllib.request, "urlopen", fake_urlopen):
            labels.apply("o/r", "tok", create, update)

        self.assertEqual(len(sent), 2)
        post, patch = sent
        self.assertEqual(post.get_method(), "POST")
        self.assertEqual(post.full_url, "https://api.github.com/repos/o/r/labels")
        self.assertEqual(post.get_header("Content-type"), "application/json")
        self.assertEqual(post.get_header("Authorization"), "Bearer tok")
        self.assertEqual(json.loads(post.data), create[0])
        self.assertEqual(patch.get_method(), "PATCH")
        self.assertEqual(patch.full_url,
                         "https://api.github.com/repos/o/r/labels/triage%3Aneeds%20owner")
        self.assertEqual(patch.get_header("Content-type"), "application/json")
        self.assertEqual(json.loads(patch.data), {"new_name": "triage:needs-owner",
                                                  "color": "b60205", "description": "z"})

    def test_get_sends_no_content_type(self):
        with mock.patch.object(labels.urllib.request, "urlopen") as op:
            op.return_value.__enter__.return_value.read.return_value = b"[]"
            labels.remote_labels("o/r", "tok")
            req = op.call_args[0][0]
        self.assertEqual(req.get_method(), "GET")
        self.assertIsNone(req.get_header("Content-type"))


def filled(**overrides):
    values = {
        "Kind": "gap — the specification does not say",
        "Area": "laid Cable lifecycle and terminals, output multiplicity",
        "Language revision": "73d5859",
        "Normative sources involved": "proposals/0014 §7.3",
        "Smallest reproduction": "root P/1",
        "Expected versus observed or possible readings": "two readings",
        "Impact and current handling": finding.PLACEHOLDER,
        "Evidence links": finding.PLACEHOLDER,
        "Reported by": "agent",
        "Agent or tool (if reported by an agent)": "Claude",
        "Checks": "\n".join(f"- [X] {c}" for c in finding.CHECKS),
    }
    values.update(overrides)
    return "\n".join(f"### {h}\n\n{values[h]}\n" for h, _ in finding.SECTIONS)


class FindingTest(unittest.TestCase):
    def test_template_is_incomplete(self):
        self.assertTrue(finding.check(finding.template()))

    def test_filled_body_passes(self):
        self.assertEqual(finding.check(filled()), [])

    def test_published_documentation_baseline_is_accepted(self):
        baseline = "https://4gentsinc.github.io/subsea_cable_webpages/LANGUAGE_REFERENCE/ 2026-10-01"
        self.assertEqual(finding.check(filled(**{"Language revision": baseline})), [])

    def test_documentation_baseline_requires_a_valid_date(self):
        for baseline in ("https://example.com/reference", "https://example.com/reference 2026-99-99", "main 2026-10-01"):
            with self.subTest(baseline=baseline):
                self.assertTrue(finding.check(filled(**{"Language revision": baseline})))

    def test_bad_revision_rejected(self):
        self.assertTrue(any("revision" in e for e in finding.check(filled(**{"Language revision": "main"}))))

    def test_unknown_area_rejected(self):
        errs = finding.check(filled(Area="output multiplicity, runtime stuff"))
        self.assertTrue(any("Area" in e for e in errs))

    def test_misspelled_area_rejected(self):
        self.assertTrue(finding.check(filled(Area="grammar & syntax")))

    def test_unknown_reporter_rejected(self):
        errs = finding.check(filled(**{"Reported by": "bot"}))
        self.assertTrue(any("Reported by" in e for e in errs))

    def test_unticked_check_rejected(self):
        body = filled(Checks="\n".join(f"- [ ] {c}" for c in finding.CHECKS))
        self.assertTrue(any("check not ticked" in e for e in finding.check(body)))

    def test_scp_form_requires_proposal_analysis_without_activating_it(self):
        if yaml is None:
            if os.environ.get("CI"):
                self.fail("PyYAML is required in CI")
            self.skipTest("PyYAML not installed")
        form = yaml.safe_load((FORM.parent / "scp.yml").read_text(encoding="utf-8"))
        self.assertEqual(form["labels"], ["proposal:scp"])
        by_id = {field["id"]: field for field in form["body"] if "id" in field}
        for name in ("revision", "problem", "sources", "reproduction", "invariants", "alternatives", "recommendation", "compatibility", "reporter"):
            self.assertTrue(by_id[name]["validations"]["required"], name)
        self.assertIn("no language change", by_id["alternatives"]["attributes"]["label"])
        self.assertTrue(all(option["required"] for option in by_id["checks"]["attributes"]["options"]))
        self.assertTrue(any("does not accept or activate" in option["label"] for option in by_id["checks"]["attributes"]["options"]))

    def test_enumerations_match_the_web_form(self):
        if yaml is None:
            if os.environ.get("CI"):
                self.fail("PyYAML is required in CI to compare the helper with the web form")
            self.skipTest("PyYAML not installed")
        form = yaml.safe_load(FORM.read_text(encoding="utf-8"))
        by_id = {b.get("id"): b for b in form["body"] if "id" in b}
        self.assertEqual(by_id["area"]["attributes"]["options"], finding.AREAS)
        self.assertEqual(by_id["reporter"]["attributes"]["options"], finding.REPORTERS)
        kinds = [o.split()[0] for o in by_id["kind"]["attributes"]["options"]]
        self.assertEqual(kinds, finding.KINDS)
        checks = [o["label"] for o in by_id["checks"]["attributes"]["options"]]
        self.assertEqual(checks, finding.CHECKS)
        for a in finding.AREAS:
            self.assertNotIn(",", a)


if __name__ == "__main__":
    unittest.main()
