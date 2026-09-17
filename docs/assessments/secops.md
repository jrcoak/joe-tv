# M0-SECOPS — Joe-TV security assessment

## 1. Assignment and evidence boundary

- Assignment: M0-SECOPS; accepted specification: TEAM-1.
- Task: `01a0ad34-c2ad-7e22-ae18-3468ca71fa88`, host `local`.
- Worktree: `/Users/joecoakley/.codex/worktrees/345c/SeasonsTV`.
- Branch: `codex/joe-tv-secops`.
- App baseline: `c08e551038bfbeaf7d2fdcc60c0b3e3021cd25b8`.
- Assessment starting HEAD/shared instructions: `314968dc10f0bd73451ed6b0876a7fc7ed5c5233`. All source evidence below refers to this commit. The report-only commit is identified in the completion handoff.
- Initial managed worktree was clean, detached at `138c2714805ce47d26f0da5c3d9d8cf48bd488b8`. The assigned branch did not exist and was created at the requested shared-instruction commit. No release changes were carried into this assessment.

Read all required team documents. Inspected tracked authentication and provider clients, `HTMLCatalogParser`, `MediaAPIConfiguration`, `XMLTVGuideProvider`, FairPlay loader, relevant `AppModel`/`Models`/`RootView` flows, configuration templates, Info.plist/privacy manifest, Xcode build settings, build validation and logo-import scripts, and relevant parser fixtures. Read historical README/handoff/playback notes only as context.

This is a source assessment with a small synthetic build-guard check. No private configuration contents, cookie stores, credentials, signed media, actual app archives, production systems, publisher installations, or unrelated SHELF files were inspected. No simulator, device, authenticated request, or provider stream was used. No app code changed. No critical/high-severity exposure was established within this evidence boundary; deployed token privileges and publisher controls remain unverified.

## 2. Existing strengths and behavior to preserve

| Boundary | Source observation and security implication |
| --- | --- |
| Provider login | `SeasonsTV/Networking/SeasonsClient.swift:142`, `signIn`, uses the fixed HTTPS login route, retrieves an anti-forgery token, form-encodes inputs, and delegates cookie handling to URLSession. `SeasonsTV/Views/RootView.swift`, `LoginView.submit`, clears the password after success. No password persistence operation was found in the reviewed source; the failed-login field retains it in view memory for retry. |
| Metadata authorization | `MediaAPIRequestBuilder.makeRequest` in `SeasonsTV/Networking/MediaAPIConfiguration.swift:74` attaches the bearer only to individual metadata GET requests. No global bearer header is installed on provider, ESPN, Sleeper, or player sessions. `SportsEventDetailIdentity.init(event:)` in `SeasonsTV/Models/Models.swift:767` restricts leagues and numeric event IDs; the detail decoder checks response identity. Preserve these boundaries. |
| Persistence | Preferences and Fantasy username/user/league IDs use UserDefaults; these IDs are personal configuration, not authentication credentials. `LegacyScheduleCredentialCleanup.run` deletes only the obsolete named Keychain item and retries on deletion failure. `XMLTVGuideProvider` writes metadata payloads and ETags, not the bearer. Keep existing namespaces and additive preference migration. |
| Playback credentials | `PlaybackTarget`/`PlaybackHistoryPolicy` retain identities rather than resolved media credentials. `AppModel.makePlaybackSession` resolves request/DRM sources on selection. Direct HLS catalog entries can still hold a URL in memory until catalog refresh; URL freshness is not universally guaranteed by the identity model. No signed-URL/SPC/CKC disk persistence was found in the inspected paths. |
| FairPlay | `FairPlayResourceLoader.fulfill` uses Apple's SPC API and supplies CKC to the resource loader; no persistent-key or DRM-bypass path was found. `PBSLiveClient.drmConfiguration` supplies fixed public-service endpoints and empty custom headers. `AppModel.makeDRMPlaybackSession` requires hardware outside Simulator. Preserve domestic/international/ESPN+ content-ID behavior. |
| Diagnostics | Only two application `print` sites were found in Swift source: `FairPlayResourceLoader.resourceLoader` and `PlaybackSession.handlePlayerStatus`. Both are Debug-only domain/code messages. They do not print URLs, headers, cookies, passwords, SPC, or CKC. |
| Build/configuration | Debug and Release include separate ignored private configurations. The project runs `scripts/validate-media-read-token.sh`; Info.plist has no ATS exceptions. No third-party package manifest/lockfile, downloaded build-time dependency, or custom trust-challenge bypass was identified in this app's tracked configuration. This does not audit Xcode, transitive platform components, or remote services. |

