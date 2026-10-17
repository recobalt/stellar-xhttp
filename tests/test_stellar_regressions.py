"""Stellar regressions: isolated functions, no installation or real Docker."""
import json
from pathlib import Path
import tempfile
import unittest
import test_xhttp_shell


class StellarRegressions(unittest.TestCase):
    def shell(self, code, **env):
        return test_xhttp_shell.XhttpShellTests().run_shell(code, **env)

    def test_ssh_detection_drains_large_sshd_output_without_sigpipe(self):
        result = self.shell('''
unset SSH_CONNECTION
SSH_PORT='';ADMIN_IP='';NO_TRAFFIC=1;NODE_PORT=2222
sshd(){ python3 -c 'print("port 2202");print("other option\\n"*100000)'; }
security_plan
[[ $SSH_PORT == 2202 ]]
''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_new_node_generates_keys_offline_without_exec_or_start(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = self.shell('''
WORK=$TEST_WORK;NODE_NEW=1;SELECTED_IMAGE=sha256:fixture;XRAY_BIN=/bin/xray
ss(){ :; }
docker(){
    [[ $* == 'run --rm --network none --entrypoint /bin/xray sha256:fixture x25519' ]] || return 90
    printf 'PrivateKey: %s\\nPassword: %s\\n' "$TEST_PRIVATE" "$TEST_PUBLIC"
}
generate_reality_keys
''', TEST_WORK=tmp, TEST_PRIVATE='A'*43, TEST_PUBLIC='B'*43)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads((Path(tmp)/'keys.json').read_text()),
                             {'private': 'A'*43, 'public': 'B'*43})
            self.assertNotIn('A'*43, result.stdout+result.stderr)

    def test_existing_listener_still_prevents_generating_replacement_keys(self):
        result = self.shell('''
NODE_NEW=0;NODE_CONTAINER=fixture
ss(){ printf 'LISTEN existing\\n'; }
docker(){ echo SHOULD_NOT_EXECUTE;return 90; }
generate_reality_keys
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Импортируйте профиль', result.stderr)
        self.assertNotIn('SHOULD_NOT_EXECUTE', result.stdout+result.stderr)

    def test_fresh_keys_are_generated_before_compose_starts_node(self):
        source=test_xhttp_shell.SOURCE.split('prepare_node() {', 1)[1].split('\nconfigure_site()', 1)[0]
        self.assertLess(source.index('generate_reality_keys'),source.index('"${COMPOSE_CMD[@]}" up'))

    def test_optional_modules_are_off_and_can_be_enabled_explicitly(self):
        result=self.shell('''
[[ $NO_TUNING == 1 && $NO_UPDATES == 1 && $NO_TRAFFIC == 1 && $NO_PRIVACY == 1 ]]
parse_args --with-tuning --with-updates --with-traffic-control --with-two-way-ping
[[ $NO_TUNING == 0 && $NO_UPDATES == 0 && $NO_TRAFFIC == 0 && $NO_PRIVACY == 0 ]]
''')
        self.assertEqual(result.returncode,0,result.stderr)
