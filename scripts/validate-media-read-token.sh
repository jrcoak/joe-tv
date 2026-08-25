#!/bin/sh

set -eu

if [ "${CONFIGURATION:-}" != "Release" ]; then
    exit 0
fi

token="${MEDIA_READ_TOKEN:-}"

if [ -z "$token" ]; then
    echo "error: MEDIA_READ_TOKEN is required for Release builds. Supply Config/Private.xcconfig or a CI build setting." >&2
    exit 1
fi

case "$token" in
    *'$('*|*PLACEHOLDER*|*placeholder*)
        echo "error: MEDIA_READ_TOKEN is still a placeholder. Inject the private read-only token before archiving." >&2
        exit 1
        ;;
esac

if [ "${#token}" -lt 32 ]; then
    echo "error: MEDIA_READ_TOKEN must contain at least 32 characters." >&2
    exit 1
fi
