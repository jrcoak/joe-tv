# Internal Joe-TV team standups

Joe means coordination between PM and the specialist agents. He does not need to attend a status meeting or manage a separate standup task.

## Recommended mechanism

Use one fresh coordinator subagent for a bounded internal standup at a meaningful checkpoint. Give it the exact integration commit, active assignment, roster and relevant handoffs. The coordinator reads current project state and compact specialist status, identifies blockers, conflicting assumptions, overlapping ownership and dependency order, then returns a short brief to PM.

Keep existing specialists in their working contexts during their assignment. Do not launch six fresh copies, force every idle specialist to respond, or replace the PM task. Request a specialist update only when available evidence cannot answer a concrete coordination question. Fresh context is supplied explicitly; shared project membership is not shared conversation memory.

PM retains authority over assignments, integration and runtime sessions. A standup coordinator is read-only and cannot reassign work, edit shared files, start a deferred feature, operate a simulator, or release software. PM integrates any resulting plan or decision changes.

## Inputs and output

Read AGENTS.md, spec.md, docs/team.md, the active assignments, docs/roadmap.md when available, and recent decisions. Reconcile reported status with Git/test evidence and live task snapshots. Until setup is merged, default main does not include the team documents; use the explicit integration baseline.

Use template.md. Return only meaningful deltas: completed work with commit/test evidence, active dependencies, conflicts/blockers, and proposed next actions with owners. Distinguish observed evidence, reports, and unknowns. Include no secrets or signed playback URLs.

Joe receives a concise PM outcome when useful, and decisions requiring his input. Internal housekeeping does not require a user-facing status meeting.

## Trigger and lifecycle

Recommended triggers: the end of a research/assessment batch, before assigning implementation, a material blocker, a shared-interface change, and before integration/release validation. No recurring schedule is installed. A request for scheduled standups needs a cadence and a supported automation configuration separately.

Start a fresh coordinator for each requested/assigned standup; finish after one brief. Do not create a persistent user-owned task for an internal coordination subtask. Specialist roles and project memory remain durable in the repository and roster.

## Coordinator brief

> Conduct one internal Joe-TV team standup at the supplied integration commit. Read the active assignments, roster, decisions and relevant reports; reconcile compact specialist status with Git/test evidence. Return completed outcomes, active dependencies, conflicts or blockers, and the smallest proposed next actions with owners. Do not modify files, message or reassign specialists, create tasks, operate runtime resources or implement features. Return the brief to PM and finish.

[OpenAI project guidance](https://learn.chatgpt.com/docs/projects) supports focused tasks with durable guidance in AGENTS.md or committed documentation. This coordination protocol is a project choice, not a built-in standup feature. Reference checked September 16, 2026 (America/New_York).
