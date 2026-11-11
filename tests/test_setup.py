"""Run with: python3 -m unittest discover -s tests -v."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest


REPOSITORY = Path(__file__).resolve().parents[1]
MOCK_COMMAND = r'''#!/usr/bin/python3
import json, os, pathlib, sys
root = pathlib.Path(os.environ['WSL_SETUP_TEST_ROOT'])
options = json.loads(os.environ.get('WSL_SETUP_TEST_OPTIONS', '{}'))
name, args = pathlib.Path(sys.argv[0]).name, sys.argv[1:]
with (root / 'calls.jsonl').open('a') as log:
    log.write(json.dumps(dict(name=name, args=args,
        offline=os.environ.get('MISE_OFFLINE'),
        auto_update=os.environ.get('MISE_SELF_UPDATE_AUTO'))) + '\n')
if name == 'dpkg':
    print(options.get('architecture', 'amd64'))
elif name == 'uname':
    print(options.get('kernel', '6.18.0-microsoft-standard-WSL2'))
elif name == 'dpkg-query':
    import tomllib
    with (root / 'config.toml').open('rb') as config_file:
        packages = tomllib.load(config_file)['bootstrap']['packages']
    installed = 'apt:' + args[-1] in packages
    installed = installed and args[-1] != options.get('missing_package')
    print('installed' if installed else 'not-installed', end='')
elif name == 'python3':
    if args[0] == '-':
        os.execv('/usr/bin/python3', ['/usr/bin/python3', *args])
    sys.exit(1 if options.get('missing_venv') else 0)
elif name == 'mise':
    if args[0] == 'which':
        if args[1] == options.get('missing_tool'): sys.exit(1)
        print(root / 'bin' / args[1])
elif name in {'node', 'go', 'dotnet', 'pnpm'}:
    if name == options.get('broken_tool'): sys.exit(1)
    if name != options.get('empty_tool'): print(name + ' test-version')
elif name == 'ps':
    print('systemd')
elif name == 'systemctl':
    if options.get('inactive_docker') and args[-1] == 'docker': sys.exit(3)
elif name == 'docker':
    if 'info' in args:
        assert args[:2] == ['--host', 'unix:///var/run/docker.sock']
        if options.get('docker_denied'): sys.exit(1)
elif name == 'ssh-add.exe':
    if options.get('empty_agent'): sys.exit(1)
elif name == 'getent':
    if args[0] == 'passwd':
        print('test-user:x:1000:1000::/unused:/usr/bin/zsh')
    elif options.get('dns_failure'):
        sys.exit(2)
    else:
        print('127.0.0.1 test-address')
elif name == 'git':
    print({'core.sshCommand': 'ssh.exe', 'user.name': 'Test User',
           'user.email': 'test@example.invalid'}[args[-1]])
elif name == 'openssl':
    sys.exit(1 if options.get('expired_certificate') else 0)
elif name in {'sudo', 'curl'}:
    raise RuntimeError('Unexpected mutation/download command: ' + name)
'''


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='wsl-setup-test-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / 'bin').mkdir()
        (self.root / 'scripts').mkdir()
        self.release = self.root / 'os-release'
        self.release.write_text('ID=ubuntu\nVERSION_ID="26.04"\nPRETTY_NAME="Ubuntu 26.04"\n')
        shutil.copyfile(REPOSITORY / 'config.toml', self.root / 'config.toml')
        for name in ['check-platform.sh', 'verify-setup.sh', 'enable-systemd.awk']:
            text = (REPOSITORY / 'scripts' / name).read_text()
            text = text.replace('source /etc/os-release', 'source ' + shlex.quote(str(self.release)))
            text = text.replace('mise_bin="$HOME/.local/bin/mise"',
                                'mise_bin=' + shlex.quote(str(self.root / 'bin/mise')))
            text = text.replace('trust_dir="$HOME/.aspnet/dev-certs/trust"',
                                'trust_dir=' + shlex.quote(str(self.root / 'trust')))
            (self.root / 'scripts' / name).write_text(text)
        (self.root / 'bootstrap.sh').write_text((REPOSITORY / 'bootstrap.sh').read_text())
        helper = self.root / 'mock-command'
        helper.write_text(MOCK_COMMAND)
        helper.chmod(0o755)
        commands = ['dpkg', 'dpkg-query', 'uname', 'python3', 'mise', 'node', 'go',
                    'dotnet', 'pnpm', 'oh-my-posh', 'fzf', 'entire', 'codex', 'claude',
                    'ps', 'systemctl', 'docker', 'ssh.exe', 'ssh-add.exe', 'git',
                    'getent', 'google-chrome', 'openssl', 'sudo', 'curl']
        for command in commands:
            (self.root / 'bin' / command).symlink_to(helper)

    def run_script(self, name='scripts/verify-setup.sh', arguments=(), **options):
        environment = os.environ.copy()
        environment.update(
            PATH=str(self.root / 'bin') + ':/usr/bin:/bin',
            WSL_SETUP_TEST_ROOT=str(self.root), WSL_SETUP_TEST_OPTIONS=json.dumps(options),
            MISE_CONFIG_DIR=str(self.root / 'config/mise'),
            DISPLAY='', WAYLAND_DISPLAY='', SSL_CERT_DIR='',
        )
        return subprocess.run(['/bin/bash', str(self.root / name), *arguments],
                              env=environment, text=True, capture_output=True, timeout=30)

    def calls(self):
        log = self.root / 'calls.jsonl'
        return [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []

    def test_success_allows_optional_setup_warnings(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('0 failed.', result.stdout)
        self.assertIn('WARN No WSLg display socket', result.stdout)
        self.assertIn('WARN No unexpired ASP.NET', result.stdout)
        queries = [call for call in self.calls() if call['name'] == 'mise']
        self.assertTrue(queries)
        for call in queries:
            self.assertIn(call['args'][0], ['which', '--version'])
            self.assertEqual(call['offline'], '1')
            self.assertEqual(call['auto_update'], 'false')
        self.assertFalse(any(call['name'] in {'sudo', 'curl'} for call in self.calls()))

    def test_required_failures_are_accumulated(self):
        result = self.run_script(missing_package='jq', missing_venv=True,
                                 docker_denied=True, empty_agent=True, inactive_docker=True)
        self.assertEqual(result.returncode, 1)
        for message in ['FAIL Package jq', 'FAIL Python venv', 'FAIL Local Docker daemon',
                        'FAIL Windows SSH agent', 'FAIL Docker service', 'Verification:']:
            self.assertIn(message, result.stdout)
        self.assertIn('PASS Google Chrome', result.stdout)

    def test_runtime_failures_and_empty_sdk_list_are_failures(self):
        result = self.run_script(broken_tool='node', empty_tool='dotnet', missing_tool='go')
        self.assertEqual(result.returncode, 1)
        self.assertIn('FAIL node is installed', result.stdout)
        self.assertIn('FAIL dotnet is installed', result.stdout)
        self.assertIn('FAIL Mise tool go is missing', result.stdout)

    def test_dns_failure_affects_online_verification(self):
        result = self.run_script(dns_failure=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('FAIL DNS resolves mise.run', result.stdout)

    def test_offline_skips_dns_queries(self):
        result = self.run_script(arguments=['--offline'], dns_failure=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('SKIP DNS lookups', result.stdout)
        self.assertFalse(any(call['name'] == 'getent' and call['args'][0] == 'ahosts'
                             for call in self.calls()))

    def test_expired_certificate_is_a_warning(self):
        (self.root / 'trust').mkdir()
        (self.root / 'trust/dev.pem').write_text('mock public certificate')
        result = self.run_script(expired_certificate=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('WARN No unexpired ASP.NET', result.stdout)

    def test_certificate_path_must_be_in_the_environment(self):
        (self.root / 'trust').mkdir()
        (self.root / 'trust/dev.pem').write_text('mock public certificate')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('PASS An unexpired ASP.NET', result.stdout)
        self.assertIn('WARN SSL_CERT_DIR', result.stdout)

    def test_help_and_invalid_flags_do_not_run_checks(self):
        result = self.run_script(arguments=['--help'])
        self.assertEqual(result.returncode, 0)
        self.assertFalse(self.calls())
        result = self.run_script(arguments=['--unknown'])
        self.assertEqual(result.returncode, 1)
        self.assertFalse(self.calls())

    def assert_bootstrap_rejects(self, expected, **options):
        result = self.run_script(name='bootstrap.sh', arguments=['--dry-run'], **options)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(expected, result.stderr)
        self.assertTrue(all(call['name'] in {'dpkg', 'uname'} for call in self.calls()))
        self.assertFalse((self.root / 'config').exists())

    def test_bootstrap_rejects_old_ubuntu_before_changes(self):
        self.release.write_text('ID=ubuntu\nVERSION_ID="24.04"\nPRETTY_NAME="Ubuntu 24.04"\n')
        self.assert_bootstrap_rejects('requires Ubuntu 26.04')

    def test_bootstrap_rejects_another_distribution_before_changes(self):
        self.release.write_text('ID=debian\nVERSION_ID="13"\nPRETTY_NAME="Debian"\n')
        self.assert_bootstrap_rejects('requires Ubuntu 26.04')

    def test_bootstrap_rejects_arm_before_changes(self):
        self.assert_bootstrap_rejects('requires amd64', architecture='arm64')

    def test_bootstrap_rejects_wsl1_before_changes(self):
        self.assert_bootstrap_rejects('requires WSL 2', kernel='4.4.0-Microsoft')


if __name__ == '__main__':
    unittest.main()
