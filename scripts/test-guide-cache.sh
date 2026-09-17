#!/bin/sh
# Offline provider lifecycle tests; all requests intercepted, isolated temporary stores.
set -eu
cache_test_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$cache_test_repo_dir"
mkdir -p .build/ModuleCache
xcrun swiftc -parse-as-library -swift-version 5 \
  -module-cache-path .build/ModuleCache \
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
  Tests/GuideCacheSmoke.swift -o .build/guide-cache-smoke
.build/guide-cache-smoke
