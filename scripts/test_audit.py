#!/usr/bin/env python3
"""Unit tests for scripts/audit.py -- the executable witness that the
provenance/methodology invariants actually FIRE on the interop-bench#1-#9
regressions (a green bridges test alone did not catch these).

Run:  scripts/.xtool-venv/bin/python -m pytest scripts/test_audit.py -q
  or:  python3 -m pytest scripts/test_audit.py -q
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path

_spec = importlib.util.spec_from_file_location(
    "audit", Path(__file__).with_name("audit.py")
)
audit = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(audit)


def _good_bundle(root: Path) -> Path:
    """A minimal but VALID canonical bundle that must pass every invariant."""
    d = root / "paper-canonical"
    agg = d / "aggregate"
    (d / "logs").mkdir(parents=True, exist_ok=True)
    agg.mkdir(parents=True, exist_ok=True)
    (d / "env.json").write_text(
        json.dumps({"git_dirty": False, "governor": "performance"})
    )

    (agg / "xtool_ffi.json").write_text(
        json.dumps(
            {
                "one_translation_unit": True,
                "oracle_all_toolchains_agree": True,
                "cells": {
                    "struct": {
                        "reference_digest": "struct:42",
                        "toolchains": {
                            "ctypes": {"digest": "struct:42", "digest_ok": True},
                            "cext": {"digest": "struct:42", "digest_ok": True},
                        },
                    }
                },
            }
        )
    )
    (agg / "sweep.json").write_text(
        json.dumps(
            {
                "reps": 3,
                "cells": {
                    "iop_call": {
                        "variants": {
                            "free": {
                                "per_work": {
                                    "100": {"n": 3, "digest": "call:1"},
                                }
                            }
                        }
                    }
                },
            }
        )
    )
    # payload: rpc dominates direct in both intercept and slope (no crossover)
    per_size = {}
    for n_el in (1, 100, 1000):
        per_size[f"p{n_el}"] = {
            "N": n_el,
            "direct": {
                "per_call_ns": 300 + 0.3 * n_el,
                "raw_per_call_ns": [300 + 0.3 * n_el] * 3,
                "n_reps": 3,
            },
            "rpc": {
                "per_call_ns": 15000 + 0.9 * n_el,
                "raw_per_call_ns": [15000 + 0.9 * n_el] * 3,
                "n_reps": 3,
            },
        }
    (agg / "payload.json").write_text(
        json.dumps(
            {
                "reps": 3,
                "cells": {"xop_feed_payload": {"per_size": per_size}},
            }
        )
    )
    (agg / "xtool_rpc.json").write_text(
        json.dumps(
            {
                "oracle_all_comparands_agree": True,
                "loopback": True,
                "two_box_mode": False,
            }
        )
    )

    files = {}
    for f in [d / "env.json", *sorted(agg.glob("*.json"))]:
        files[str(f.relative_to(d))] = hashlib.sha256(f.read_bytes()).hexdigest()
    (d / "MANIFEST.json").write_text(
        json.dumps({"git_sha": "deadbeef", "files": files})
    )
    return d


def _run(d: Path) -> list[str]:
    a = audit.Audit()
    audit.audit_env(a, d)
    audit.audit_manifest(a, d)
    audit.audit_ffi(a, d)
    audit.audit_sweep(a, d)
    audit.audit_payload(a, d)
    audit.audit_crossover(a, d)
    audit.audit_rpc(a, d)
    return a.failures


def test_good_bundle_passes(tmp_path: Path):
    assert _run(_good_bundle(tmp_path)) == []


def test_dirty_env_fails(tmp_path: Path):
    d = _good_bundle(tmp_path)
    (d / "env.json").write_text(json.dumps({"git_dirty": True}))
    assert any("git_dirty" in f for f in _run(d))


def test_short_sweep_cell_fails(tmp_path: Path):
    d = _good_bundle(tmp_path)
    doc = json.loads((d / "aggregate" / "sweep.json").read_text())
    doc["cells"]["iop_call"]["variants"]["free"]["per_work"]["100"]["n"] = 2
    (d / "aggregate" / "sweep.json").write_text(json.dumps(doc))
    assert any("n=2" in f and "reps=3" in f for f in _run(d))


def test_unmatched_ffi_struct_fails(tmp_path: Path):
    d = _good_bundle(tmp_path)
    doc = json.loads((d / "aggregate" / "xtool_ffi.json").read_text())
    # a scalar-substituted struct kernel -> different digest
    doc["cells"]["struct"]["toolchains"]["cext"]["digest"] = "struct:999"
    (d / "aggregate" / "xtool_ffi.json").write_text(json.dumps(doc))
    assert any("unmatched struct" in f for f in _run(d))


def test_payload_reps1_fails(tmp_path: Path):
    d = _good_bundle(tmp_path)
    doc = json.loads((d / "aggregate" / "payload.json").read_text())
    doc["reps"] = 1
    (d / "aggregate" / "payload.json").write_text(json.dumps(doc))
    assert any("reps=1" in f for f in _run(d))


def test_payload_no_raw_fails(tmp_path: Path):
    d = _good_bundle(tmp_path)
    doc = json.loads((d / "aggregate" / "payload.json").read_text())
    for slot in doc["cells"]["xop_feed_payload"]["per_size"].values():
        slot["direct"].pop("raw_per_call_ns", None)
    (d / "aggregate" / "payload.json").write_text(json.dumps(doc))
    assert any("raw per-invocation" in f for f in _run(d))


def test_false_crossover_fails(tmp_path: Path):
    """If direct's slope exceeds rpc's, a positive rpc==direct break-even
    exists and the audit must reject the 'curves converge' framing."""
    d = _good_bundle(tmp_path)
    doc = json.loads((d / "aggregate" / "payload.json").read_text())
    ps = doc["cells"]["xop_feed_payload"]["per_size"]
    for n_el, slot in zip((1, 100, 1000), ps.values(), strict=True):
        slot["direct"]["per_call_ns"] = 300 + 5.0 * n_el  # steeper than rpc
    (d / "aggregate" / "payload.json").write_text(json.dumps(doc))
    assert any("break-even" in f for f in _run(d))


def test_manifest_tamper_fails(tmp_path: Path):
    d = _good_bundle(tmp_path)
    (d / "aggregate" / "sweep.json").write_text(
        (d / "aggregate" / "sweep.json").read_text() + " "
    )
    assert any("sha mismatch" in f for f in _run(d))