Apple documents shared default cookie storage and a private in-memory store for ephemeral sessions; shared here means the application's store, not arbitrary other apps' cookies. The Very Local client already uses an ephemeral session. [Apple cookie storage reference](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/httpcookiestorage).

## 3. Findings, prerequisites, and proportional response

### SEC-01 — Distributed metadata bearer relies on backend scope and lifecycle

**Rating:** Medium operational risk, conditional on token scope/distribution. **Confidence:** High in the bundle exposure; unknown in deployed enforcement. **Verification:** Source observed; no artifact extraction or backend test.

`SeasonsTV/Resources/Info.plist` expands `MediaReadToken`; `MediaAPIConfiguration.bundled` reads it into memory. `Config/Internal.example.xcconfig` correctly calls for a separate revocable, rate-limited, read-only token. Neither the client route enum nor the length check can enforce server permissions or distinguish a development/publisher token from a read token. There is no client token expiration/refresh contract; replacement normally requires new build configuration, while server revocation is outside this repository.

**Prerequisite/impact:** Someone with a distributed app artifact can recover its embedded bearer and issue requests independently of the television UI. With properly narrow read scope, the plausible exposure is metadata access and quota/service abuse. Write/admin compromise requires mistakenly broader server privileges; no such privileges were demonstrated. Revoking a shared token can also remove metadata access for every build that uses it. Moving the same static bearer to Keychain or obfuscating it would not remove the distribution boundary.

**Mitigation/owner:** Services and release owner document the exact allowed routes/methods, token cohort, issuer, revocation owner, rate policy, and replacement behavior. Publisher write credentials must be distinct from all app read credentials. PM coordinates any later deployment/rotation; none is authorized by this report.

**Smallest experiment/acceptance:** In the backend owner's local test environment, use synthetic read/write credentials to exercise approved GETs plus denied write/admin/refresh routes, wrong/revoked token, and rate-limit handling. Accept only explicit read scope, demonstrable read/write separation, and graceful metadata failure while provider playback remains usable. Confirm actual production policy separately through approved read-only configuration evidence; template comments are insufficient.

### SEC-02 — Provider-derived URLs and headers lack a destination contract

**Rating:** Medium conditional trust-boundary risk. **Confidence:** High in missing application checks; Medium in practical exploitability. **Verification:** Source trace only; no malicious payload execution or network probe.

`HTMLCatalogParser.parseDRMChannels`/`parseRows` check playable paths but not origin; `absoluteURL` (`SeasonsTV/Networking/HTMLCatalogParser.swift:1297`) accepts arbitrary absolute schemes/hosts. `parseDRMConfiguration` (`:466`) extracts HLS/certificate/license/proxy values and arbitrary header names/values from provider HTML. Its FairPlay region is an 8,000-character suffix, not a balanced JavaScript object. `FairPlayResourceLoader.fulfill` (`SeasonsTV/Playback/FairPlayResourceLoader.swift:47`) applies those headers to both certificate and license requests, including an explicit license URL or an SKD-derived URL. `SeasonsClient.loadDRMConfiguration` and `authenticatedData` have no origin/redirect policy. `directHLSURL` accepts HTTP as well as HTTPS, although `parseHLSURL` accepts HTTPS only and Very Local explicitly requires HTTPS.

