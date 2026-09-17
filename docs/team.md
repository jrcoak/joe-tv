# Joe-TV team roster

Status: **S1 integrated candidate in QA; R2 shortlist complete**; M0/R1 setup and research complete. See docs/assignments/S1.md for current ownership.
Codex project: SeasonsTV (`8f337b91-9b82-4cb2-b34e-d23cb87622a8`)
Repository: `/Users/joecoakley/SeasonsTV`
Spec revision: TEAM-4 (small implementation sprint authorized). Original technical assessments retain TEAM-1 provenance; Design/App adopted TEAM-2.
App baseline: c08e551038bfbeaf7d2fdcc60c0b3e3021cd25b8
Team bootstrap: `314968dc10f0bd73451ed6b0876a7fc7ed5c5233`
PM integrated release build-number commit `138c2714805ce47d26f0da5c3d9d8cf48bd488b8`. S1 application changes are now being assembled separately on the team branch.

| Role | Exact task ID | Host | Worktree | Branch | Assignment |
| --- | --- | --- | --- | --- | --- |
| PM / Integrator | `01a0ad24-56de-73e1-b5de-5a0fdc8c49ff` | local | `/Users/joecoakley/.codex/worktrees/joe-tv-team-pm` | `codex/joe-tv-team` | S1 integration |
| Product Design | `01a0ad34-9969-7ce1-9a82-a53fe7b979e9` | local | `/Users/joecoakley/.codex/worktrees/3770/SeasonsTV` | `codex/joe-tv-design-s1` | S1-DESIGN |
| tvOS App | `01a0ad34-a194-7232-bde5-886ee0c7fb35` | local | `/Users/joecoakley/.codex/worktrees/0b9c/SeasonsTV` | `codex/joe-tv-app-s1` | S1-APP |
| Playback | `01a0ad34-ab28-7012-94c5-ed6e82ea8f8e` | local | `/Users/joecoakley/.codex/worktrees/52e6/SeasonsTV` | `codex/joe-tv-playback-s1` | S1-PLAYBACK |
| Services | `01a0ad34-b79b-7253-a48c-8667f351276e` | local | `/Users/joecoakley/.codex/worktrees/cc62/SeasonsTV` | `codex/joe-tv-services-r2` | R2-SERVICES |
| QA | `01a0ad34-d1be-78d0-b050-35a67462b35d` | local | `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV` | `codex/joe-tv-qa-s1-candidate` | S1-QA |
| SecOps | `01a0ad34-c2ad-7e22-ae18-3468ca71fa88` | local | `/Users/joecoakley/.codex/worktrees/345c/SeasonsTV` | `codex/joe-tv-secops-s1-s2` | SECURITY-S1-S2 complete |

PM owns this roster. Task titles are descriptive; route by exact ID. Worktrees and branch names are recorded from actual task reports rather than guessed.

## Existing release owner

`Clone joe-tv repository`, task `01a0370d-dbdd-7ed1-8e23-e8be05509ccb`, local host, owns the current commit and next TestFlight release. Its release turn is now idle and its build-7 source commit is integrated in the PM branch. Team setup must not change its original checkout, simulator session, release configuration, or upload. Current App Store processing status is not asserted here. It is a historical/release task, not an additional permanent specialist.

## Ongoing use

Give a request to PM. PM consults the appropriate specialists, defines a bounded milestone, assigns owned work, integrates sequentially, and requests independent QA. Specialists idle between assignments. New feature ideas go through the same prioritization process rather than creating autonomous scope.

## Messaging verification

Five onboarding callbacks reached PM. App's outbound callback was rejected by automatic approval review on destination-authorization grounds; PM retrieved its report/commit through Git and task status instead. PM-to-App follow-up succeeds. Use final responses plus `wait_threads`/`read_thread` as a supported fallback; do not require Joe to relay messages or retry rejected sends in a loop.

## Completed M0/R1 checkpoint

All six baseline reports, both TEAM-3 research reports and independent integrated QA are received. All M0/R1 specialist assignments are complete; their reports are historical evidence for subsequent implementation. QA accepted assembled commit `28e3406c7aa67787537faa53d17bbbfb0b01b8da`; report commit `82e8ea5a9dd1e68158a96fa12c294d9f106d3b75` is integrated. The runtime was released at that checkpoint; the active S1 grant below supersedes that completed session.

Read [roadmap](roadmap.md), [assessment](assessments/summary.md), and [internal standup protocol](standups/README.md). Setup lives on codex/joe-tv-team and has not been merged/pushed to main. Future tasks must receive this branch/commit explicitly until integration into main is separately selected.

## S1 runtime and branch handoff

QA owns only the dedicated Joe-TV Team QA simulator for this sprint, through the next baseline/final verification checkpoint. Other roles must not operate it. Role worktrees remain the same; listed S1/R2 branches have been verified. Design and Playback commits are integrated; QA baseline is integrated and the simulator is shut down between checkpoints. App implementation is in progress, with final combined verification pending. No real provider playback or release runtime is assigned.

## Active candidate checkpoint

Candidate `f394d4d356851092ae579051cff5a5a667d53cdb` passed fresh smoke and unsigned Debug build 7; QA UI acceptance is pending, with a cleanly reproduced guide-origin player focus problem under investigation. Home origin, Quick Switch origin preservation and removed-favorite fallback have passed sampled journeys. App/Playback are diagnosing without changing the frozen candidate. SecOps found no source-identified S1 fixture security blocker; see `sprints/S1-S2-secops.md` for precise isolation limits. R2 shortlist is integrated; no streams have been added or tested.
