# Joe-TV team operating model

This adapts Joe's supplied Agent Team Specification to the existing Joe-TV application. The six specialist charters are in `tvos-specialists.md`; accepted product requirements are in `../spec.md`.

## Sources of truth

| Concern | Source |
| --- | --- |
| Current scope and acceptance | Joe's current request and `spec.md` |
| Shared instructions | `AGENTS.md` |
| Role IDs, branches, worktrees | `docs/team.md` |
| Assignments and status | `docs/assignments/M0.md`, `docs/assignments/R1.md`, then one file per later milestone |
| Accepted decisions | `docs/decisions.md` |
| Historical context | `docs/product-context.md` and its linked source task |
| Implementation and verification | Named Git commits and exact test evidence |

Joe explicitly excluded Notion and Northstar. Do not attempt to connect or synchronize them.

## Persistent roles, bounded runs

Use PM / Integrator, Product Design, tvOS App, Playback, Services, QA, and SecOps. These are seven persistent Codex tasks, not seven agents that must run continuously. Their conversations and files are separate. Deliver necessary context explicitly; common project membership does not synchronize it.

Joe authorizes PM to choose models and reasoning effort per assignment. Use strong reasoning for architecture, security, ambiguous design and cross-role synthesis; use a capable lighter model for bounded extraction, repeatable checks or small well-specified edits. Escalate if evidence or quality is weak. Do not default every task to maximum effort or optimize price at the expense of a reliable result. Record explicit overrides in assignments; verify availability when assigning. Fernando's choices are historical context, not mandatory settings.

At the end of an assignment, send one useful handoff to PM and become idle. PM replies only with an actionable assignment or needed decision; avoid acknowledgment loops. No recurring schedule is installed by this setup. Resume the same team when Joe requests the next milestone.

## Baselines and integration

1. Joe authorized startup from committed app baseline `c08e551038bfbeaf7d2fdcc60c0b3e3021cd25b8`. The original checkout has a release-owned build-number bump from 6 to 7; leave it untouched. Do not interfere with that task's simulator, signing, archive, or upload. Reconcile its final commit separately.
2. Commit shared instructions on the PM integration branch. Do not include `SHELF/`, private configuration, or unrelated files.
3. Create specialist tasks in managed worktrees. Their bootstrap instruction moves each pristine worktree to a unique `codex/` branch at the same shared-instruction commit before edits. Verify their reported branch/path/HEAD.
4. PM alone maintains the integration branch. Workers return bounded commits; PM integrates ready changes one at a time.
5. QA verifies the combined result at an exact commit. A worker's build does not substitute for integrated verification.
6. Requirements changes get a decision ID and commit. PM sends the delta and revision to affected workers, who acknowledge before affected work continues.

Protect the user's original checkout and any unrelated task still using it. Prefer a separate integration worktree when the original checkout remains active. Each coding worktree has its own build cache. Shared external resources need explicit coordination.

## Assignment format

Every work package names an ID, role/task ID, objective, product-spec revision, starting commit, allowed files or symbols, dependencies, acceptance criteria, verification, and expected deliverable. Tell workers what they may implement and what remains a proposal.

Use purpose-built task tools to send assignments, read status, and wait for completion. If a worker's outbound message is unavailable or rejected, PM retrieves its final report via task status and its commit; never force Joe to act as a message relay. Route by recorded task ID. Do not infer IDs from titles. Read a compact progress snapshot or wait with the last cursor; don't repeatedly request unchanged status.

## Runtime sessions

The assignment file records the owner of shared simulator/device/real-stream activity. Other workers can inspect source or run their own offline compilation but must not take that simulator/device. Serialize expensive builds where resource contention would make testing unreliable.

Real Seasons4U playback is a single controlled session across the entire team. The owner confirms no conflicting team playback, coordinates with Joe if his device may be using the account, tests one stream, stops it, and reports release of the resource. Do not use a burst of stream requests as a health check.

Use Debug fixtures for parallel UI development. Never claim fixture data is a live integration. FairPlay hardware coverage is pending until tested with a signed build on actual Apple TV. Preserve simulator sessions and saved preferences.

## Cross-repository services work

Services establishes a map of Joe-TV, Personal Media API source, and deployed Mac mini publisher paths. For each change, record repository/branch/commit, API compatibility, publisher artifact/version, tests, and ordered rollout/rollback instructions. Joe has authorized coordinated project work; that does not turn every source assignment into a production deployment.

No exact backend checkout or remote mount is assumed healthy based on an old conversation. Discover read-only and report unavailable access accurately. PM assigns any required live environment change explicitly.

## Innovation workflow

Every specialist contributes two or three grounded opportunities. For each, describe a specific viewer situation, proposed behavior, what already exists, the smallest experiment, dependencies, and validation. Include confidence and rough effort, not invented performance gains or delivery guarantees.

Design may sketch a new idea in its owned report. App, Playback, and Services assess feasibility; QA describes how to tell whether the idea improves the experience; SecOps evaluates relevant trust and credential implications. PM combines overlaps into a short ranked portfolio: useful near-term improvements and a small number of larger experiments. Joe chooses the next implementation milestone.

SecOps reviews assignments involving authentication, credentials, networking/URLs, provider parsing, dependencies, permissions, or releases. Routine visual edits do not require a ceremonial security gate. Confirmed material risks get a bounded remediation assignment and independent review; vague hypothetical concerns do not halt unrelated work.

## Standups and fresh context

Keep this PM task as Joe's primary contact. Joe clarified standups are internal PM/specialist coordination. Use a fresh coordinator subagent for one bounded checkpoint review; keep specialist assignment contexts intact and provide project state explicitly. Return conflicts, dependencies and proposed next steps to PM. See `docs/standups/README.md`. No user-owned standup task or recurring schedule is created.

## Completion and recovery

A worker handoff includes assignment ID, baseline/spec, summary, branch/commits, checks/results, limitations, and integration notes. Send it to the PM task once; then end the turn.

PM delivers the integrated commit, assessment/acceptance results, ideas, next-milestone recommendation, and pending hardware checks. Stop at the milestone; do not automatically launch the next idea.

On resumption, read the roster, decisions, current assignment file, relevant task snapshots, and Git state. Reconcile completed and in-flight work before assigning anything. Revalidate runtime ownership after interruptions. Never assume that an old worktree, host path, simulator, or deployment still exists.

## References

- Joe's supplied `Spec.txt` and `tvOS Specialist Charters.txt` (September 16, 2026), adapted by the current user decisions.
- [Codex Git worktrees](https://learn.chatgpt.com/docs/environments/git-worktrees): separate checkouts, shared Git metadata, managed-worktree lifecycle.
- [Joe-TV development history](https://chatgpt.com/s/cx_6aab4d0d169c81918e2420b5e59f014f): historical evidence, with later decisions superseding earlier alternatives.
