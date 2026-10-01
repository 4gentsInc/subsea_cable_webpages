#!/usr/bin/env python3
"""Validate and synchronize the managed language-intake labels in .github/labels.json.

The file is canonical only for the labels it lists. Other repository labels
(for example GitHub's defaults) are unmanaged: `sync` keeps them and `diff`
lists them without treating them as drift.

Usage:
  python .github/scripts/labels.py validate
  python .github/scripts/labels.py diff  --repo OWNER/NAME   # read-only drift report
  python .github/scripts/labels.py sync  --repo OWNER/NAME   # create/update, never delete

`diff` and `sync` use the GitHub REST API with the token in GH_TOKEN or
GITHUB_TOKEN. `sync` never deletes a label that is absent from the file; it
reports it as unmanaged instead.
"""
import argparse
import json
import os
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

LABELS = Path(__file__).resolve().parents[1] / "labels.json"
COLOR = re.compile(r"^[0-9a-f]{6}$")
REQUIRED_PREFIXES = ("finding", "area:", "triage:", "scp-candidate",
                     "editorial-fix", "wontfix:", "moved:", "proposal:")


def load(path=LABELS):
    return json.loads(path.read_text(encoding="utf-8"))


def validate(labels):
    errors = []
    if not isinstance(labels, list) or not labels:
        return ["labels.json must be a non-empty list"]
    seen = set()
    for i, lab in enumerate(labels):
        where = f"entry {i}"
        if not isinstance(lab, dict) or set(lab) != {"name", "color", "description"}:
            errors.append(f"{where}: must have exactly name, color, description")
            continue
        name, color, desc = lab["name"], lab["color"], lab["description"]
        where = f"label {name!r}"
        if not isinstance(name, str) or not name or name != name.strip() or len(name) > 50:
            errors.append(f"{where}: name must be 1-50 chars without surrounding spaces")
        key = name.casefold() if isinstance(name, str) else name
        if key in seen:
            errors.append(f"{where}: duplicate name (GitHub label names are case-insensitive)")
        seen.add(key)
        if not isinstance(color, str) or not COLOR.match(color):
            errors.append(f"{where}: color must be 6 lowercase hex digits without '#'")
        if not isinstance(desc, str) or not desc or len(desc) > 100:
            errors.append(f"{where}: description must be 1-100 chars")
        if isinstance(name, str) and not name.startswith(REQUIRED_PREFIXES):
            errors.append(f"{where}: name must use a documented prefix {REQUIRED_PREFIXES}")
    if "finding" not in seen:
        errors.append("the 'finding' label must exist; the issue form applies it")
    return errors


def api(method, url, token, body=None):
    req = urllib.request.Request(url, method=method,
                                 data=None if body is None else json.dumps(body).encode())
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    if body is not None:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read() or b"null")


def remote_labels(repo, token):
    out, page = {}, 1
    while True:
        batch = api("GET", f"https://api.github.com/repos/{repo}/labels?per_page=100&page={page}", token)
        for lab in batch:
            out[lab["name"].casefold()] = lab
        if len(batch) < 100:
            return out
        page += 1


def plan(labels, remote):
    create, update = [], []
    for lab in labels:
        cur = remote.get(lab["name"].casefold())
        if cur is None:
            create.append(lab)
        elif (cur["name"], cur["color"].lower(), cur.get("description") or "") != \
                (lab["name"], lab["color"], lab["description"]):
            update.append((cur["name"], lab))
    managed = {lab["name"].casefold() for lab in labels}
    unmanaged = sorted(v["name"] for k, v in remote.items() if k not in managed)
    return create, update, unmanaged


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("command", choices=["validate", "diff", "sync"])
    p.add_argument("--repo", help="target repository; required for diff and sync")
    args = p.parse_args(argv)
    if args.command != "validate" and not args.repo:
        p.error("--repo OWNER/NAME is required for diff and sync")
    labels = load()
    errors = validate(labels)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    if args.command == "validate":
        print(f"labels.json valid: {len(labels)} labels")
        return 0
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if not token:
        print("set GH_TOKEN or GITHUB_TOKEN", file=sys.stderr)
        return 2
    create, update, unmanaged = plan(labels, remote_labels(args.repo, token))
    for lab in create:
        print(f"create  {lab['name']}")
    for old, lab in update:
        print(f"update  {old} -> {lab['name']}")
    for name in unmanaged:
        print(f"unmanaged (kept) {name}")
    if args.command == "diff":
        return 1 if (create or update) else 0
    apply(args.repo, token, create, update)
    print(f"synced: {len(create)} created, {len(update)} updated")
    return 0


def apply(repo, token, create, update):
    base = f"https://api.github.com/repos/{repo}/labels"
    for lab in create:
        api("POST", base, token, lab)
    for old, lab in update:
        api("PATCH", f"{base}/{urllib.parse.quote(old, safe='')}", token,
            {"new_name": lab["name"], "color": lab["color"], "description": lab["description"]})


if __name__ == "__main__":
    sys.exit(main())
