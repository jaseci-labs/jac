"""Drift guard: the in-compiler ``.jac`` bridge generators must stay identical to
the ``jac_bridge_loader`` Python reference.

There are two copies of the bridge metadata parser + code generators:

  * the Python reference in ``jac_bridge_loader`` (this package) — where features
    are developed and the conformance suite runs, and
  * the self-contained ``.jac`` port shipped INSIDE jaclang
    (``jaclang.compiler.rust_bridge``) — what actually runs when a user program
    does ``import from rust.<crate>`` with no external package installed.

They drifted once (the ``.jac`` port lagged behind Option / adopt-ctor / nested /
callback support and silently skipped nine owning-bridge methods). This test
re-generates from the SAME built ``.so`` metadata through BOTH implementations and
asserts they agree, so any future divergence fails CI instead of silently
degrading the compiler path. Gated on jaclang being importable; skips cleanly in
the pure-Python CI leg.
"""

from __future__ import annotations

from pathlib import Path

import pytest

# Reference implementation (this package).
from jac_bridge_loader._blob import parse as ref_parse
from jac_bridge_loader._codegen import build_module as ref_build_module
from jac_bridge_loader._elf import read_jac_bridge_section
from jac_bridge_loader._na_codegen import render_na_source as ref_render

# The in-compiler .jac port. Importing it triggers jaclang's meta-importer to
# compile the .jac modules; if jaclang is not importable in this leg, skip.
jac_blob = pytest.importorskip("jaclang.compiler.rust_bridge._blob")
jac_synth = pytest.importorskip("jaclang.compiler.rust_bridge._synth")
jac_ctypes = pytest.importorskip("jaclang.compiler.rust_bridge._ctypes_codegen")

REPO = Path(__file__).resolve().parents[4]


def _built_sos() -> list[Path]:
    out = []
    for stem in (
        "libjac_bridge_owning.so",
        "libjac_bridge_regex.so",
        "libjac_bridge_regex_v2.so",
    ):
        for build in ("release", "debug"):
            p = REPO / "bridges" / "target" / build / stem
            if p.is_file():
                out.append(p)
                break
    return out


SOS = _built_sos()
if not SOS:
    pytest.skip(
        "no bridge .so built (run: cargo build --release)",
        allow_module_level=True,
    )


def _ids(sos: list[Path]) -> list[str]:
    return [p.name for p in sos]


@pytest.mark.parametrize("so", SOS, ids=_ids(SOS))
def test_blob_parse_matches_reference(so: Path) -> None:
    """The .jac metadata parser yields the same structured fields as the reference."""
    blob = read_jac_bridge_section(str(so))
    ref = ref_parse(blob)
    got = jac_blob.parse(blob)
    assert got.abi_version == ref.abi_version
    assert got.module_name == ref.module_name
    assert [(t.index, t.kind, t.name, t.drop_sym) for t in got.types] == [
        (t.index, t.kind, t.name, t.drop_sym) for t in ref.types
    ]

    def fn_tuple(f: object) -> tuple:
        return (
            f.index,
            f.name,
            f.sym,
            f.self_type,
            f.kind,
            f.throws,
            f.ret,
            [(p.name, p.tag) for p in f.params],
        )

    assert [fn_tuple(f) for f in got.fns] == [fn_tuple(f) for f in ref.fns]


@pytest.mark.parametrize("so", SOS, ids=_ids(SOS))
def test_na_source_byte_identical(so: Path) -> None:
    """The na Jac-source generator emits byte-identical output on both paths."""
    blob = read_jac_bridge_section(str(so))
    ref = ref_render(ref_parse(blob), so.name)
    got = jac_synth.render_na_source(jac_blob.parse(blob), so.name)
    assert got.source == ref.source
    assert got.bridged == ref.bridged
    assert [(s.item, s.reason) for s in got.skips] == [
        (s.item, s.reason) for s in ref.skips
    ]


@pytest.mark.parametrize("so", SOS, ids=_ids(SOS))
def test_ctypes_module_structure_matches(so: Path) -> None:
    """The ctypes (CPython runtime) builder exposes the same surface on both paths."""
    blob = read_jac_bridge_section(str(so))
    ref_mod = ref_build_module(str(so), ref_parse(blob))
    got_mod = jac_ctypes.build_module(str(so), jac_blob.parse(blob))

    def surface(mod: object) -> dict:
        classes = {}
        for name in dir(mod):
            obj = getattr(mod, name)
            if isinstance(obj, type) and not issubclass(obj, Exception):
                methods = sorted(
                    m
                    for m in vars(obj)
                    if callable(vars(obj)[m]) and not m.startswith("__")
                )
                classes[name] = methods
        return classes

    assert surface(got_mod) == surface(ref_mod)
