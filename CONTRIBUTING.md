# Contributing

Read [the language documentation](https://4gentsInc.github.io/subsea_cable_webpages/)
and identify the language revision or specific page you used. If you do not know
the source revision, provide the documentation URL and date read (YYYY-MM-DD).

External contributors report here. Language developers with source-repository
access may report directly there using the same finding and SCP forms. Link
related intake records rather than filing duplicates.

## Findings

Report one observed ambiguity, gap, conflict, or ergonomics problem per issue
using the **Language finding** form. Include the smallest Voyage Plan, exact
clauses or page links, expected versus observed behavior, and relevant evidence.
A finding records a problem; it does not select a new language rule.

For CLI or API submissions:

```sh
python .github/scripts/finding.py template > finding.md
# Fill every required section.
python .github/scripts/finding.py check finding.md
gh issue create --repo 4gentsInc/subsea_cable_webpages --label finding \
  --title "[finding] <short summary>" --body-file finding.md
```

Runtime-specific bugs and profiles belong with their implementation. If unsure,
report the finding here and maintainers will route it.

## SCP proposals

Use the **Subsea Cable Proposal (SCP)** issue form for a worked-out proposal.
It applies `proposal:scp`, identifying Draft intake rather than an Accepted or
effective change. Maintainers allocate SCP numbers during review.

You may also create `proposals/draft-<topic>.md` from
[the intake template](proposals/TEMPLATE.md) and open a PR. Explain the problem, evidence, alternatives including no language
change, recommendation, compatibility impact, and proposed conformance changes.
An existing finding is useful but is not required for a complete direct proposal.

This is the public discussion and intake record. Maintain the issue or Draft record here through
review. Opening or closing an SCP issue does not accept or activate it. Maintainers reference it when preparing the canonical decision and
activation in the language source repository; public PR merge alone does not
make the proposed behavior effective. Final status should link the published
decision-log entry and identify the effective language revision.

Accepted decisions are published only as compact entries in the append-only
decision log `SCP.md`, which records the final accepted result without the
proposal process. See [Published decisions](proposals/README.md#published-decisions-one-append-only-log).

## Website changes

Builder changes belong here. Document-original corrections can be described in
an issue or proposal with page links; source maintainers integrate them into the
language source repository. Do not add editable language-document copies here.

If you have the arranged source directory, run `python scripts/build.py` and
include the updated `build/` output. Otherwise explain that the builder change
needs a maintainer rebuild. Never add source-access credentials to a PR.
