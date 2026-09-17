# S2-DESIGN — Channels sheet polish

## Scope and evidence

This is a Channels-only visual contract for App. Source was reviewed at `a30b22893f736b72186739f1dd834de680c96fbf`; the QA capture is the 1920×1080 S1 candidate fixture at `f394d4d` with a disabled saved favorite. The capture visibly shows an oversized three-line description, clipped two-line playback copy inside a fixed 64-point row, early channel-name truncation, and “Clear Favorites” broken across three fragments. The filled saved star also uses `focusVolt`, which the existing design treats as focus feedback.

Preserve every action, the separate enabled/favorite preferences, immediate settings behavior, initial focus behavior, accessibility identifiers, and S1 Home return rules. This brief adds no screen, route, confirmation, token, or global settings redesign. R1 supports couch readability and keeping saved state distinct from availability; its competitor evidence does not supply Joe-TV dimensions or prove usability.

## Local layout and type contract

Use explicit local sizes so tvOS semantic styles do not expand this sheet unpredictably.

| Element | Acceptance |
| --- | --- |
| Sheet | `1100 × 840`, 44-point outer padding, 18-point major vertical spacing. Keep the footer outside the scrolling channel list. Allow at least 10 points around scaled focus shapes so outlines are not clipped. |
| Header | “Channels” at 40 points, semibold. Replace the description with **Choose channels for Live TV and favorites for Home.** at 20 points, regular, secondary, maximum two lines and about 650 points wide. Done remains top-right with at least `140 × 64` points. |
| Section labels | 15 points, semibold, uppercase, existing tracking and secondary color. Keep PLAYBACK and provider names as structural labels rather than competing headings. |
| Playback row | Minimum height 96, 20-point horizontal and 14-point vertical padding. Title **Change channels with Up/Down** at 22 points, semibold, one line. Supporting text **When off, directional gestures show playback controls.** at 17 points, regular, secondary, maximum two lines. Neither line may clip at rest or in focus. |
| Channel row | Minimum height 88. Artwork `80 × 48`; channel name 22 points, semibold, maximum two lines. Give the main channel control all flexible width before the favorite control. Long fixture names may truncate only after two lines and must not collide with the state indicator. |
| Favorite control | Fixed minimum width 170 and the same 88-point row height. Use a horizontal star-plus-label treatment: **Favorited** with `star.fill`, **Favorite** with `star`. Keep both state words to avoid color-only meaning. |
| Footer | One unwrapped row: 18-point secondary summary on the left; actions on the right with 16-point gaps. Minimum widths: Clear Favorites 190, Restore Defaults 210, Enable All 150; 18-point semibold labels, one line, minimum height 64. If localization exceeds these widths, grow the button or sheet rather than splitting a word. |

The existing `SportsSettingsRowButtonStyle` has a fixed 64-point height and cannot contain the required playback/channel layouts. Add a Channels-local row style or a local height parameter; do not alter that shared style for unrelated settings. The sheet may scroll more content after rows grow. Header and footer remain stable while the channel list scrolls.

## State and focus acceptance

The main channel control continues to toggle Live TV availability. Its trailing state must pair the existing circle/check symbol with visible **Disabled** or **Enabled** text at 17 points. The adjacent favorite control continues to toggle the saved favorite independently. A favorite may truthfully read Favorited while its channel reads Disabled; opening this sheet must not enable it.

Use `SeasonTheme.accent` or the normal foreground for the unfocused filled star, not `focusVolt`. In focus, the row style’s white/black treatment remains the dominant focus signal. Filled versus outline symbol, state text, and accessibility value must all agree, so color is redundant rather than essential.

Focus must remain visibly bounded on Done, playback, every channel and favorite control, and all three footer actions. Increasing the sheet and rows must not change focus order, activate a neighboring control, or hide the focused row beneath the fixed footer. Disabled footer actions remain legible as disabled and are skipped/handled according to existing tvOS behavior. Done/Back retains S1’s predictable return to Choose Favorites or the first visible Home favorite; this polish must not change that bookmark logic.

## QA captures and limits

QA should capture the complete sheet at 1920×1080 with: the first row focused; a long channel name; enabled plus non-favorite; disabled plus saved favorite; playback row focused; and each footer edge action focused. Confirm no clipping, word fragmentation, overlap, focus-outline cropping, or state conveyed only by color. Traverse the full list and return to Home with no change, a newly visible favorite, and a saved-but-disabled favorite. Check VoiceOver names/values and Reduce Motion, but keep fixes local to this sheet.

Design did not build or operate a simulator. This review is based on one QA fixture capture and exact source inspection; it does not establish physical-TV couch legibility, localization fit, VoiceOver order, dynamic type behavior, or device focus performance. QA owns those observations on the integrated candidate. No new competitor research was performed.
