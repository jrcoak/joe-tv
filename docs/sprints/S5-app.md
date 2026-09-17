# S5-APP — Sports filter sheet repair

Baseline: `7fe97fcddd32630f27de2e74ea2f70e53bb017d5`; assignment S5 / TEAM-4, with PM-relayed Design guidance. Clean branch `codex/joe-tv-app-s5` created in the existing App worktree after status/absence checks; prior branches preserved. Exact final commit is supplied in the handoff.

Inspected Joe's September 17 11:55:11 AM screenshot. It visibly shows oversized helper/category/count text, a three-line College Football / NCAAF title, unequal tile heights and crowded footer. This repairs observed clipping; no competitor research or redesign is needed.

Only `JoeTVSportsFilterView`, new private `JoeTVSportsFilterButtonStyle` in `JoeTVExperience.swift`, and this report change. The sheet retains 1060 × 790 dimensions, 50-point outer padding, two columns and all 26 categories in their existing order. Header uses 42/20-point type and concise copy. Done/Select All use explicit 20-point labels, 64-point height and minimum widths 140/180. Footer uses 17-point concise text outside the scrolling grid.

Tiles are uniformly 112 points high with 20/14 horizontal/vertical padding, 16-point grid gaps, 24-point medium category titles in a reserved 58-point two-line block, 17-point counts, 24-point category symbols in 34-point slots and 24-point state symbols in 28-point slots. No per-name size reduction or abbreviation was added. Counts are computed once per body evaluation, and the singular is **1 event**. At the proposed width, the title column receives approximately 334 points; long names such as NCAA Women’s Ice Hockey and Women’s College Basketball have two lines available. Actual rendered fit remains a QA check.

The new filter-only style follows S2's white/black focus contrast, with a bounded outline and subtle glow. Twelve-point scroll insets and 16-point grid gaps leave room for focus decoration. Reduce Motion removes focus scaling/animation. Filled check versus outline circle remains distinct in either focus state; accessibility retains Included/Excluded and now explicitly names the category and correctly pluralized count. Existing filter toggles, immediate persistence, counts' Live/Upcoming policy, Select All, Done/dismiss behavior and surrounding navigation/focus IDs are unchanged. Shared button styles and all S1/S2/S4 code outside this sheet remain untouched.

Verification: Debug and non-Debug syntax-only parsing of `JoeTVExperience.swift` passed (`xcrun swiftc -frontend -parse` with/without `-D DEBUG`); whitespace checks passed. A byte comparison confirms all source before the filter view and after its new local style is unchanged. No source-mirroring test, typecheck/full build, simulator, runtime, network or private-config operation was run. Joe owns the simulator; QA builds the integrated configured candidate next.

QA should inspect all 26 tiles, especially College Football / NCAAF, NCAA Women’s Ice Hockey and Women’s College Basketball; verify equal heights, complete two-line names, 0/1/multiple event grammar, included/excluded states in and out of focus, Done/Select All, first/last-row focus outlines and scroll clearance above the fixed footer. Exercise toggle/persistence/dismiss and Reduce Motion. Source sizing and syntax checks are not visual or accessibility-runtime acceptance.

Final/Git handoff is the established path; no rejected callbacks were retried.
