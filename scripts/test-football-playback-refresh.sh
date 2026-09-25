#!/bin/sh
set -eu
football_refresh_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$football_refresh_repo_dir"
mkdir -p .build/FootballPlaybackRefreshModuleCache
xcrun swiftc -parse-as-library -swift-version 5 \
  -module-cache-path .build/FootballPlaybackRefreshModuleCache \
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
  Tests/FootballPlaybackRefreshSmoke.swift \
  -o .build/football-playback-refresh-smoke
.build/football-playback-refresh-smoke
