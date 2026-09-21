# S6 App handoff — guide sizing

- Assignment: S6 App guide sizing under `docs/assignments/S6-guide-captions.md`.
- Governing baseline/spec: base Joe-TV `46256bc`, TEAM-8 repository instructions.
- Branch: `codex/joe-tv-app-s6`.
- Scope: `JoeTVGuideView`, `JoeTVGuideGrid`, adjacent guide sizing/preference types, and the focused sizing fixture only.

## Result

Settings now exposes persistent Standard and Compact guide-size choices alongside the existing playback and channel controls. The Live TV filter bar remains focused on guide filtering. Compact preserves the released 250-point channel column, 66-point rows, 38-point ruler, 555-point viewport, timeline scale, logo sizes, single-line labels, and all existing type sizes.

Standard keeps the same three-hour timeline scale and visual styling while using a 330-point channel column, 94-point rows, a 44-point ruler, a 600-point viewport, 24-point channel and program text, 20-point ruler text, 18-point program times, and two-line channel and program titles. The viewport presents about 5.9 rows, so five rows are complete and the sixth remains visible, matching Joe's couch-readable photo reference without adopting its skin or sidebar. These values incorporate PM's first native acceptance pass, which found the initial Large typography still too small.

The Settings choices update metrics in the existing grid position, preserving the current focus binding, filter behavior, scroll reader, preview, program selection, and playback routes. The normal preference key is `com.jrcoak.joetv.guideSize`; its legacy raw mapping is preserved (`large` means Standard, `standard` means Compact), and missing/invalid values default to Standard. Debug navigation runs with `JOE_TV_DEBUG_NAVIGATION=1` use the isolated `com.jrcoak.joetv.fixture.guide` defaults suite so native QA does not change the normal app preference.

Joe's supplied guide photo is the direct comparison for this change; separate competitor parity does not apply because the requested outcome is a user-selected density variant of the accepted Joe-TV guide.

## Verification

- `scripts/test-guide-sizing.sh`: passed 9 checks covering exact Compact preservation, native-accepted Standard geometry/type values, Standard row density, larger text, two-line labels, and unchanged timeline scale.
- `xcrun swiftc -frontend -parse SeasonsTV/Views/JoeTVExperience.swift`: passed.
- `git diff --check`: passed.

No simulator, provider, device, player, model, project, signing, build-number, release, or Plex-fork work was performed. PM owns the combined build and native fixture verification. Native acceptance remains required for visible row density, focus continuity after changing size, two-line truncation, ruler/row/now-line alignment, and preference restoration.
