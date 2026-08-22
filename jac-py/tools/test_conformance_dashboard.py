"""Fast unit tests for the D2 conformance dashboard/ratchet tooling."""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_SPEC = importlib.util.spec_from_file_location(
    "conformance_dashboard", _HERE / "conformance_dashboard.py"
)
assert _SPEC and _SPEC.loader
cd = importlib.util.module_from_spec(_SPEC)
sys.modules.setdefault("conformance_dashboard", cd)
_SPEC.loader.exec_module(cd)


def _manifest(stems: list[str], wave: str = "p2_wave1") -> dict:
    return {
        "version": 1,
        "wave": wave,
        "module_count": len(stems),
        "modules": [{"stem": s, "gate_type": "oracle", "status": "gated"} for s in stems],
    }


def _write_manifest(tests_dir: Path, name: str, doc: dict) -> None:
    tests_dir.mkdir(parents=True, exist_ok=True)
    (tests_dir / name).write_text(json.dumps(doc), encoding="utf-8")


# ---------------------------------------------------------------------------
# ingestion


def test_discover_manifests_orders_by_wave_number(tmp_path: Path) -> None:
    for name in ("conformance_manifest_wave10.json", "conformance_manifest_wave2.json",
                 "conformance_manifest.json"):
        _write_manifest(tmp_path, name, _manifest(["x"]))
    paths = cd.discover_manifests(tmp_path)
    assert [p.name for p in paths] == [
        "conformance_manifest.json",
        "conformance_manifest_wave2.json",
        "conformance_manifest_wave10.json",
    ]


def test_entries_extracted_with_case_counts(tmp_path: Path) -> None:
    doc = _manifest(["getplatform"])
    doc["jacpython_results"] = {
        "getplatform": {"passed": 1, "failed": 0, "total": 1}
    }
    entries = cd.entries_from_doc(doc)
    assert entries["getplatform"]["status"] == "gated"
    assert entries["getplatform"]["cases_passed"] == 1
    assert entries["getplatform"]["cases_total"] == 1


def test_collect_state_reports_unreadable_manifest(tmp_path: Path) -> None:
    _write_manifest(tmp_path, "conformance_manifest.json", _manifest(["a"]))
    (tmp_path / "conformance_manifest_wave2.json").write_text("{bogus", encoding="utf-8")
    state, warnings = cd.collect_state(tmp_path)
    assert set(state) == {"a"}
    assert len(warnings) == 1


# ---------------------------------------------------------------------------
# ratchet


def _base_entry(**over) -> dict:
    entry = {"wave": "p2_wave1", "gate_type": "oracle", "status": "gated",
             "cases_passed": None, "cases_total": None}
    entry.update(over)
    return entry


def test_ratchet_passes_when_set_unchanged() -> None:
    baseline = {"a": _base_entry()}
    current = {"a": _base_entry()}
    assert cd.ratchet_regressions(baseline, current) == []


def test_ratchet_fails_when_entry_missing() -> None:
    problems = cd.ratchet_regressions({"a": _base_entry()}, {})
    assert problems == ["a: present in baseline, missing from manifests"]


def test_ratchet_fails_on_status_regression() -> None:
    problems = cd.ratchet_regressions(
        {"a": _base_entry()}, {"a": _base_entry(status="broken")}
    )
    assert any("status regressed" in p for p in problems)


def test_ratchet_fails_on_case_count_shrinkage() -> None:
    problems = cd.ratchet_regressions(
        {"a": _base_entry(cases_passed=3, cases_total=3)},
        {"a": _base_entry(cases_passed=2, cases_total=3)},
    )
    assert any("cases passed 3 -> 2" in p for p in problems)


def test_ratchet_allows_growth() -> None:
    baseline = {"a": _base_entry(cases_passed=1, cases_total=1)}
    current = {
        "a": _base_entry(cases_passed=2, cases_total=2),
        "b": _base_entry(),
    }
    assert cd.ratchet_regressions(baseline, current) == []
    assert cd.ratchet_new_entries(baseline, current) == ["b"]


# ---------------------------------------------------------------------------
# rendering + CLI


def test_render_markdown_includes_summary_and_rows(tmp_path: Path) -> None:
    state, warnings = cd.collect_state(tmp_path if tmp_path.is_dir() else tmp_path)
    state = {"m": _base_entry(cases_passed=None, cases_total=None)}
    text = cd.render_markdown(state, warnings)
    assert "# D2 Conformance Dashboard" in text
    assert "| `m` | p2_wave1 | oracle | gated | — |" in text
    assert "Gated modules: **1/1**" in text


def test_cli_check_fails_on_regression(tmp_path: Path) -> None:
    tests = tmp_path / "tests"
    _write_manifest(tests, "conformance_manifest.json", _manifest(["a", "b"]))
    baseline = tmp_path / "baseline.json"
    rc = cd.main(["--tests-dir", str(tests), "--baseline", str(baseline),
                  "--update-baseline"])
    assert rc == 0
    _write_manifest(tests, "conformance_manifest.json", _manifest(["a"]))
    rc = cd.main(["--tests-dir", str(tests), "--baseline", str(baseline), "--check"])
    assert rc == 1


def test_cli_check_passes_when_only_growing(tmp_path: Path, capsys) -> None:
    tests = tmp_path / "tests"
    _write_manifest(tests, "conformance_manifest.json", _manifest(["a"]))
    baseline = tmp_path / "baseline.json"
    cd.main(["--tests-dir", str(tests), "--baseline", str(baseline),
             "--update-baseline"])
    _write_manifest(tests, "conformance_manifest.json", _manifest(["a", "b"]))
    rc = cd.main(["--tests-dir", str(tests), "--baseline", str(baseline), "--check"])
    assert rc == 0
    assert "unpinned passing entries" in capsys.readouterr().err


def test_cli_report_writes_markdown_file(tmp_path: Path) -> None:
    tests = tmp_path / "tests"
    out = tmp_path / "dash.md"
    _write_manifest(tests, "conformance_manifest.json", _manifest(["a"]))
    rc = cd.main(["--tests-dir", str(tests),
                  "--baseline", str(tmp_path / "nope.json"),
                  "--out", str(out)])
    assert rc == 0
    assert "# D2 Conformance Dashboard" in out.read_text(encoding="utf-8")
