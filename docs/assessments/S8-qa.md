# S8 QA — HLS transport user-agent repair

September 28, 2026. Assignment `S8-TRANSPORT`, integrated source `c59d175328fde250aad1eb86dfb689e0c370ee53`, QA branch `codex/joe-tv-qa-s8`. Source disposition: accepted with no concrete blocker found.

The change correctly centralizes the existing Seasons4U HTTP user agent in `SeasonsClient.playbackUserAgent` and applies it through `AVURLAssetHTTPUserAgentKey` to the non-DRM HLS asset. AppModel supplies it at the three intended S4U construction paths: sports direct HLS, sports request-resolved HLS, and S4U live-channel request-resolved HLS. The optional initializer default preserves the prior system-agent behavior for debug fixtures, Very Local and non-DRM PBS. The FairPlay initializer and certificate/license path remain unchanged.

The call-site review found no missed S4U non-DRM path in the integrated source. ESPN+ remains DRM-page playback; Very Local and PBS use their own playback cases. The user agent is also reused by the existing authenticated Seasons4U URLSession, preserving request and playback identity without adding cookies, Origin, Referer, retries or alternate-feed behavior.

`sh scripts/test-football-playback-refresh.sh` passed 35 checks in this QA worktree. The existing suite covers football metadata refresh and stable feed identity; its FairPlay deprecation warning is unchanged. PM reported the integrated tvOS type-check, parser checks, failure-diagnostics suite and configured Debug build passing. Those checks were not rerun here because PM owns the assigned build/runtime session.

PM measured the same CBS master request with the default Python user agent returning HTTP 403 and Joe-TV's user agent returning HTTP 200 with a valid HLS playlist; the configured Debug app then showed advancing CBS New York video frames before the stream was stopped. This establishes a clear-HLS transport repair at the observed master request. It does not prove child-resource behavior, DRM/FairPlay, NFL behavior, every provider route, or the exact original TNF failure cause.

No provider request, credential use, build, simulator operation, device operation, release, deployment or app-code edit was performed by QA. Physical FairPlay, NFL and any serialized real-stream validation remain pending; the report does not claim those outcomes.
