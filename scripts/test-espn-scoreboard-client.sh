#!/bin/sh
# Offline ESPN scoreboard request/cache tests. URLProtocol intercepts every request.
set -eu
scoreboard_test_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$scoreboard_test_repo_dir"
mkdir -p .build/ESPNScoreboardClientModuleCache
xcrun swiftc -parse-as-library -swift-version 5 \
  -module-cache-path .build/ESPNScoreboardClientModuleCache \
  SeasonsTV/Models/Models.swift \
  SeasonsTV/Models/ChannelDirectory.swift \
  SeasonsTV/Networking/MediaAPIConfiguration.swift \
  SeasonsTV/Networking/HTMLCatalogParser.swift \
  SeasonsTV/Networking/SeasonsClient.swift \
  SeasonsTV/Networking/SleeperClient.swift \
  SeasonsTV/Networking/ESPNScoreboardClient.swift \
  SeasonsTV/Networking/XMLTVGuideProvider.swift \
  SeasonsTV/Networking/VeryLocalClient.swift \
  SeasonsTV/Networking/PBSLiveClient.swift \
  SeasonsTV/Playback/FairPlayResourceLoader.swift \
  Tests/ESPNScoreboardClientSmoke.swift -o .build/espn-scoreboard-client-smoke
.build/espn-scoreboard-client-smoke
