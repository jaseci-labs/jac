#!/usr/bin/env python3
"""Fast regression net for the cross-tool FFI harness matched-ness
(interop-bench#1): every AVAILABLE toolchain must bind the same C translation
unit with the SAME signature and agree on every kernel digest -- including the
struct-by-value kernel, which must NOT be a scalar reimplementation.

Only ctypes + a gcc C-extension are required (both present wherever gcc is);
cffi/pybind11/pyo3 join automatically when installed. Skips if gcc is absent.

Run:  python3 -m pytest scripts/test_xtool_ffi_matched.py -q --noconftest
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent


@pytest.mark.skipif(not shutil.which("gcc"), reason="gcc required")
def test_struct_kernel_matched_across_toolchains():
    out = Path(tempfile.mkdtemp()) / "ffi.json"
    # ctypes + cext always build with gcc; cffi joins if importable.
    tcs = "ctypes,cext"
    try:
        import cffi  # noqa: F401

        tcs += ",cffi"
    except ImportError:
        pass
    subprocess.run(
        [
            sys.executable,
            str(HERE / "xtool_ffi.py"),
            "--toolchains",
            tcs,
            "--reps",
            "1",
            "--matched-n",
            "300",
            "--isolated-n",
            "50000",
            "--out",
            str(out),
        ],
        check=True,
        capture_output=True,
        timeout=180,
    )
    doc = json.loads(out.read_text())

    assert doc["one_translation_unit"] is True
    assert doc["oracle_all_toolchains_agree"] is True

    for kernel in ("sqrt", "struct", "bytes"):
        cell = doc["cells"][kernel]
        ref = cell["reference_digest"]
        rows = cell["toolchains"]
        assert len(rows) >= 2, f"{kernel}: need >=2 toolchains, got {list(rows)}"
        for tc, row in rows.items():
            # the load-bearing assertion: the struct kernel really passed a Vec3
            # by value through the SAME ib_dot in every tool -> identical digest.
            assert row["digest"] == ref and row["digest_ok"], (
                f"{kernel}/{tc} digest {row['digest']} != ref {ref}"
            )


@pytest.mark.skipif(
    not (shutil.which("gcc") and shutil.which("jac")),
    reason="gcc + jac required",
)
def test_jac_na_anchors_all_three_shapes():
    """--jac-na must yield a measured (not skipped) Jac-native anchor for each
    signature shape: scalar (sqrt), struct-by-value, and bytes-pointer. Guards
    against the bytes anchor silently regressing back to a skip."""
    out = Path(tempfile.mkdtemp()) / "ffi.json"
    subprocess.run(
        [
            sys.executable,
            str(HERE / "xtool_ffi.py"),
            "--toolchains",
            "ctypes,cext",
            "--reps",
            "1",
            "--matched-n",
            "100",
            "--isolated-n",
            "20000",
            "--jac-na",
            "--out",
            str(out),
        ],
        check=True,
        capture_output=True,
        timeout=300,
    )
    jac_na = json.loads(out.read_text())["jac_na"]
    for shape in ("sqrt", "struct", "bytes"):
        cell = jac_na[shape]
        assert "skipped" not in cell, f"{shape} anchor skipped: {cell.get('skipped')}"
        assert cell["per_ffi_call_ns"] >= 0
        assert cell["digest"] and cell["digest"].startswith(f"{shape}:")