**Prerequisite/impact:** A compromised/malformed provider page, compromised authorized delivery path, or controlled manifest/SKD value could redirect requests or provider-supplied entitlement headers/challenges to an unintended HTTPS destination, or simply break playback. This is a client request-routing concern, not evidence of server-side SSRF or decryption bypass. System cookies still follow platform domain rules; the source does not establish blanket Seasons4U cookie leakage to arbitrary hosts. No cross-origin redirect header behavior was measured. Missing URL validation alone does not establish plaintext transport: ATS remains enabled. [Apple ATS reference](https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSAppTransportSecurity).

`MediaAPIConfiguration.values` also accepts any scheme with a host; its tracked default is HTTPS. A bad private/CI base URL requires build-configuration control, rather than provider HTML control, but could direct the app bearer to the wrong host.

**Mitigation/owner:** Services and Playback agree a provider-specific contract: same-origin page/resolution routes; HTTPS, known certificate/license/proxy destinations; separately scoped headers per destination; explicit policy for redirects and SKD derivation. Validate media/metadata image schemes too, without assuming one fixed CDN or breaking PBS redirects. Reject unknown destinations with a recoverable viewer message. Keep system TLS verification; do not introduce fragile certificate pinning as a substitute.

**Smallest experiment/acceptance:** Extend synthetic fixtures to include unrelated HTTPS hosts, user-info URLs, HTTP/custom schemes, protocol-relative URLs, misleading FairPlay blocks, unapproved header names, and redirects through an offline URLProtocol fixture. Existing domestic/international/ESPN+/PBS fixtures must still produce their expected contracts; disallowed requests must be rejected before dispatch, with no entitlement header/SPC delivered to an unapproved sink. Hardware verification remains required before shipping a FairPlay change.

### SEC-03 — Local sign-out does not fully bound outstanding authorization work

**Rating:** Medium candidate defect on a shared television. **Confidence:** High in lifecycle omissions; Medium in end-to-end user reachability. **Verification:** Source inference; race not reproduced.

`SeasonsClient.clearLocalSession` (`SeasonsTV/Networking/SeasonsClient.swift:398`) deletes cookies by substring domain match; it makes no server logout request and does not cancel or recreate its URLSession. Cookie expiry and Secure/HttpOnly/SameSite attributes are provider-controlled and were not inspected. `AppModel.signOut` (`SeasonsTV/App/AppModel.swift:1658`) pauses/drops playback and invalidates some request IDs, but not `espnPlusRequestID`; `loadContent` has no session-generation guard. `playMediaItem`, `playLiveChannel`, and `switchPlayback` await network resolution and then call `installPlaybackSession` without checking whether sign-out happened during the await. The transition ID is created at installation, too late to exclude that resolution. The FairPlay loader cancels individual delegate requests but has no explicit session-wide teardown operation.

**Prerequisite/impact:** Sign-out must overlap an already accepted refresh/playback request or a delayed Set-Cookie response. Old work could repopulate models, install playback, or restore a local cookie after clearing. UI overlays may limit some overlap paths; fixture reproduction is needed before claiming a viewer-observed failure. Independently, a previously copied valid session cookie is not revoked by local deletion and may remain usable until the provider expires/revokes it. No token theft is implied.

**Mitigation/owner:** Services owns a session generation and cancellation/reset boundary; App owns generation checks around state installation; Playback owns key-task teardown. Match cookie domains exactly or as dot-delimited subdomains rather than substring. Preserve intentional remembered sign-in and public sources. Add provider logout only after confirming a supported contract and failure behavior, not by guessing an endpoint.

**Smallest experiment/acceptance:** Hold synthetic catalog/playback/cookie responses, sign out, release them, and assert no authenticated catalog, player, or session cookie is installed. Relaunch with synthetic persistent/session cookies for both remember-me choices. A cookie for a similarly named unrelated domain must remain untouched. No provider account is required. Server revocation and actual persistence remain separate authorized integration checks.

### SEC-04 — Publisher content can replace the last usable cache before validation

