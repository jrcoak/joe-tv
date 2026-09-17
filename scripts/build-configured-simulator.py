#!/usr/bin/env python3
"""Build a normal browsing simulator app using an explicit private Debug config."""
import argparse
import html
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
from urllib.parse import quote


def read_token(config):
    # Only consume the explicit existing Debug file; never copy or print it.
    matches = re.findall(r'^\s*MEDIA_READ_TOKEN\s*=\s*([^\r\n]*)', config.read_text(), re.MULTILINE)
    if len(matches) != 1:
        raise ValueError('Debug config must contain one explicit MEDIA_READ_TOKEN assignment.')
    token = matches[0].strip()
    if len(token) >= 2 and token[0] == token[-1] and token[0] in "\"'":
        token = token[1:-1]
    if len(token) < 32 or '$(' in token or 'placeholder' in token.lower() or any(c.isspace() for c in token):
        raise ValueError('Debug config has no usable explicit read token.')
    return token


def redact(line, token):
    if re.search(r'MEDIA_READ_TOKEN|MediaReadToken', line, re.IGNORECASE):
        return '[redacted token-related build output]\n'
    variants = {token, html.escape(token, quote=True), quote(token, safe=''), json.dumps(token)[1:-1]}
    # Xcode may escape punctuation when writing shell environment values.
    variants.add(''.join(c if c.isalnum() or c in '_./-' else '\\' + c for c in token))
    for value in sorted(variants, key=len, reverse=True):
        line = line.replace(value, '[REDACTED]')
    return line


def validate_bundle(app, expected_token):
    with (app / 'Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    actual = info.get('MediaReadToken')
    base = info.get('MediaAPIBaseURL')
    if not isinstance(actual, str) or actual.strip() != expected_token:
        raise ValueError('Built app does not contain the selected Debug configuration.')
    if not isinstance(base, str) or not base.startswith('https://') or '$(' in base:
        raise ValueError('Built app has no usable HTTPS metadata API base URL.')
    return {'bundle_id': info.get('CFBundleIdentifier'),
            'version': info.get('CFBundleShortVersionString'),
            'build': info.get('CFBundleVersion'), 'metadata_configuration_present': True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True, type=Path, help='Existing private Debug xcconfig; never a Release/Internal token')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    config = args.config.resolve()
    if config.name != 'Private.xcconfig':
        parser.error('Select the existing Private.xcconfig for Debug, not Internal/Release configuration.')
    try:
        token = read_token(config)
    except (OSError, ValueError):
        print('Configuration preflight failed: supply the existing valid private Debug config.', file=sys.stderr)
        return 2
    build = root / '.build' / 'ConfiguredDerivedData'
    log = root / '.build' / 'configured-simulator-build.log'
    log.parent.mkdir(parents=True, exist_ok=True)
    command = ['xcodebuild', '-quiet', '-project', 'Joe-TV.xcodeproj', '-scheme', 'Joe-TV',
               '-configuration', 'Debug', '-sdk', 'appletvsimulator', '-destination',
               'generic/platform=tvOS Simulator', '-derivedDataPath', str(build),
               '-xcconfig', str(config), 'CODE_SIGNING_ALLOWED=NO', 'build']
    env = os.environ.copy()
    env.pop('MEDIA_READ_TOKEN', None)
    with log.open('w') as output:
        with subprocess.Popen(command, cwd=root, env=env, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True, errors='replace') as process:
            for line in process.stdout:
                output.write(redact(line, token))
                output.flush()
            result = process.wait()
    if result:
        print(f'Configured simulator build failed (exit {result}); inspect redacted log: {log}', file=sys.stderr)
        return result
    app = build / 'Build' / 'Products' / 'Debug-appletvsimulator' / 'Joe-TV.app'
    try:
        metadata = validate_bundle(app, token)
    except (OSError, ValueError, plistlib.InvalidFileException):
        print('Configured build failed bundle preflight; do not install this artifact.', file=sys.stderr)
        return 2
    print(json.dumps({'result': 'PASS', 'app': str(app), 'log': str(log), **metadata}))
    return 0


if __name__ == '__main__':
    sys.exit(main())
