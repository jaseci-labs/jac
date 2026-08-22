"""Unit tests for T8 automated patch loop driver (jac-py/PLAN.md §6.8)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from t8_driver import (
    ByllmPatcher,
    MockPatcher,
    PatchResult,
    RulePatcher,
    build_prompt_payload,
    emit_queue,
    get_patcher,
    refresh_aggregate_report,
    remove_site_from_sidecar,
    run_loop,
)


def _write_sidecar(
    path: Path,
    *,
    output: str,
    source: str,
    sites: list[dict],
) -> None:
    path.write_text(
        json.dumps(
            {
                "version": 1,
                "lenient": True,
                "output": output,
                "source": source,
                "tier_b_count": len(sites),
                "quarantined_functions": [],
                "sites": sites,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def _write_aggregate(path: Path, output: str, sidecar_rel: str, tier_b: int) -> None:
    path.write_text(
        json.dumps(
            {
                "version": 1,
                "tier_b_total": tier_b,
                "quarantined_functions": [],
                "files": [
                    {
                        "output": output,
                        "source": "tools/fixture/module.c",
                        "tier_b_count": tier_b,
                        "quarantined_functions": [],
                    }
                ],
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


class PromptPayloadTests(unittest.TestCase):
    def test_build_prompt_payload_shape(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            jac = root / "module.jac"
            jac.write_text(
                "\n".join(
                    [
                        "# c2jac: 1 best-effort site",
                        "#   L6 [W4201] cast to `char` elided",
                        "",
                        "def c_strcmp(a: str, b: str) -> int {",
                        "    return 0;",
                        "}",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            site = {
                "sidecar": "module.c2jac.report.json",
                "source": "tools/fixture/module.c",
                "output": str(jac),
                "code": "W4201",
                "band": "style",
                "line": 6,
                "msg": "cast to `char` elided",
                "function": "c_strcmp",
                "context": ["    return (unsigned char)*a - (unsigned char)*b;"],
            }
            payload = build_prompt_payload(site)
            self.assertEqual(payload["site"]["code"], "W4201")
            self.assertEqual(payload["reason"], site["msg"])
            self.assertIn("def c_strcmp", payload["jac_function"])
            self.assertIn("def c_strcmp", payload["jac_output"])


class QueueTests(unittest.TestCase):
    def test_emit_queue_from_aggregate(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out_rel = "lift/module.jac"
            sidecar_rel = "lift/module.c2jac.report.json"
            jac = root / "lift" / "module.jac"
            sidecar = root / "lift" / "module.c2jac.report.json"
            aggregate = root / "lift" / "project.c2jac.report.json"
            jac.parent.mkdir(parents=True)
            jac.write_text("def f() -> int { return 1; }\n", encoding="utf-8")
            _write_sidecar(
                sidecar,
                output=out_rel,
                source="tools/fixture/module.c",
                sites=[
                    {
                        "band": "style",
                        "code": "W4201",
                        "function": "f",
                        "line": 1,
                        "msg": "cast elided",
                        "quarantined": False,
                    }
                ],
            )
            _write_aggregate(aggregate, out_rel, sidecar_rel, 1)

            with patch("t8_tier_b_queue._REPO", root), patch("t8_driver._REPO", root):
                queue = emit_queue(aggregate)
            self.assertEqual(len(queue), 1)
            self.assertEqual(queue[0]["code"], "W4201")


class SidecarRefreshTests(unittest.TestCase):
    def test_remove_site_and_refresh_aggregate(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out_rel = "lift/module.jac"
            sidecar = root / "lift" / "module.c2jac.report.json"
            aggregate = root / "lift" / "project.c2jac.report.json"
            sidecar.parent.mkdir(parents=True)
            site = {
                "band": "style",
                "code": "W4201",
                "function": "f",
                "line": 6,
                "msg": "cast elided",
                "quarantined": False,
            }
            _write_sidecar(
                sidecar,
                output=out_rel,
                source="tools/fixture/module.c",
                sites=[site],
            )
            _write_aggregate(aggregate, out_rel, "lift/module.c2jac.report.json", 1)

            with patch("t8_driver._REPO", root):
                self.assertTrue(remove_site_from_sidecar(sidecar, site))
                refresh_aggregate_report(aggregate)
                agg = json.loads(aggregate.read_text(encoding="utf-8"))
                sc = json.loads(sidecar.read_text(encoding="utf-8"))
            self.assertEqual(sc["tier_b_count"], 0)
            self.assertEqual(agg["tier_b_total"], 0)


class RulePatcherTests(unittest.TestCase):
    def test_w4201_char_rule_edits_jac_and_sidecar(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out_rel = "lift/getbuildinfo.jac"
            jac = root / "lift" / "getbuildinfo.jac"
            sidecar = root / "lift" / "getbuildinfo.c2jac.report.json"
            jac.parent.mkdir(parents=True)
            msg = (
                "cast to `char` elided — representation-changing conversion "
                "(truncation/narrowing/discard) not applied"
            )
            jac.write_text(
                "\n".join(
                    [
                        "# c2jac: 1 best-effort site",
                        f"#   L6 [W4201] {msg}",
                        "",
                        "def c_strcmp(a: str, b: str) -> int {",
                        "    return ((ord(a[0]) if a else 0) - (ord(b[0]) if b else 0));",
                        "}",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            site = {
                "sidecar": "lift/getbuildinfo.c2jac.report.json",
                "source": "tools/fixture/getbuildinfo.c",
                "output": out_rel,
                "code": "W4201",
                "function": "c_strcmp",
                "line": 6,
                "msg": msg,
            }
            _write_sidecar(
                sidecar,
                output=out_rel,
                source="tools/fixture/getbuildinfo.c",
                sites=[
                    {
                        "band": "style",
                        "code": "W4201",
                        "function": "c_strcmp",
                        "line": 6,
                        "msg": msg,
                        "quarantined": False,
                    }
                ],
            )

            with patch("t8_driver._REPO", root):
                result = RulePatcher().apply(site, build_prompt_payload(site))
                sc = json.loads(sidecar.read_text(encoding="utf-8"))
                text = jac.read_text(encoding="utf-8")

            self.assertTrue(result.applied)
            self.assertEqual(sc["tier_b_count"], 0)
            self.assertIn("& 255", text)
            self.assertNotIn("[W4201]", text)

    def test_w4201_char_py_tolower_rule(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out_rel = "lift/pystrnicmp.jac"
            jac = root / "lift" / "pystrnicmp.jac"
            sidecar = root / "lift" / "pystrnicmp.c2jac.report.json"
            jac.parent.mkdir(parents=True)
            msg = (
                "cast to `char` elided — representation-changing conversion "
                "(truncation/narrowing/discard) not applied"
            )
            jac.write_text(
                "\n".join(
                    [
                        "# c2jac: 1 best-effort site",
                        f"#   L5 [W4201] {msg}",
                        "",
                        "def _py_tolower(c: int) -> int {",
                        "    if ((c >= 65) and (c <= 90)) {",
                        "        return (c + (97 - 65));",
                        "    }",
                        "    return c;",
                        "}",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            site = {
                "sidecar": "lift/pystrnicmp.c2jac.report.json",
                "source": "tools/fixture/pystrnicmp.c",
                "output": out_rel,
                "code": "W4201",
                "function": "_py_tolower",
                "line": 5,
                "msg": msg,
            }
            _write_sidecar(
                sidecar,
                output=out_rel,
                source="tools/fixture/pystrnicmp.c",
                sites=[site],
            )

            with patch("t8_driver._REPO", root):
                result = RulePatcher().apply(site, build_prompt_payload(site))
                text = jac.read_text(encoding="utf-8")
                sc = json.loads(sidecar.read_text(encoding="utf-8"))

            self.assertTrue(result.applied)
            self.assertEqual(sc["tier_b_count"], 0)
            self.assertIn("& 255", text)

    def test_w4201_int_pystrnicmp_rule_removes_duplicate_sites(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out_rel = "lift/pystrnicmp.jac"
            jac = root / "lift" / "pystrnicmp.jac"
            sidecar = root / "lift" / "pystrnicmp.c2jac.report.json"
            jac.parent.mkdir(parents=True)
            msg = (
                "cast to `int` elided — representation-changing conversion "
                "(truncation/narrowing/discard) not applied"
            )
            jac.write_text(
                "\n".join(
                    [
                        "# c2jac: 2 best-effort sites",
                        f"#   L23 [W4201] {msg}",
                        f"#   L23 [W4201] {msg}",
                        "",
                        "def PyOS_mystrnicmp(s1: str, s2: str, size: int) -> int {",
                        "    p1: str = s1;",
                        "    p2: str = s2;",
                        "    return (",
                        "        _py_tolower((ord(p1[0]) if p1 else 0)) - _py_tolower((ord(p2[0]) if p2 else 0))",
                        "    );",
                        "}",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            site = {
                "band": "style",
                "code": "W4201",
                "function": "PyOS_mystrnicmp",
                "line": 23,
                "msg": msg,
                "quarantined": False,
            }
            _write_sidecar(
                sidecar,
                output=out_rel,
                source="tools/fixture/pystrnicmp.c",
                sites=[site, dict(site)],
            )
            payload_site = {
                "sidecar": "lift/pystrnicmp.c2jac.report.json",
                "source": "tools/fixture/pystrnicmp.c",
                "output": out_rel,
                **site,
            }

            with patch("t8_driver._REPO", root):
                result = RulePatcher().apply(payload_site, build_prompt_payload(payload_site))
                text = jac.read_text(encoding="utf-8")
                sc = json.loads(sidecar.read_text(encoding="utf-8"))

            self.assertTrue(result.applied)
            self.assertEqual(sc["tier_b_count"], 0)
            self.assertIn("as int", text)


class LoopTests(unittest.TestCase):
    def test_run_loop_accepts_mock_patcher(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out_rel = "lift/module.jac"
            sidecar = root / "lift" / "module.c2jac.report.json"
            aggregate = root / "lift" / "project.c2jac.report.json"
            sidecar.parent.mkdir(parents=True)
            site = {
                "band": "style",
                "code": "W4201",
                "function": "f",
                "line": 1,
                "msg": "cast elided",
                "quarantined": False,
            }
            _write_sidecar(
                sidecar,
                output=out_rel,
                source="tools/fixture/module.c",
                sites=[site],
            )
            _write_aggregate(aggregate, out_rel, "lift/module.c2jac.report.json", 1)

            with patch("t8_driver._REPO", root), patch(
                "t8_accept.validate",
                return_value=({"sites_before": 1, "sites_after": 0, "sites_fixed": 1}, []),
            ):
                result = run_loop(
                    aggregate,
                    MockPatcher(),
                    max_iterations=3,
                    run_tests=False,
                )

            self.assertEqual(result.patches_accepted, 1)
            self.assertEqual(result.queue_remaining, 0)

    def test_run_loop_stops_at_max_iterations(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out_rel = "lift/module.jac"
            sidecar = root / "lift" / "module.c2jac.report.json"
            aggregate = root / "lift" / "project.c2jac.report.json"
            sidecar.parent.mkdir(parents=True)
            site = {
                "band": "style",
                "code": "W4201",
                "function": "f",
                "line": 1,
                "msg": "cast elided",
                "quarantined": False,
            }
            _write_sidecar(
                sidecar,
                output=out_rel,
                source="tools/fixture/module.c",
                sites=[site],
            )
            _write_aggregate(aggregate, out_rel, "lift/module.c2jac.report.json", 1)

            class NoopPatcher:
                def apply(self, s: dict, payload: dict) -> PatchResult:
                    del s, payload
                    return PatchResult(False, "noop")

            with patch("t8_driver._REPO", root):
                result = run_loop(
                    aggregate,
                    NoopPatcher(),
                    max_iterations=2,
                    run_tests=False,
                )

            self.assertEqual(result.iterations, 2)
            self.assertEqual(result.patches_accepted, 0)
            self.assertGreater(result.queue_remaining, 0)

    def test_byllm_patcher_not_implemented(self) -> None:
        patcher = get_patcher("byllm")
        with self.assertRaises(NotImplementedError):
            patcher.apply({}, {})

    def test_get_patcher_mock(self) -> None:
        self.assertIsInstance(get_patcher("mock"), MockPatcher)


if __name__ == "__main__":
    unittest.main()
