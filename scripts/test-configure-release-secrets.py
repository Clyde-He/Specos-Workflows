#!/usr/bin/env python3
"""Exercise credential setup with synthetic files and a local gh stub."""
import base64
import io
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = Path(os.environ.get('CONFIGURE_RELEASE_SCRIPT',
    ROOT / 'templates/macos-app/scripts/configure-release-secrets.sh'))


class ConfigureReleaseSecretsTests(unittest.TestCase):
    def check_setup(self, encode, certificate_name='Developer ID.p12'):
        with tempfile.TemporaryDirectory(prefix='release credentials ') as temporary:
            root = Path(temporary)
            captured = root / 'captured'
            captured.mkdir()
            gh = root / 'gh'
            gh.write_text(f'#!{sys.executable}\n' + '''import os
from pathlib import Path
import sys
args = sys.argv[1:]
target = Path(os.environ['CAPTURED_SECRETS'])
if args[:2] == ['auth', 'status']:
    pass
elif args[:2] == ['secret', 'set']:
    (target / args[2]).write_bytes(sys.stdin.buffer.read())
elif args[:2] == ['variable', 'set']:
    (target / args[2]).write_text(args[args.index('--body') + 1])
else:
    raise SystemExit('Unexpected gh invocation')
''')
            gh.chmod(0o755)
            certificate = root / certificate_name
            key = root / "AuthKey Clyde's.p8"
            development = root / 'Apple Development.p12'
            profile = root / 'Developer ID App.provisionprofile'
            for file, value in [(certificate, b'fake certificate'), (key, b'fake private key'),
                                (development, b'fake development certificate'), (profile, b'fake profile')]:
                file.write_bytes(value)
            password = "literal 'password' \\ $(touch PASSWORD_EXECUTED)"
            inputs = [encode(str(certificate)), password, encode(str(key)), 'KEY-ID', 'ISSUER-ID', 'TEAM-ID',
                      encode(str(development)), password, encode(str(profile)), '', 'fake package token']
            environment = dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH'],
                               CAPTURED_SECRETS=str(captured))
            result = subprocess.run(['bash', str(SCRIPT), 'owner/example',
                '--with-apple-development-certificate', '--with-developer-id-profiles',
                '--with-swift-package-token'], input='\n'.join(inputs) + '\n', text=True,
                capture_output=True, env=environment, cwd=root)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(base64.b64decode((captured / 'DEVELOPER_ID_CERTIFICATE_BASE64').read_bytes()), certificate.read_bytes())
            self.assertEqual((captured / 'APP_STORE_CONNECT_PRIVATE_KEY').read_bytes(), key.read_bytes())
            self.assertEqual(base64.b64decode((captured / 'APPLE_DEVELOPMENT_CERTIFICATE_BASE64').read_bytes()), development.read_bytes())
            for name in ['DEVELOPER_ID_CERTIFICATE_PASSWORD', 'APPLE_DEVELOPMENT_CERTIFICATE_PASSWORD']:
                self.assertEqual((captured / name).read_text(), password)
            self.assertEqual((captured / 'APPLE_TEAM_ID').read_text(), 'TEAM-ID')
            self.assertEqual((captured / 'SWIFT_PACKAGE_TOKEN').read_text(), 'fake package token')
            bundle = base64.b64decode((captured / 'DEVELOPER_ID_PROVISIONING_PROFILES_BASE64').read_bytes())
            with tarfile.open(fileobj=io.BytesIO(bundle), mode='r:gz') as archive:
                self.assertEqual(archive.extractfile(profile.name).read(), profile.read_bytes())
            self.assertFalse((root / 'UNEXPECTED_EXECUTION').exists())
            self.assertFalse((root / 'PASSWORD_EXECUTED').exists())
            self.assertNotIn(password, result.stdout + result.stderr)

    def test_literal_paths_with_spaces_and_apostrophes(self):
        self.check_setup(lambda value: value)

    def test_single_quoted_dragged_paths(self):
        self.check_setup(shlex.quote)

    def test_double_quoted_dragged_paths(self):
        self.check_setup(lambda value: '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"')

    def test_backslash_escaped_dragged_paths(self):
        self.check_setup(lambda value: ''.join('\\' + c if c in " \\'\"()$" else c for c in value))

    def test_path_text_is_not_executed(self):
        self.check_setup(lambda value: '"' + value + '"', '$(touch UNEXPECTED_EXECUTION).p12')


if __name__ == '__main__':
    unittest.main()
