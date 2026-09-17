#!/bin/sh
# Existing offline suite and unsigned Debug build, with per-worktree caches.
set -eu
team_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$team_repo_dir"

case "${1:-}" in
  smoke)
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
      Tests/ParserSmoke.swift -o .build/parser-smoke
    .build/parser-smoke
    ;;
  build)
    xcodebuild -project Joe-TV.xcodeproj -scheme Joe-TV \
      -configuration Debug -sdk appletvsimulator \
      -destination 'generic/platform=tvOS Simulator' \
      -derivedDataPath .build/TeamDerivedData \
      CODE_SIGNING_ALLOWED=NO build
    ;;
  *)
    echo 'Usage: scripts/team-check.sh smoke|build' >&2
    exit 2
    ;;
esac
