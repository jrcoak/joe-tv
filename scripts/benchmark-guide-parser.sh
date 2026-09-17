#!/bin/sh
# Host XMLTV parser microbenchmark; excludes fixture generation, network and UI.
set -eu
benchmark_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$benchmark_repo_dir"
mkdir -p .build/ModuleCache
xcrun swiftc -parse-as-library -swift-version 5 -O \
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
  scripts/benchmarks/GuideParserBenchmark.swift -o .build/guide-parser-benchmark
.build/guide-parser-benchmark
