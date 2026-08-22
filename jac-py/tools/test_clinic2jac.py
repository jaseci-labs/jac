"""P3.1d clinic2jac generator integrity tests."""

from __future__ import annotations

import os
import subprocess
import sys
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
sys.path.insert(0, str(_HERE))

import clinic2jac as c2j  # noqa: E402


class Clinic2JacTests(unittest.TestCase):
    def test_regeneration_matches_checked_in_output(self) -> None:
        proc = subprocess.run(
            [sys.executable, str(_HERE / "clinic2jac.py"), "--check"],
            cwd=_REPO,
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr or proc.stdout)

    def test_generated_provenance_is_repository_relative(self) -> None:
        text = c2j.generate_text()
        self.assertIn(f"from {c2j.FIXTURE_PROVENANCE}", text.splitlines()[2])
        self.assertNotIn(os.path.abspath(_REPO), text)

    def test_bool_new_fixture_parses_one_function(self) -> None:
        source = Path(c2j.FIXTURE_PATH).read_text(encoding="utf-8")
        funcs = c2j.parse_fixture(source, filename=c2j.FIXTURE_PATH)
        self.assertEqual(len(funcs), 1)
        func = funcs[0]
        self.assertEqual(func.c_basename, "bool_new")
        self.assertEqual(func.full_name, "bool.__new__")
        params = list(func.render_parameters)
        self.assertEqual(len(params), 2)
        self.assertEqual(params[1].name, "object")
        self.assertTrue(params[1].is_optional())
        self.assertTrue(params[1].is_positional_only())

    def test_bool_new_output_contains_impl_and_glue(self) -> None:
        text = c2j.generate_text()
        self.assertIn("def bool_new_impl(type: PyTypeObject, object: PyObj | None = None)", text)
        self.assertIn("def bool_new(type: PyTypeObject, args: PyObj, kwds: PyObj)", text)
        self.assertIn("_PyArg_NoKeywords", text)
        self.assertIn("_PyArg_CheckPositional", text)
        self.assertIn("PyTuple_GET_SIZE", text)
        self.assertIn("PyTuple_GET_ITEM", text)
        self.assertIn("glob bool_new__doc__", text)


if __name__ == "__main__":
    raise SystemExit(unittest.main())
