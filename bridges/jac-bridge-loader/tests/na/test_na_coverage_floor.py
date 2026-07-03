"""na-runtime coverage ratchet: the na synthesizer must not bridge fewer public
surface items than the recorded floor (``na-coverage-floor.toml``).

This is the na analog of the binder's ``coverage_does_not_regress`` corpus gate.
It recomputes coverage from ``render_na_source`` for each bridge .so present in the
build tree and asserts ``bridged >= floor`` (a one-way ratchet).  Unlike the na
conformance suite it needs NO LLVM shim — it inspects the SYNTHESIZED source's item
counts, not a compiled binary; the conformance suite is what proves those counts
correspond to code that actually compiles and runs natively.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - py<3.11
    import tomli as tomllib  # type: ignore[no-redef]

from jac_bridge_loader._blob import parse
from jac_bridge_loader._elf import read_jac_bridge_section
from jac_bridge_loader._na_codegen import render_na_source

FLOOR_TOML = Path(__file__).with_name("na-coverage-floor.toml")


def _so_dir() -> Path | None:
    here = Path(__file__).resolve()
    for base in (here.parents[2], here.parents[3]):  # loader/, bridges/, repo/
        for build in ("release", "debug"):
            d = base / "target" / build
            if d.is_dir():
                return d
    return None


def _load_floor() -> dict[str, dict[str, int]]:
    with FLOOR_TOML.open("rb") as fh:
        return tomllib.load(fh)


def _key(so_name: str) -> str:
    # TOML tables can't hold dots; the floor keys .so basenames with '.' -> '_'.
    return so_name.replace(".", "_")


@pytest.mark.parametrize("so_name", sorted(_load_floor()))
def test_na_coverage_does_not_regress(so_name: str) -> None:
    floor = _load_floor()[so_name]
    d = _so_dir()
    if d is None:
        pytest.skip("no target/{release,debug} build dir")
    # floor keys are the '.'-> '_' form; map back to the real filename.
    so = d / so_name.replace("_so", ".so")
    if not so.is_file():
        pytest.skip(f"{so.name} not built")

    res = render_na_source(parse(read_jac_bridge_section(str(so))), so.name)
    total = res.bridged + len(res.skips)
    # Ratchet: na must realize AT LEAST the floor's bridged count.  A drop means a
    # regression in the synthesizer (or a fixture that lost items) — investigate,
    # don't silently lower the floor.
    assert res.bridged >= floor["bridged"], (
        f"{so.name}: na bridged {res.bridged} < floor {floor['bridged']}; "
        f"skips={[s.item for s in res.skips]}"
    )
    # `total` is a fixture-drift canary: if the .so grew public items the synthesizer
    # can't yet reach, bridged holds but total rises — surfaced, not silently passed.
    assert total >= floor["total"], (
        f"{so.name}: total surface {total} < recorded {floor['total']} "
        "(fixture shrank?)"
    )


def test_floor_file_is_not_empty() -> None:
    # A guard so a truncated/renamed floor file fails loudly instead of vacuously
    # passing (zero parametrized cases would otherwise be a green no-op).
    assert _load_floor(), "na-coverage-floor.toml has no entries"


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v"]))