**Rating:** Low-to-Medium availability/integrity risk, proportional to publisher trust. **Confidence:** High in write order and missing app-level bounds; unmeasured resource impact. **Verification:** Source observed, no oversized payload or remote publisher test.

`XMLTVGuideProvider.currentGuideData` and `currentSportsScheduleData` write nonempty HTTP 200 bodies and update ETags before `XMLTVParser.parse`/`SportsScheduleDecoder.decode` validates them. A malformed publication can replace the usable disk fallback, then be reused within the five-minute retry window. Event-detail handling is stronger: `loadSportsEventDetail` decodes and checks identity before writing. HTML/XML/JSON responses are generally buffered through `URLSession.data` without application byte/record/text limits; XMLTV's selected-station/time filtering happens after download. A corrupt or excessively large authenticated publication could disrupt guide availability or consume memory; no numerical limit or measured denial of service is claimed.

No remote publisher source, write API, launchd configuration, installation ownership, or deployment policy is tracked here. Services must identify their exact baselines. Possession of publisher write access is therefore an explicit prerequisite for the malicious-publication case, not a demonstrated weakness in Mac mini permissions. Ordinary publisher mistakes require no attacker.

`XMLTVParser.parse` does not enable external entities or provide an external resolver. Apple documents a false default, so this review does **not** label it confirmed XXE. Making the setting explicit and testing it would protect intent. [Apple XMLParser reference](https://developer.apple.com/documentation/foundation/xmlparser/shouldresolveexternalentities).

**Mitigation/owner:** Services validates full payloads before atomic cache replacement and ETag advancement; uses measured, provider-specific size/count limits; preserves the prior valid publication. Review publisher write scope, source/version provenance, atomic publication, and rollback after repository discovery. Do not introduce new infrastructure or permission changes to address an unverified deployment concern.

**Smallest experiment/acceptance:** Feed valid, malformed nonempty, mismatched-identity, and bounded oversized synthetic responses. After each rejected publication, the previous valid guide/sports snapshot must remain usable, errors must remain separate from playback, and ETags must still refer to the accepted snapshot. Choose resource limits from representative fixtures, not invented production sizes.

### SEC-05 — Release build guard accepts whitespace-only configuration

**Rating:** Low release reliability defect. **Confidence:** High. **Verification:** Reproduced offline with synthetic environment values.

`scripts/validate-media-read-token.sh` counts the untrimmed value and accepts 32 spaces with exit 0. `MediaAPIConfiguration.values` trims whitespace before checking length, so that same value is rejected at runtime. A malformed build setting can pass the archive guard yet ship without usable schedule authorization. This is not an authentication bypass and says nothing about the actual release token.

**Mitigation/owner:** Services proposes one normalization/validation contract; PM/release owner owns project integration. Align whitespace and case-insensitive placeholder rejection between shell and Swift. Even a valid-shaped value cannot prove entropy or backend privilege.

**Smallest experiment/acceptance:** Run the same synthetic matrix against both validators: missing, short, unexpanded, mixed-case placeholder, whitespace-only, padded valid value, and valid fixture. Build/runtime decisions must agree; output must never contain a token value. No credential rotation is necessary to fix the validator.

### Additional low-priority review notes

- **Diagnostics, source-observed:** `AppModel.signIn`, playback resolution catches, and other service catches display `error.localizedDescription`. Current explicit provider errors and AVPlayer diagnostics are restrained, but there is no central sanitizer proving all future URLSession/custom errors are safe for screen capture. Test nested synthetic URL/header/token errors before introducing telemetry. Do not claim current application logs expose secrets based on this gap alone.
- **Developer import tool, conditional:** `scripts/import-channel-logos.sh` reads icon URLs from operator-supplied XML and uses `curl --location` without protocol/redirect, host, size, or time limits. A malicious guide requires an operator to run this tool; it is not in the app build phase. Before future imports, constrain HTTPS/redirects and byte/time budgets and validate images before replacing assets. No command injection was established: URL expansion is quoted. Script was inspected, not executed.
- **Signed URL lifetime, source-observed:** `.request` and `.drmPage` resolve fresh; `.hls` returns its existing catalog URL (`AppModel.makePlaybackSession`). Expiry failures in this last path are a reliability possibility, not evidence that URLs were logged or persisted. Services/Playback should use a failed/expired direct-HLS fixture when designing refresh/retry behavior.

## 4. Three practical improvement proposals

### A. Make sign-out and session recovery predictable

- **Viewer situation/behavior:** A household member signs out or a session expires during a slow tune. Finish outstanding work under the old session without allowing it to restore authenticated state; show a simple sign-in/retry path. Preserve favorites and intended remembered-login behavior.
- **Existing implementation/benefit:** Local cookie deletion, paused playback, selective request IDs, and sanitized playback errors already exist. A consistent session boundary would make those protections complete and reduce confusing return-to-playback behavior.
- **Effort/confidence:** Medium, crossing Services/App/Playback; High confidence in the value of a deterministic contract, Medium confidence in the current race's UI reachability.
- **Dependencies:** PM assigns `AppModel` symbols; Services exposes session cancellation/generation; Playback teardown; QA independently tests. Remote logout is optional pending provider evidence.
- **Smallest experiment:** SEC-03 delayed-response fixture with sign-out during resolution. No UI redesign or real streams.
- **Success criterion:** Late work cannot install a player, authenticated models, or cookies; public playback, saved preferences, retry, and successful remembered sign-in remain functional. Synthetic diagnostic errors reveal no credentials.

### B. Preserve working feeds with explicit provider request contracts

- **Viewer situation/behavior:** Provider markup or an endpoint changes. The app either uses a recognized compatible FairPlay/HLS contract or provides a recoverable unavailable state, with safe internal diagnostics.
- **Existing implementation/benefit:** Provider-specific controller routes, FairPlay regression fixtures, and PBS fixed configuration already exist. Extend them to validate destinations and scoped headers, reducing both credential-routing risk and regressions from overly broad parsing.
- **Effort/confidence:** Medium; High confidence in the observed validation gap. Live compatibility remains dependent on provider behavior.
- **Dependencies:** Services parses/validates descriptors; Playback validates key requests; PM allocates shared `DRMConfiguration` and `Tests/ParserSmoke.swift`; QA owns independent tests; Joe assists with later hardware checks.
- **Smallest experiment:** Pure URL/header-policy fixtures and one offline redirect sink, preserving existing domestic/international/ESPN+/PBS contracts.
- **Success criterion:** All approved fixtures remain compatible; every disallowed destination is blocked before dispatch; sensitive fields never appear in diagnostics. Physical FairPlay confirmation is required before delivery, not inferred from fixture success.

### C. Keep schedule failures from becoming an app-wide incident

- **Viewer situation/behavior:** A publisher sends bad data or a build's read token is revoked. Continue valid provider playback and last usable metadata where appropriate; display a short schedule-unavailable state without technical credential instructions.
- **Existing implementation/benefit:** Separate metadata/playback paths, ETags, disk caches, templates, and a release guard provide most of the foundation. Add validation-before-cache-write, validator parity, and a tested token/publisher contract for easier recovery and smaller incident scope.
- **Effort/confidence:** Small for validator parity; Medium for cache and backend contract checks. High confidence locally; backend effort unknown until Services identifies source/deployment baselines.
- **Dependencies:** Services owns client and backend/publisher source; PM owns release/project integration; QA exercises failure recovery; any production change needs a later scoped authorization.
- **Smallest experiment:** Synthetic malformed-publication cache test plus backend local read/write/revocation matrix. No new accounts, services, or production token changes.
- **Success criterion:** Invalid publications cannot replace accepted cache/ETag state; a read token cannot publish; revoked/missing tokens fail without disabling provider playback; token values never enter reports/logs; validator decisions agree.

## 5. Ownership, documentation discrepancies, and open dependencies

Only this report is assigned for editing. Services owns provider/configuration/cache changes; Playback owns FairPlay and player teardown; App owns UI/state integration; PM must allocate shared models/tests/AppModel symbols and owns project settings. QA owns fresh smoke/build/integrated evidence. Current TestFlight remains with task `01a0370d-dbdd-7ed1-8e23-e8be05509ccb`; this report does not certify or alter its artifact, build number, signing, or upload.

Documentation requiring later reconciliation:

- `docs/TECHNICAL_HANDOFF.md` security/configuration sections describe server read-only scope and revocation as established. This app repository establishes the client contract only. Services must provide backend evidence before that becomes current verification.
- Its configuration section says `Config/Shared.xcconfig` optionally includes the private file. At this baseline, `Debug.xcconfig` includes `Private.xcconfig` and `Release.xcconfig` includes `Internal.xcconfig`; this separation matters when preparing internal distribution.
- Its player-error prose says the viewer receives domain/code diagnostics; `PlaybackSession.handlePlayerStatus` now presents a generic message and logs domain/code only in Debug.
- `README.md` says Joe-TV never contacts ESPN. `ESPNScoreboardClient.loadNFLScoreboard` is the accepted direct Fantasy Zone exception; ordinary metadata still follows the publisher path.
- Historical physical FairPlay success and provider lockout in `docs/product-context.md`/`docs/TECHNICAL_HANDOFF.md` are historical reports, not fresh evidence for this baseline. Keep the single-stream coordination requirement.

Outstanding evidence: backend route/method authorization and revocation implementation; publisher read/write identity separation and install ownership; release artifact distribution scope and secret handling; actual provider cookie attributes/expiry/logout contract; sign-out race reproduction; provider destination/redirect compatibility; physical FairPlay results. Absence of these facts is not proof of unsafe configuration. No live probes or permission changes should be inferred from these questions.

## 6. Checks performed and remaining validation

| Check | Actual result and limitation |
| --- | --- |
| Git preflight and baseline | Clean initial worktree; branch absent before creation; assigned branch created at `314968dc10f0bd73451ed6b0876a7fc7ed5c5233`. Git needed normal shared-worktree metadata access; no files in the user's checkout or PM worktree were edited. |
| Tracked inventory and private-config ignore rules | Tracked Config files are public templates/shared build files. `git check-ignore` confirmed both private config paths are ignored without reading them. No publisher/deployment source, dependency lockfile, or entitlements file appeared in the scoped tracked inventory. This is not a whole-history secret scan. |
| Source data-flow/log review | Traced login/cookie, bearer, URL parsing, FairPlay, cache, state teardown, and build flows. Swift log search found the two Debug-only domain/code print sites described above. No runtime logs were collected. |
| Release validation script | Invoked existing script in isolated subprocess environments, using synthetic values only. Debug missing: exit 0. Release missing, short, uppercase placeholder, and unexpanded value: exit 1. Release synthetic valid-length value: exit 0. Release 32 spaces: exit 0 (SEC-05). All seven outcomes matched the recorded observations; checked that nonempty fixture values were not echoed. No private file or release build was involved. |
| Existing parser fixtures | Inspected metadata request tests and domestic/international/ESPN+/PBS FairPlay fixtures. They cover useful positive contracts, not an end-to-end auth/redirect/sign-out adversarial matrix. Did not execute or extend them. |
| Official documentation | Checked Apple documentation for default cookie-store behavior, ATS, and XML external-entity default. These references narrow claims; they do not prove runtime behavior in the actual app artifact. |
| Report verification | `git diff --check` and `git diff --cached --check` passed. Staged path/stat inspection showed only `docs/assessments/secops.md`; no application or other documentation changes. |

Full `scripts/team-check.sh smoke` and unsigned simulator build were not run by SecOps; QA owns fresh M0 baseline evidence. No simulator/device/live-service claim is made. No new test files or generated artifacts were written. Future fixture experiments above are proposals, not completed verification. The completed deliverable is this assessment and its bounded report-only commit.
