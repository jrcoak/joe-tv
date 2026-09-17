"""Synthetic preflight and log-redaction checks; no real config, build or network."""
import importlib.util
from pathlib import Path
import plistlib
import tempfile
import sys
sys.dont_write_bytecode = True
import unittest

spec = importlib.util.spec_from_file_location('configured_build', Path(__file__).resolve().parents[1] / 'scripts/build-configured-simulator.py')
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
TOKEN = 'synthetic-only-test-value-' + 'a' * 40


class ConfiguredBuildTests(unittest.TestCase):
    def test_missing_placeholder_and_ambiguous_tokens_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / 'Private.xcconfig'
            for content in ['', 'MEDIA_READ_TOKEN =\n', 'MEDIA_READ_TOKEN = PLACEHOLDER_' + 'a' * 40,
                            'MEDIA_READ_TOKEN = $(OTHER_SECRET)',
                            'MEDIA_READ_TOKEN = ' + TOKEN + '\nMEDIA_READ_TOKEN = ' + TOKEN]:
                config.write_text(content)
                with self.assertRaises(ValueError):
                    helper.read_token(config)
            config.write_text('// Debug only\nMEDIA_READ_TOKEN = ' + TOKEN + '\n')
            self.assertEqual(helper.read_token(config), TOKEN)

    def test_redaction_preserves_diagnostics_without_tokens(self):
        for line in ['export MEDIA_READ_TOKEN=' + TOKEN, 'MediaReadToken = expanded-secret-not-known',
                     'unrelated message ' + TOKEN + ' tail']:
            result = helper.redact(line, TOKEN)
            self.assertNotIn(TOKEN, result)
            self.assertNotIn('expanded-secret-not-known', result)
        self.assertEqual(helper.redact('warning: missing symbol\n', TOKEN), 'warning: missing symbol\n')
        escaped = TOKEN + '+/='
        import html
        from urllib.parse import quote
        for variant in [escaped, html.escape(escaped), quote(escaped, safe=''),
                        ''.join(c if c.isalnum() or c in '_./-' else '\\' + c for c in escaped)]:
            self.assertNotIn(variant, helper.redact('output ' + variant, escaped))

    def test_bundle_must_match_selected_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory)
            info = {'MediaReadToken': TOKEN, 'MediaAPIBaseURL': 'https://metadata.invalid',
                    'CFBundleIdentifier': 'synthetic.test', 'CFBundleVersion': '7'}
            with (app / 'Info.plist').open('wb') as stream:
                plistlib.dump(info, stream)
            result = helper.validate_bundle(app, TOKEN)
            self.assertTrue(result['metadata_configuration_present'])
            self.assertNotIn(TOKEN, str(result))
            with self.assertRaises(ValueError):
                helper.validate_bundle(app, TOKEN + 'wrong')
            for invalid_url in ['$(MEDIA_API_BASE_URL)', '', 'http://metadata.invalid']:
                info['MediaAPIBaseURL'] = invalid_url
                with (app / 'Info.plist').open('wb') as stream:
                    plistlib.dump(info, stream)
                with self.assertRaises(ValueError):
                    helper.validate_bundle(app, TOKEN)


if __name__ == '__main__':
    unittest.main()
