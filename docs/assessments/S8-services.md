# S8 — Sports schedule single-flight refresh

- Assignment: S8 Services incident correction
- Baseline: `a6eaf61`
- Branch: `codex/joe-tv-services-s8`
- Scope: `XMLTVGuideProvider` sports-schedule request coalescing and deterministic offline cache regression coverage

## Incident evidence

PM measured a first launch whose Sports model showed one live ESPN+ item and no upcoming schedule items even though the simulator cache file was replaced at `18:51:59Z` with the current 131-event publication. Parsing, enrichment and consolidation of those exact cached bytes offline produced the expected upcoming NFL event. A metadata-only relaunch against the same cache then showed ten upcoming items for the enabled sports.

The source permits that split state. `AppModel.loadContent` starts an unstructured sports refresh after catalog load, while `JoeTVSportsView.onAppear` can call the combined sports loader while either schedule or ESPN+ state remains idle. Each schedule call replaces `sportsScheduleRequestID`. Before this change, the actor recorded `sportsLastAttempt` immediately before awaiting the network. Actor reentrancy then allowed an overlapping call to enter the five-minute throttle branch and return the old cache. That later AppModel call could publish the old snapshot, while the original network call wrote fresh bytes to disk and was then discarded by its superseded request ID.

This sequence is confirmed as possible from the source and closely fits the measured disk/model divergence. The prior run was not instrumented with request IDs, so the report does not claim the exact interleaving was directly observed. The separately reproduced CBS playback failure is unrelated to this schedule-cache correction.

## Change

`XMLTVGuideProvider.loadSportsSchedule` now installs one actor-owned `Task<SportsScheduleSnapshot, Error>` before entering cache/throttle/network work. Overlapping callers await that same task, so a follower cannot read the pre-refresh cache while the leader is suspended in `URLSession`. The initiating caller clears the task after both success and failure. The fully injected provider initializer accepts a no-op-by-default join observer so the offline regression can coordinate on the follower actually entering the single-flight branch; the normal app initializer always uses the no-op observer.

The existing cache lifecycle remains inside `currentSportsSchedule`: validation occurs before cached bytes are used, request attempts and successful refreshes retain their existing timestamps, conditional ETags and HTTP handling are unchanged, valid transport fallback remains unchanged, and guide/EPG loading is untouched.

## Verification

- `scripts/test-guide-cache.sh`: passed. A held `URLProtocol` response is released only after an injected observer proves the second sports caller joined the first in-flight task. Both callers receive the fresh publication and only one HTTP request is made, with both a stale cache and no cache. A subsequent request after the five-minute boundary proves successful-task cleanup. A second held scenario proves both callers receive the same HTTP failure and a later successful request proves failure-task cleanup. The existing guide and sports cache lifecycle matrices also pass.
- `scripts/team-check.sh smoke`: passed.
- `git diff --check`: passed.

The existing FairPlay deprecation warning remains. No provider request, app runtime, simulator operation, stream, credential access, publisher change, deployment or release was performed. Competitive comparison does not apply to this bounded cache-consistency incident because the acceptance target is deterministic delivery of an already supported publication.
