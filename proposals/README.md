# Public Subsea Cable Proposals

Submit an evidence-backed proposal through the **Subsea Cable Proposal (SCP)**
[issue form](https://github.com/4gentsInc/subsea_cable_webpages/issues/new/choose),
or open a Draft PR as `draft-<topic>.md` using [TEMPLATE.md](TEMPLATE.md). Maintainers allocate SCP numbers during review.

SCP issues and these files are public intake and discussion records. Merging a Draft or
Discussion proposal does not activate language semantics. The canonical
activation must synchronize the Accepted decision, specification, grammar,
and conformance in the language source repository.

After an effective decision is published, link its decision-log entry and
effective language revision from the discussion record. Use the **Language finding** form for observations that
do not yet have proposal-level analysis.

## Published decisions: one append-only log

The documentation publishes Accepted decisions only through a single decision
log, `SCP.md`. The log is append-only: each activation adds one entry at the
end, and existing entries are never edited, reordered, or removed.

Each entry records only the final accepted result:

- SCP number and title;
- status (`Accepted`) and the effective language revision;
- the accepted decision, stated as the resulting rule and its scope;
- the earlier decisions or clauses it supersedes, if any.

An entry omits the process that led to the decision: motivation narrative,
alternatives considered, review discussion, evidence, experiments,
implementation references, and drafting history. Maintainers' full working
records are not published.

A later change never rewrites an earlier entry. Supersession, correction, or
withdrawal of an accepted rule is recorded as a new entry that names the entry
it affects. To find the current rule for a topic, read the log from the end.

Proposals stay proposals. An SCP issue or Draft record here is discussion and
is not added to the log. Only a proposal that becomes Accepted through
activation appears in the log, in its compact final form. Rejected, withdrawn,
or superseded-before-acceptance proposals produce no log entry.

The log records which decisions took effect. The canonical rules themselves
remain in the Language Reference, grammar, Runtime Contract, and conformance
documents; a log entry is not a second normative copy of them.
