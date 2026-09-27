#!/bin/sh
set -eu
playback_failure_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$playback_failure_repo_dir"
mkdir -p .build/PlaybackFailureModuleCache
xcrun swiftc -parse-as-library -swift-version 5 \
  -module-cache-path .build/PlaybackFailureModuleCache \
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
  Tests/PlaybackFailureSmoke.swift \
  -o .build/playback-failure-smoke
.build/playback-failure-smoke
