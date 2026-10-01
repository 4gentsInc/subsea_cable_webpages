#!/usr/bin/env python3
"""Produce or check a finding issue body outside the web form.

The web issue form enforces required fields only in the browser. Agents and
CLI users create issues through the API, where no form validation applies, so
they use this helper to produce the same body shape and check it first.

  python .github/scripts/finding.py template > finding.md   # fill in every section
  python .github/scripts/finding.py check finding.md         # exit 1 if incomplete
  gh issue create --repo on-the-ground/subsea_cable_language \\
      --label finding --title "[finding] <short summary>" --body-file finding.md

The headings match the rendered output of .github/ISSUE_TEMPLATE/finding.yml,
so triage reads browser and CLI findings the same way.
"""
import re
import sys
from pathlib import Path

KINDS = ["ambiguity", "gap", "conflict", "ergonomics"]
# Must equal the `area` dropdown options in .github/ISSUE_TEMPLATE/finding.yml
# (a test enforces this). The web form renders a multi-select as the chosen
# options joined by ", ", so no option may contain a comma.
AREAS = [
    "grammar and syntax",
    "output multiplicity",
    "laid Cable lifecycle and terminals",
    "Runtime planes (Vessel / Cable / Carousel boundary)",
    "deduction and aliases",
    "policy and Scheduler/Host channel",
    "Codebase / artifacts / hashing",
    "conformance corpus",
    "documentation only",
]
REPORTERS = ["human", "agent"]
# (heading, required)
SECTIONS = [
    ("Kind", True),
    ("Area", True),
    ("Language revision", True),
    ("Normative sources involved", True),
    ("Smallest reproduction", True),
    ("Expected versus observed or possible readings", True),
    ("Impact and current handling", False),
    ("Evidence links", False),
    ("Reported by", True),
    ("Agent or tool (if reported by an agent)", False),
    ("Checks", True),
]
CHECKS = [
    "I searched open and closed issues labeled `finding` and this is not a duplicate.",
    "This concerns language semantics or its documentation, not only one Runtime's bug or profile choice.",
    "I did not ship a private semantic workaround and present it as Subsea Cable behavior.",
]
PLACEHOLDER = "_No response_"


def template():
    parts = []
    for heading, _ in SECTIONS:
        if heading == "Kind":
            body = "one of: " + ", ".join(KINDS)
        elif heading == "Area":
            body = "one or more, comma-separated: " + "; ".join(AREAS)
        elif heading == "Reported by":
            body = "one of: " + ", ".join(REPORTERS)
        elif heading == "Checks":
            body = "\n".join(f"- [ ] {c}" for c in CHECKS)
        else:
            body = PLACEHOLDER
        parts.append(f"### {heading}\n\n{body}\n")
    return "\n".join(parts)


def parse(text):
    sections, current = {}, None
    for line in text.splitlines():
        m = re.match(r"^###\s+(.*\S)\s*$", line)
        if m:
            current = m.group(1)
            sections[current] = []
        elif current is not None:
            sections[current].append(line)
    return {k: "\n".join(v).strip() for k, v in sections.items()}


def check(text):
    got = parse(text)
    errors = []
    for heading, required in SECTIONS:
        value = got.get(heading)
        if value is None:
            errors.append(f"missing section: ### {heading}")
        elif required and (not value or value == PLACEHOLDER
                           or value.startswith(("one of:", "one or more,"))):
            errors.append(f"required section is empty: ### {heading}")
    kind = got.get("Kind", "").split()[0].lower() if got.get("Kind") else ""
    if kind and kind not in KINDS and not kind.startswith("one"):
        errors.append(f"Kind must start with one of {KINDS}")
    area = got.get("Area", "")
    if area and area != PLACEHOLDER and not area.startswith("one or more,"):
        chosen = [a.strip() for a in area.split(",")]
        unknown = [a for a in chosen if a not in AREAS]
        if unknown or not chosen:
            errors.append(f"unknown Area value(s) {unknown}; allowed: {AREAS}")
    reporter = got.get("Reported by", "")
    if reporter and reporter != PLACEHOLDER and not reporter.startswith("one of:") \
            and reporter not in REPORTERS:
        errors.append(f"Reported by must be one of {REPORTERS}")
    rev = got.get("Language revision", "")
    if rev and rev != PLACEHOLDER and not re.fullmatch(r"`?[0-9a-f]{7,40}`?", rev):
        errors.append("Language revision must be a commit hash")
    for c in CHECKS:
        if f"- [x] {c}" not in got.get("Checks", "") and f"- [X] {c}" not in got.get("Checks", ""):
            errors.append(f"check not ticked: {c}")
    return errors


def main(argv):
    if len(argv) == 1 and argv[0] == "template":
        sys.stdout.write(template())
        return 0
    if len(argv) == 2 and argv[0] == "check":
        errors = check(Path(argv[1]).read_text(encoding="utf-8"))
        if errors:
            print("\n".join(errors), file=sys.stderr)
            return 1
        print("finding body complete")
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
