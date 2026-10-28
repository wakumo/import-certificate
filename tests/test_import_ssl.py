import base64
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "import-ssl.sh"
OPENSSL = "/usr/bin/openssl"


class ImportSSLTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixtures = tempfile.TemporaryDirectory()
        cls.root = Path(cls.fixtures.name)

        def openssl(*args):
            subprocess.run([OPENSSL, *map(str, args)], check=True,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        cls.openssl = staticmethod(openssl)
        cls.key = cls.root / "key.pem"
        openssl("genrsa", "-out", cls.key, "2048")
        cls.certs = {}
        for name, extensions in {
            "wiki": "basicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign",
            "plane": "basicConstraints=critical,CA:TRUE",
            "leaf": "basicConstraints=critical,CA:FALSE",
            "missing-bc": "keyUsage=keyCertSign",
            "bad-ku": "basicConstraints=CA:TRUE\nkeyUsage=digitalSignature",
            "expired": "basicConstraints=CA:TRUE",
            "future": "basicConstraints=CA:TRUE",
        }.items():
            folder = cls.root / name
            folder.mkdir()
            (folder / "index").write_text("")
            (folder / "serial").write_text("01\n")
            config = folder / "ca.cnf"
            config.write_text(
                f"[ca]\ndefault_ca=CA\n[CA]\ndatabase={folder}/index\n"
                f"serial={folder}/serial\nnew_certs_dir={folder}\n"
                "default_md=sha256\npolicy=policy\nx509_extensions=ext\n"
                "[policy]\ncommonName=supplied\n[ext]\n" + extensions + "\n")
            csr = folder / "request.pem"
            cert = folder / "cert.pem"
            openssl("req", "-new", "-key", cls.key, "-subj", f"/CN={name}", "-out", csr)
            start, end = "20200101000000Z", "20400101000000Z"
            if name == "expired":
                end = "20210101000000Z"
            if name == "future":
                start, end = "20400101000000Z", "20410101000000Z"
            openssl("ca", "-batch", "-selfsign", "-config", config,
                    "-keyfile", cls.key, "-in", csr, "-out", cert,
                    "-notext", "-startdate", start, "-enddate", end)
            cls.certs[name] = cert
        cls.der = cls.root / "root.der"
        openssl("x509", "-in", cls.certs["wiki"], "-outform", "DER", "-out", cls.der)
        intermediate = cls.root / "intermediate.pem"
        openssl("x509", "-req", "-in", cls.root / "plane/request.pem",
                "-CA", cls.certs["wiki"], "-CAkey", cls.key, "-set_serial", "2",
                "-days", "30", "-extfile", cls.root / "plane/ca.cnf",
                "-extensions", "ext", "-out", intermediate)
        cls.certs["intermediate"] = intermediate
        damaged = bytearray(cls.der.read_bytes())
        damaged[-1] ^= 1
        bad_signature = cls.root / "bad-signature.pem"
        bad_signature.write_bytes(b"-----BEGIN CERTIFICATE-----\n" +
                                  base64.encodebytes(damaged) + b"-----END CERTIFICATE-----\n")
        cls.certs["bad-signature"] = bad_signature

    @classmethod
    def tearDownClass(cls):
        cls.fixtures.cleanup()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.log = self.work / "commands"
        self.snapshot = self.work / "imported.pem"
        self.download = self.certs["plane"]
        self.env = dict(os.environ, COMMAND_LOG=str(self.log),
                        SNAPSHOT=str(self.snapshot), DOWNLOAD=str(self.download))
        shims = {
            "uname": '#!/bin/bash\nprintf "%s\\n" "${TEST_OS:-Darwin}"\n',
            "sudo": '#!/bin/bash\necho sudo >> "$COMMAND_LOG"\nexec "$@"\n',
            "security": '#!/bin/bash\necho "security $*" >> "$COMMAND_LOG"\n'
                        'if [ "$1" = add-trusted-cert ]; then\n'
                        '  cp "${@: -1}" "$SNAPSHOT"\n'
                        '  [ "${INSTALL_FAIL:-0}" = 0 ] || exit 1\n'
                        'else\n'
                        '  cmp "$3" "$SNAPSHOT" || exit 1\n'
                        '  [ "${VERIFY_FAIL:-0}" = 0 ] || exit 1\nfi\n',
            "curl": '#!/bin/bash\nprintf "%s\\n" "$@" >> "$COMMAND_LOG"\n'
                    '[ "${DOWNLOAD_FAIL:-0}" = 0 ] || exit 22\n'
                    'while [ "$1" != --output ]; do shift; done\n'
                    'cp "$DOWNLOAD" "$2"\n',
        }
        for name, content in shims.items():
            path = self.work / name
            path.write_text(content)
            path.chmod(0o700)
        # Only the test copy is rewritten; production has no command injection knobs.
        source = SCRIPT.read_text().replace(
            "PATH=/usr/bin:/bin:/usr/sbin:/sbin",
            f'PATH="{self.work}:/usr/bin:/bin:/usr/sbin:/sbin"')
        for command in ("security", "curl"):
            source = source.replace(f"/usr/bin/{command}", f'"{self.work / command}"')
        source = source.replace("/private/tmp/root-ca.XXXXXX",
                                str(self.work / "snapshot.XXXXXX"))
        self.script = self.work / "script.sh"
        self.script.write_text(source)

    def run_script(self, *args):
        result = subprocess.run(["/bin/bash", str(self.script), *map(str, args)],
                                input="", text=True, capture_output=True,
                                env=self.env, timeout=15)
        self.assertEqual(list(self.work.glob("snapshot.*")), [], "snapshot not cleaned up")
        return result

    def commands(self):
        return self.log.read_text() if self.log.exists() else ""

    def test_accepts_unpinned_roots_in_check_mode_without_sudo(self):
        for cert in (self.certs["wiki"], self.certs["plane"], self.der):
            with self.subTest(cert=cert):
                result = self.run_script("--file", cert, "--check")
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("Fingerprint=", result.stdout)
                self.assertIn("No trust settings changed", result.stdout)
        self.assertEqual(self.commands(), "")

    def test_install_without_stdin_normalizes_pem_and_verifies_same_snapshot(self):
        for cert in (self.certs["plane"], self.der):
            with self.subTest(cert=cert):
                result = self.run_script("--file", cert)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertTrue(self.snapshot.read_bytes().startswith(b"-----BEGIN CERTIFICATE-----"))
                self.assertNotIn("Type INSTALL", result.stdout)
                self.assertIn("add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain", self.commands())
                self.assertIn("security verify-cert", self.commands())

    def test_rejects_invalid_certificate_properties(self):
        for name in ("leaf", "missing-bc", "bad-ku", "intermediate", "expired", "future", "bad-signature"):
            with self.subTest(name=name):
                result = self.run_script("--file", self.certs[name])
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("sudo", self.commands())

    def test_rejects_bundles_keys_malformed_and_trailing_data(self):
        pem = self.certs["wiki"].read_bytes()
        for data in (pem + pem, pem + self.key.read_bytes(), self.key.read_bytes(),
                     b"<html>login</html>", b"", pem + b"garbage", self.der.read_bytes() + b"garbage",
                     self.der.read_bytes() * 2):
            with self.subTest(prefix=data[:30], length=len(data)):
                path = self.work / "invalid"
                path.write_bytes(data)
                result = self.run_script("--file", path)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("sudo", self.commands())

    def test_https_and_github_blob_downloads(self):
        for url, expected in (
            ("https://example.com/root.crt", "https://example.com/root.crt"),
            ("https://github.com/company/certs/blob/main/plane/root.crt",
             "https://raw.githubusercontent.com/company/certs/main/plane/root.crt"),
        ):
            with self.subTest(url=url):
                result = self.run_script("--file", url, "--check")
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn(expected, self.commands())
                self.assertIn("--proto\n=https\n--proto-redir\n=https", self.commands())
                self.assertIn("--disable\n--fail", self.commands())
                self.assertNotIn("sudo", self.commands())

    def test_download_failure_and_invalid_download_never_install(self):
        self.env["DOWNLOAD_FAIL"] = "1"
        result = self.run_script("--file", "https://example.com/root")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("download failed", result.stderr)
        self.env["DOWNLOAD_FAIL"] = "0"
        self.env["DOWNLOAD"] = str(self.certs["leaf"])
        self.assertNotEqual(self.run_script("--file", "https://example.com/root").returncode, 0)
        self.assertNotIn("sudo", self.commands())

    def test_install_and_verify_failures_propagate(self):
        for failure in ("INSTALL_FAIL", "VERIFY_FAIL"):
            with self.subTest(failure=failure):
                self.env[failure] = "1"
                result = self.run_script("--file", self.certs["wiki"])
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("sudo", self.commands())
                self.assertNotIn("installed and verified", result.stdout)
                del self.env[failure]

    def test_arguments(self):
        for args in ((), ("--file",), ("--file", ""), ("--file", "--check"),
                     ("--unknown",), ("--file", "a", "--file", "b"),
                     ("--file", "http://example.com/a"), ("--file", "ftp://example.com/a")):
            with self.subTest(args=args):
                self.assertEqual(self.run_script(*args).returncode, 2)
        self.assertNotEqual(self.run_script("--file", self.work / "missing").returncode, 0)
        self.assertEqual(self.run_script("--help").returncode, 0)
        self.assertEqual(self.commands(), "")

    def test_macos_only(self):
        self.env["TEST_OS"] = "Linux"
        result = self.run_script("--file", self.certs["wiki"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("macOS only", result.stderr)
        self.assertEqual(self.commands(), "")


if __name__ == "__main__":
    unittest.main()
