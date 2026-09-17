# Joe-TV team roster

Status: six specialist tasks created in isolated worktrees; onboarding and M0 assessment in progress.
Codex project: SeasonsTV (`8f337b91-9b82-4cb2-b34e-d23cb87622a8`)
Repository: `/Users/joecoakley/SeasonsTV`
Spec revision: TEAM-2 (UI/performance priorities; original technical assessments began at TEAM-1)
App baseline: c08e551038bfbeaf7d2fdcc60c0b3e3021cd25b8
Team bootstrap: `314968dc10f0bd73451ed6b0876a7fc7ed5c5233`
PM additionally integrated release build-number commit `138c2714805ce47d26f0da5c3d9d8cf48bd488b8`; application code is otherwise identical.

| Role | Exact task ID | Host | Worktree | Branch | Assignment |
| --- | --- | --- | --- | --- | --- |
| PM / Integrator | `01a0ad24-56de-73e1-b5de-5a0fdc8c49ff` | local | `/Users/joecoakley/.codex/worktrees/joe-tv-team-pm` | `codex/joe-tv-team` | M0 coordination |
| Product Design | `01a0ad34-9969-7ce1-9a82-a53fe7b979e9` | local | `/Users/joecoakley/.codex/worktrees/3770/SeasonsTV` | `codex/joe-tv-design` | M0-DESIGN |
| tvOS App | `01a0ad34-a194-7232-bde5-886ee0c7fb35` | local | `/Users/joecoakley/.codex/worktrees/0b9c/SeasonsTV` | `codex/joe-tv-app` | M0-APP |
| Playback | `01a0ad34-ab28-7012-94c5-ed6e82ea8f8e` | local | `/Users/joecoakley/.codex/worktrees/52e6/SeasonsTV` | `codex/joe-tv-playback` | M0-PLAYBACK |
| Services | `01a0ad34-b79b-7253-a48c-8667f351276e` | local | `/Users/joecoakley/.codex/worktrees/cc62/SeasonsTV` | `codex/joe-tv-services` | M0-SERVICES |
| QA | `01a0ad34-d1be-78d0-b050-35a67462b35d` | local | `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV` | `codex/joe-tv-qa` | M0-QA |
| SecOps | `01a0ad34-c2ad-7e22-ae18-3468ca71fa88` | local | `/Users/joecoakley/.codex/worktrees/345c/SeasonsTV` | `codex/joe-tv-secops` | M0-SECOPS |

PM owns this roster. Task titles are descriptive; route by exact ID. Worktrees and branch names are recorded from actual task reports rather than guessed.

## Existing release owner

`Clone joe-tv repository`, task `01a0370d-dbdd-7ed1-8e23-e8be05509ccb`, local host, owns the current commit and next TestFlight release. Its release turn is now idle and its build-7 source commit is integrated in the PM branch. Team setup must not change its original checkout, simulator session, release configuration, or upload. Current App Store processing status is not asserted here. It is a historical/release task, not an additional permanent specialist.

## Ongoing use

Give a request to PM. PM consults the appropriate specialists, defines a bounded milestone, assigns owned work, integrates sequentially, and requests independent QA. Specialists idle between assignments. New feature ideas go through the same prioritization process rather than creating autonomous scope.

## Messaging verification

Five onboarding callbacks reached PM. App's outbound callback was rejected by automatic approval review on destination-authorization grounds; PM retrieved its report/commit through Git and task status instead. PM-to-App follow-up succeeds. Use final responses plus `wait_threads`/`read_thread` as a supported fallback; do not require Joe to relay messages or retry rejected sends in a loop.
