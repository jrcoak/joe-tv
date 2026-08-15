#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: sh scripts/import-channel-logos.sh /path/to/xmltv.xml" >&2
    exit 64
fi

guide_path=$1
repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
directory_source="$repository_root/SeasonsTV/Models/ChannelDirectory.swift"
asset_catalog="$repository_root/SeasonsTV/Resources/Assets.xcassets"
contents_template="$repository_root/scripts/channel-logo-Contents.json"

if [ ! -f "$guide_path" ]; then
    echo "Guide not found: $guide_path" >&2
    exit 66
fi

station_ids=$(sed -nE 's/.*stationID: "([0-9]+)".*/\1/p' "$directory_source" | sort -u)

for station_id in $station_ids; do
    icon_url=$(xmllint --xpath "string(//channel[@id='$station_id']/icon/@src)" "$guide_path" 2>/dev/null)
    if [ -z "$icon_url" ]; then
        echo "Missing XMLTV icon for station $station_id" >&2
        exit 65
    fi

    high_resolution_url=$(printf '%s' "$icon_url" | sed -E 's/([?&])w=[0-9]+/\1w=512/')
    image_set="$asset_catalog/ChannelLogo_$station_id.imageset"
    image_path="$image_set/logo.png"

    mkdir -p "$image_set"
    curl --fail --location --retry 2 "$high_resolution_url" --output "$image_path"
    cp "$contents_template" "$image_set/Contents.json"

    width=$(sips -g pixelWidth "$image_path" 2>/dev/null | awk '/pixelWidth/ { print $2 }')
    if [ -z "$width" ] || [ "$width" -lt 400 ]; then
        echo "Logo for station $station_id is unexpectedly small ($width px)" >&2
        exit 65
    fi

    echo "Imported ChannelLogo_$station_id ($width px)"
done
