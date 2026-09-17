# XMLTV parser performance investigation

Measured September 16, 2026 EDT. Application source: S1 candidate `f394d4d356851092ae579051cff5a5a667d53cdb`; XMLTV provider unchanged from the established baseline. This is a host-only microbenchmark, not simulator input latency, network startup, or a production viewing measurement.

`scripts/benchmark-guide-parser.sh` compiles the repository parser with Swift 5 mode and `-O`, then parses a deterministic 588,650-byte guide containing 70 stations and 3,360 half-hour programs. An 18-hour selection returns exactly 2,520 programs. Fixture generation is outside timing. One warm-up precedes five measured complete parses using ContinuousClock. Input dates, titles and station IDs are synthetic; no endpoints or credentials are used. The helper is outside the application target.

Host: arm64 MacBook Air, macOS 26.6.2, Xcode 26.6 / Swift 6.3.3. QA's compilation finished before the run; fixture UI testing and agent work continued, so host load is not laboratory-controlled. Compare repeated distributions and equivalent output; no universal speed budget follows from these samples.

| Variant | Five samples (milliseconds) | Median | Interpretation |
| --- | --- | --- | --- |
| Existing repository parser | 1754.85, 1888.82, 2089.08, 2309.03, 2056.67 | 2056.67 ms | The whole XML-to-program parse is a measurable target on this data. |
| Temporary per-document formatter reuse only | 1876.02, 1614.51, 2245.12, 4907.27, 1849.66 | 1876.02 ms | Overlapping distributions and a large outlier; no convincing gain established, so this alone is not selected for production. |

A second temporary experiment memoizes identical raw timestamps within one document; result is pending. Experimental source/executables/logs live only under the PM worktree's ignored `.build/`. No application source was changed for these experiments. Services must independently implement and test any selected optimization in its owned source, and final measurements must name the integrated source. Timestamp formats, offsets, boundaries, malformed input, and concurrent parse independence require correctness coverage; count equality alone is insufficient.

Competitor parser internals are unavailable and do not establish a performance standard. This follows the evidence-first approach in `evaluation-method.md`: measure a specific cost, preserve behavior, then compare the exact result. The benchmark cannot quantify remote-control responsiveness or Apple TV hardware performance.
