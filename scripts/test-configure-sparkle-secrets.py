#!/usr/bin/env python3
"""Exercise Sparkle credential setup with local gh, security, and generate_keys stubs."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = Path(os.environ.get('CONFIGURE_SPARKLE_SCRIPT',
    ROOT / 'templates/macos-app/scripts/configure-sparkle-secrets.sh'))

GH_STUB = '''import os
from pathlib import Path
import sys
args = sys.argv[1:]
target = Path(os.environ['CAPTURED_SECRETS'])
if args[:2] == ['auth', 'status']:
    pass
elif args[:2] == ['secret', 'set']:
    repository = args[args.index('--repo') + 1].replace('/', '_')
    (target / repository).mkdir(exist_ok=True)
    (target / repository / args[2]).write_bytes(sys.stdin.buffer.read())
else:
    raise SystemExit('Unexpected gh invocation')
'''

SECURITY_STUB = '''import json
import os
from pathlib import Path
import shlex
import sys
store_path = Path(os.environ['KEYCHAIN_STORE'])
store = json.loads(store_path.read_text()) if store_path.exists() else {}
args = sys.argv[1:]
if args == ['-i']:
    for line in sys.stdin:
        command = shlex.split(line)
        if command and command[0] == 'add-generic-password':
            store[command[command.index('-s') + 1] + '/' + command[command.index('-a') + 1]] = command[command.index('-w') + 1]
    store_path.write_text(json.dumps(store))
elif args[:1] == ['find-generic-password']:
    value = store.get(args[args.index('-s') + 1] + '/' + args[args.index('-a') + 1])
    if value is None:
        raise SystemExit(44)
    print(value)
else:
    raise SystemExit('Unexpected security invocation')
'''

GENERATE_KEYS_STUB = '''import json
import os
from pathlib import Path
import sys
store_path = Path(os.environ['SPARKLE_KEY_STORE'])
store = json.loads(store_path.read_text()) if store_path.exists() else {}
args = sys.argv[1:]
account = args[args.index('--account') + 1]
if '-p' in args:
    if account not in store:
        print('ERROR: No existing signing key found!')
        raise SystemExit(1)
    print(store[account]['public'])
elif '-x' in args:
    Path(args[args.index('-x') + 1]).write_text(store[account]['private'])
else:
    store.setdefault(account, {'public': 'PUBLIC-' + account, 'private': 'PRIVATE-' + account})
    store_path.write_text(json.dumps(store))
    with open(os.environ['GENERATE_LOG'], 'a') as log:
        log.write(account + '\\n')
'''

ACCOUNT_ID = '0123456789abcdef0123456789abcdef'
SECRET = 'SecretAccessKey123'


class ConfigureSparkleSecretsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='sparkle credentials ')
        self.root = Path(self.temporary.name)
        self.captured = self.root / 'captured'
        self.captured.mkdir()
        bin_dir = self.root / 'bin'
        bin_dir.mkdir()
        for name, source in [('gh', GH_STUB), ('security', SECURITY_STUB), ('generate_keys', GENERATE_KEYS_STUB)]:
            stub = bin_dir / name
            stub.write_text(f'#!{sys.executable}\n' + source)
            stub.chmod(0o755)
        self.environment = dict(os.environ,
            PATH=str(bin_dir) + os.pathsep + os.environ['PATH'],
            CAPTURED_SECRETS=str(self.captured),
            KEYCHAIN_STORE=str(self.root / 'keychain.json'),
            SPARKLE_KEY_STORE=str(self.root / 'sparkle-keys.json'),
            GENERATE_LOG=str(self.root / 'generate.log'),
            SPARKLE_GENERATE_KEYS=str(bin_dir / 'generate_keys'))

    def tearDown(self):
        self.temporary.cleanup()

    def run_script(self, repository, bundle_id, inputs=(), *options):
        return subprocess.run(['bash', str(SCRIPT), repository, '--bundle-id', bundle_id, *options],
            input='\n'.join(inputs) + '\n', text=True, capture_output=True,
            env=self.environment, cwd=self.root)

    def secrets(self, repository):
        directory = self.captured / repository.replace('/', '_')
        return {path.name: path.read_text() for path in directory.iterdir()}

    def generated_accounts(self):
        log = self.root / 'generate.log'
        return log.read_text().split() if log.exists() else []

    def test_first_app_prompts_and_saves_r2_credentials(self):
        result = self.run_script('owner/needle', 'design.specos.needle', [ACCOUNT_ID, 'AccessKey123', SECRET])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.secrets('owner/needle'), {
            'SPARKLE_PRIVATE_KEY': 'PRIVATE-design.specos.needle',
            'R2_ACCOUNT_ID': ACCOUNT_ID,
            'R2_ACCESS_KEY_ID': 'AccessKey123',
            'R2_SECRET_ACCESS_KEY': SECRET,
        })
        keychain = json.loads((self.root / 'keychain.json').read_text())
        self.assertEqual(keychain['Specos Sparkle R2/secret-access-key'], SECRET)
        self.assertIn('<string>PUBLIC-design.specos.needle</string>', result.stdout)
        self.assertNotIn(SECRET, result.stdout + result.stderr)
        self.assertNotIn('PRIVATE-', result.stdout + result.stderr)

    def test_later_app_reuses_saved_r2_credentials_and_existing_key(self):
        first = self.run_script('owner/needle', 'design.specos.needle', [ACCOUNT_ID, 'AccessKey123', SECRET])
        self.assertEqual(first.returncode, 0, first.stderr)
        again = self.run_script('owner/needle', 'design.specos.needle')
        self.assertEqual(again.returncode, 0, again.stderr)
        other = self.run_script('owner/tacho', 'design.specos.tacho')
        self.assertEqual(other.returncode, 0, other.stderr)
        self.assertIn('Using R2 credentials saved', other.stdout)
        self.assertEqual(self.secrets('owner/tacho')['R2_SECRET_ACCESS_KEY'], SECRET)
        self.assertEqual(self.secrets('owner/tacho')['SPARKLE_PRIVATE_KEY'], 'PRIVATE-design.specos.tacho')
        self.assertEqual(self.generated_accounts(), ['design.specos.needle', 'design.specos.tacho'])

    def test_reset_replaces_saved_r2_credentials(self):
        self.run_script('owner/needle', 'design.specos.needle', [ACCOUNT_ID, 'AccessKey123', SECRET])
        result = self.run_script('owner/needle', 'design.specos.needle',
            [ACCOUNT_ID, 'AccessKey456', 'NewSecret456'], '--reset-r2-credentials')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.secrets('owner/needle')['R2_SECRET_ACCESS_KEY'], 'NewSecret456')

    def test_invalid_account_id_is_rejected_before_saving(self):
        result = self.run_script('owner/needle', 'design.specos.needle', ['not-an-account', 'AccessKey123', SECRET])
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / 'keychain.json').exists())
        self.assertFalse(any(self.captured.iterdir()))

    def test_bundle_identifier_is_required(self):
        result = subprocess.run(['bash', str(SCRIPT), 'owner/needle'], text=True,
            capture_output=True, env=self.environment, cwd=self.root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('--bundle-id', result.stderr)


if __name__ == '__main__':
    unittest.main()
