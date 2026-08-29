import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "audit_report.py"


class AuditReportTest(unittest.TestCase):
    def run_report(self, content: str):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        directory = Path(temporary.name)
        source, output = directory / "audit.log", directory / "report.json"
        source.write_text(content, encoding="utf-8")
        completed = subprocess.run(
            [sys.executable, str(SCRIPT), "--input", str(source), "--output", str(output)],
            capture_output=True,
            text=True,
            check=False,
        )
        return completed, output

    def test_ok_log_creates_json_and_returns_zero(self):
        completed, output = self.run_report(
            "2026-08-29T10:00:00+0000 [INFO] 点検開始\n"
            "2026-08-29T10:00:01+0000 [OK] ディスク正常\n"
        )
        self.assertEqual(completed.returncode, 0)
        report = json.loads(output.read_text(encoding="utf-8"))
        self.assertEqual(report["result"], "OK")
        self.assertEqual(report["counts"]["OK"], 1)

    def test_warning_is_preserved_as_exit_one(self):
        completed, output = self.run_report(
            "2026-08-29T10:00:00+0000 [WARN] ディスク使用率 90%\n"
        )
        self.assertEqual(completed.returncode, 1)
        self.assertEqual(json.loads(output.read_text(encoding="utf-8"))["result"], "WARN")

    def test_unknown_line_returns_two_and_creates_nothing(self):
        completed, output = self.run_report("形式が違う行\n")
        self.assertEqual(completed.returncode, 2)
        self.assertIn("1行目", completed.stderr)
        self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
