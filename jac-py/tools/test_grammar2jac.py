"""Phase 1 generator integrity tests (INTEGRATION_PLAN.md)."""

from __future__ import annotations

import hashlib
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(_REPO / "reference" / "cpython" / "Tools" / "peg_generator"))

from action_translate import ActionTranslationError, ActionTranslator  # noqa: E402
from pegen.build import build_parser  # noqa: E402

import grammar2jac as g2j  # noqa: E402


class Grammar2JacTests(unittest.TestCase):
    def test_regeneration_matches_checked_in_parser(self) -> None:
        proc = subprocess.run(
            [sys.executable, str(_HERE / "grammar2jac.py"), "--check"],
            cwd=_REPO,
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr or proc.stdout)

    def test_reproducible_across_checkout_paths(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            for name in ("repo_a", "repo_b"):
                root = Path(tmp) / name
                (root / "jac-py" / "tools").mkdir(parents=True)
                (root / "jac-py" / "jacpython").mkdir(parents=True)
                subprocess.run(
                    ["cp", "-r", str(_REPO / "reference"), str(root / "reference")],
                    check=True,
                )
                for fname in ("grammar2jac.py", "action_translate.py"):
                    subprocess.run(
                        ["cp", str(_HERE / fname), str(root / "jac-py" / "tools" / fname)],
                        check=True,
                    )
            out_a = subprocess.run(
                [sys.executable, "jac-py/tools/grammar2jac.py", "--stdout"],
                cwd=Path(tmp) / "repo_a",
                capture_output=True,
                text=True,
                check=True,
            ).stdout
            out_b = subprocess.run(
                [sys.executable, "jac-py/tools/grammar2jac.py", "--stdout"],
                cwd=Path(tmp) / "repo_b",
                capture_output=True,
                text=True,
                check=True,
            ).stdout
            self.assertEqual(
                hashlib.sha256(out_a.encode()).hexdigest(),
                hashlib.sha256(out_b.encode()).hexdigest(),
            )

    def test_unknown_grammar_type_fails(self) -> None:
        with self.assertRaises(g2j.GrammarTypeError):
            g2j.jac_type("totally_unknown_ty")

    def test_unknown_action_fixture_fails(self) -> None:
        translator = ActionTranslator()
        with self.assertRaises(ActionTranslationError):
            translator.translate("_TotallyUnknownHelper(p, a)")

    def test_full_grammar_actions_translate(self) -> None:
        grammar, _, _ = build_parser(str(_REPO / g2j.GRAMMAR_PROVENANCE))
        translator = ActionTranslator()
        for rule in grammar.rules.values():
            for alt in rule.rhs.alts:
                if alt.action:
                    translator.translate(alt.action)

    def test_generated_provenance_is_repository_relative(self) -> None:
        text = g2j.generate_text()
        self.assertIn(f"from {g2j.GRAMMAR_PROVENANCE}", text.splitlines()[2])
        self.assertNotIn(os.path.abspath(_REPO), text)


if __name__ == "__main__":
    raise SystemExit(unittest.main())
