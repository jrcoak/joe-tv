#!/bin/sh
set -eu
guide_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$guide_repo_dir"
guide_build_dir=$(mktemp -d "${TMPDIR:-/tmp}/joetv-guide-sizing.XXXXXX")
trap 'rm -rf "$guide_build_dir"' EXIT
{
  echo 'import Foundation'
  sed -n '/BEGIN GUIDE SIZING POLICY/,/END GUIDE SIZING POLICY/p' \
    SeasonsTV/Views/JoeTVExperience.swift
} > "$guide_build_dir/JoeTVGuideSizing.swift"
xcrun swiftc -parse-as-library -swift-version 5 \
  -module-cache-path "$guide_build_dir/module-cache" \
  "$guide_build_dir/JoeTVGuideSizing.swift" \
  Tests/JoeTVGuideSizingSmoke.swift \
  -o "$guide_build_dir/joe-tv-guide-sizing"
"$guide_build_dir/joe-tv-guide-sizing"
