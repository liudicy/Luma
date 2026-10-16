"""Exercise the build helper without running signed test binaries or touching keys."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SigningSelectionTests(unittest.TestCase):
    def run_helper(self, annotated, include_good=True):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            certs = []
            for name in ('revoked', 'good'):
                cert = work / (name + '.pem')
                subprocess.run([
                    '/usr/bin/openssl', 'req', '-x509', '-newkey', 'rsa:2048',
                    '-nodes', '-keyout', str(work / (name + '.key')),
                    '-out', str(cert), '-days', '1',
                    '-subj', '/CN=Apple Development: Test ' + name + '/OU=TESTTEAM',
                ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                der = subprocess.check_output(['/usr/bin/openssl', 'x509', '-in', str(cert), '-outform', 'DER'])
                certs.append((cert, hashlib.sha1(der).hexdigest().upper()))
            identities = '  1) ' + certs[0][1] + ' "Apple Development: Test revoked"'
            identities += ' (CSSMERR_TP_CERT_REVOKED)\n' if annotated else '\n'
            if include_good:
                identities += '  2) ' + certs[1][1] + ' "Apple Development: Test good"\n'
            (work / 'identities.txt').write_text(identities)
            (work / 'all.pem').write_text(''.join(cert.read_text() for cert, _ in certs))
            utility = work / 'utility'
            utility.write_text('''#!/usr/bin/env python3
import json, os, pathlib, subprocess, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['TEST_EVENTS'], 'a') as f:
    f.write(json.dumps([name, args]) + '\\n')
if name == 'security':
    if args[0] == 'find-identity':
        print(pathlib.Path(os.environ['TEST_IDENTITIES']).read_text(), end='')
    elif args[0] == 'find-certificate':
        print(pathlib.Path(os.environ['TEST_CERTIFICATES']).read_text(), end='')
    elif args[0] == 'verify-cert':
        assert args[-4:] == ['-R', 'ocsp', '-R', 'require']
        cert = args[args.index('-c') + 1]
        der = subprocess.check_output(['/usr/bin/openssl', 'x509', '-in', cert, '-outform', 'DER'])
        import hashlib
        sys.exit(0 if hashlib.sha1(der).hexdigest().upper() == os.environ['TEST_TRUSTED'] else 1)
    else:
        sys.exit(90)
elif name == 'codesign':
    if args[0] == '--verify':
        sys.exit(0)
    if args[0] == '-dvvv':
        print('Identifier=com.liudicy.QuickRecorder\\nTeamIdentifier=TESTTEAM\\nCDHash=test', file=sys.stderr)
    else:
        sys.exit(91)  # No signing a probe is permitted.
elif name == 'xcodebuild':
    assert 'CODE_SIGN_IDENTITY=' + os.environ['TEST_TRUSTED'] in args
elif name == 'xcrun':
    sys.exit(92)  # The old helper compiled a native test program here.
else:
    sys.exit(93)
''')
            utility.chmod(0o755)
            for name in ('security', 'codesign', 'xcodebuild', 'xcrun'):
                (work / name).symlink_to(utility)
            env = dict(os.environ, PATH=str(work) + os.pathsep + os.environ['PATH'],
                       TEST_EVENTS=str(work / 'events.jsonl'),
                       TEST_IDENTITIES=str(work / 'identities.txt'),
                       TEST_CERTIFICATES=str(work / 'all.pem'), TEST_TRUSTED=certs[1][1])
            result = subprocess.run(['/bin/sh', str(ROOT / 'Scripts/build_and_check_signing.sh')],
                                    env=env, text=True, capture_output=True)
            events = [json.loads(line) for line in (work / 'events.jsonl').read_text().splitlines()]
            return result, events, certs[1][1]

    def test_annotated_revoked_identity_is_skipped(self):
        result, events, good = self.run_helper(annotated=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('identity: ' + good, result.stdout)
        self.assertEqual(sum(name == 'security' and args[0] == 'verify-cert' for name, args in events), 1)
        self.assertFalse(any(name == 'xcrun' for name, _ in events))
        self.assertFalse(any(name == 'codesign' and '--force' in args for name, args in events))

    def test_unannotated_untrusted_identity_is_rejected(self):
        result, events, good = self.run_helper(annotated=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('identity: ' + good, result.stdout)
        self.assertEqual(sum(name == 'security' and args[0] == 'verify-cert' for name, args in events), 2)

    def test_no_trusted_identity_stops_before_build(self):
        result, events, _ = self.run_helper(annotated=False, include_good=False)
        self.assertEqual(result.returncode, 1)
        self.assertFalse(any(name in ('xcodebuild', 'codesign', 'xcrun') for name, _ in events))


if __name__ == '__main__':
    unittest.main()
