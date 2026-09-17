#!/bin/sh
# Pure guide merge policy tests; no providers, sessions or app state instantiated.
set -eu
merge_test_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$merge_test_repo_dir"
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
  Tests/GuideMergeSmoke.swift -o .build/guide-merge-smoke
.build/guide-merge-smoke
