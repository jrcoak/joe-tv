# Joe-TV accepted decisions

| ID | Decision | Basis |
| --- | --- | --- |
| TEAM-001 | Improve the existing Joe-TV app; do not start over. | Joe's team-setup request. |
| TEAM-002 | Seven persistent roles: PM, Design, App, Playback, Services, QA, SecOps. Reuse this setup task as PM. | Requested team structure and proposed setup. |
| TEAM-003 | Exclude SHELF. Preserve the existing app work; adopt its committed baseline independently of the other task's release operation (TEAM-011 supersedes the initial wait). | Joe's explicit clarification. |
| TEAM-004 | Track work and decisions in the repository; omit Notion and Northstar. | Joe: irrelevant; skip them. |
| TEAM-005 | Services coordinates app, Personal Media API, and Mac mini publisher changes. | Joe authorized coordinated project changes. |
| TEAM-006 | First team milestone: assessment plus concrete innovation ideas and a recommended next milestone. No speculative app implementation or extra release in M0. | Joe wants innovation and ideas; no specific feature selected. |
| TEAM-007 | Use the simulator as much as practical. Joe assists with physical-device checks, including FairPlay and remote behavior that simulation cannot establish. | Joe's device-testing preference. |
| TEAM-008 | Existing task owns the in-progress commit and next TestFlight build. Setup uses its own worktree and the committed app baseline (TEAM-011). | Joe's latest steering. |
| TEAM-009 | Keep configured model defaults; no scheduled coordination or additional agents installed as part of setup. | Working default; source spec describes model choice as an observation and defers recurring meetings. |
| TEAM-010 | Add SecOps as the sixth specialist, for seven roles including PM. Include security in design, implementation, and release review. | Joe explicitly requested a SecOps agent. |
| TEAM-011 | Begin from app commit `c08e551038bfbeaf7d2fdcc60c0b3e3021cd25b8` in a separate integration worktree while the original task finishes TestFlight. Its build-7 project-file change remains untouched. | Joe confirmed the commit is done and told setup to start. |

| TEAM-012 | Integrate release task commit `138c2714805ce47d26f0da5c3d9d8cf48bd488b8` (build number 7) into PM branch. Specialist assessment source remains c08e551 plus bootstrap 314968d; the only release delta is the build number. | Fresh Git inspection; original checkout stays untouched. |

| TEAM-013 | Highest priority is UI polish, performance, simple intuitive navigation, and fewer heavy click paths. Explore left-side Plex-like primary navigation and a future curated Home using favorite teams such as Patriots/Bruins. These future directions do not authorize an immediate layout replacement. | Joe's latest product direction; spec advanced to TEAM-2. |

Product history and superseded alternatives are summarized separately in `product-context.md`. New accepted choices receive a dated entry with rationale and source; proposals are not silently added to this table.
