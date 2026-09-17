# S1 Playback Handoff

## Assignment

- Role: Playback specialist (`TEAM-4`, `S1-PLAYBACK`)
- Task: `01a0ad34-ab28-7012-94c5-ed6e82ea8f8e`
- Branch: `codex/joe-tv-playback-s1`
- Required baseline: `22f0fdf51b9b105bfb5b34cf5ecc2bb6e72a1340`
- Owned paths: `SeasonsTV/Views/PlayerScreen.swift` and this report

## Change

The focused Fantasy scorebug did not install the exit handlers used by the other player controls. A Back/Menu press could therefore bypass `handleBack()`, leaving the controls visible or escaping the intended one-layer route.

The scorebug now handles both the tvOS exit command and keyboard Escape through `handleBack()`. The same focused-button gap was present on the Quick Switch error banner's Dismiss action and the playback failure view's Return to Browse action, so those two closely related failure targets now use the same route. When a playback error appears, hidden chrome state is normalized before focus moves to Return to Browse; this ensures Back dismisses the visible failure layer rather than first consuming an invisible controls or Quick Switch layer.

All routes still pass through `PlayerChromeModel.acquireBack()`, preserving the 450 ms repeated-input guard. The existing layer behavior remains:

- Quick Switch Back returns to controls.
- Controls Back hides controls.
- Fantasy drawer Back closes the drawer and restores scorebug focus.
- Hidden-player Back uses delayed playback dismissal to prevent event fallthrough.

The native captions confirmation dialog, drawer-local exit command, Hold Select/Last Stream gesture, play/pause gesture, media lifecycle, and DRM paths were not changed.

## Source verification

- Confirmed the branch began clean at the required baseline.
- Reviewed every `Button` in `PlayerSessionView` and the Fantasy drawer's container-level exit handler.
- Kept the implementation to the existing `handleBack()` contract; no new routing mechanism was introduced.
- Ran `git diff --check` and reviewed the complete owned-path diff.
- Simulator, build, and authenticated-stream checks were intentionally left to QA under the S1 ownership boundary.

## QA simulator checks remaining

Run these on QA's integrated S1 commit and designated tvOS simulator:

1. In the Fantasy Zone fixture, show controls, focus the full-width scorebug, and press Back once. Controls should hide while video remains. After the debounce interval, a second Back should dismiss playback without reaching the browse screen or system twice.
2. Open the Fantasy drawer from the scorebug. Back should close the drawer and restore scorebug focus; the next spaced Back should hide controls; the next should dismiss playback. Rapid repeated Back presses must not skip layers or fall through.
3. Force a Quick Switch failure, focus Dismiss, and press Back. The view should return to controls through the one-layer route. Verify rapid repeated Back is debounced.
4. Show a playback failure while controls or Quick Switch is open. With Return to Browse focused, Back should dismiss playback through the delayed hidden-layer path. Verify one press, rapid repeats, and spaced repeats.
5. Recheck Play/Pause, Favorite, Matchup/Guide, Captions, Quick Switch cards, and the Quick Switch trigger. Back should retain their existing one-layer behavior.
6. Open the native captions dialog and dismiss it with Back. Focus should return to the player control without a parent-level double action.
7. Recheck Hold Select/Last Stream and Select/Play-Pause gestures for regressions.
8. Repeat the Back sequence on a physical Siri Remote when device coverage is available.
