#!/bin/sh
set -eu
caption_policy_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$caption_policy_repo_dir"
mkdir -p .build/CaptionPolicyModuleCache
xcrun swiftc -parse-as-library -swift-version 5 \
  -module-cache-path .build/CaptionPolicyModuleCache \
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
  Tests/PlaybackCaptionPolicySmoke.swift \
  -o .build/caption-policy-smoke
.build/caption-policy-smoke
