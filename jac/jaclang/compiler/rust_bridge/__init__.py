"""In-compiler Rust-bridge loader for the na (native/AOT) path.

One high-level entry point, ``synthesize_bridge(crate)``, ties together the three
ported pieces so the frontend import hook stays tiny:

    resolve ``rust.<crate>`` -> a compiled bridge ``.so``   (_finder)
    read the ``.jac_bridge`` D2 metadata section as bytes   (_elf)
    parse the blob, gate the ABI version                    (_blob)
    render golden-spike-shaped Jac source                   (_synth)

The library is never dlopen'd for its metadata (cross-compile safety, D2); the
section is parsed straight off disk.  Version skew is structurally impossible
(D5): the metadata travels inside the library it describes, so there is no
separate bindings file to drift.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from ._blob import BridgeMeta, parse
from ._elf import read_jac_bridge_section
from ._finder import find_bridge_lib
from ._synth import NaModule, Skip, render_na_source

SUPPORTED_ABI = 1

__all__ = [
    "SUPPORTED_ABI",
    "BridgeSynth",
    "synthesize_bridge",
    "materialize_bridge",
    "find_bridge_lib",
    "is_bridge_module",
    "RustBridgeFinder",
    "install_rust_namespace",
]


def __getattr__(name: str) -> Any:  # noqa: ANN401
    """Lazily re-export the CPython-runtime importer, which is a ``.jac`` module.

    Deferred on purpose to avoid a compile-time import cycle: compiling
    ``_importer.jac`` runs the ``BoundaryAnalysisPass`` over its imports, which
    calls ``codeinfo.is_bundled_native_module`` -> imports *this* package.  An
    eager ``from ._importer import ...`` at package load would re-enter
    ``_importer.jac`` mid-compile ("No bytecode found").  Loading it only on
    first attribute access breaks the cycle — by then this package's __init__ has
    completed and the Jac compiler is ready to compile the module.  The na path
    (synthesize/materialize/is_bridge_module) never touches ``_importer``.
    """
    if name in ("RustBridgeFinder", "install_rust_namespace"):
        from . import _importer

        return getattr(_importer, name)
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


# `import rust.<crate>` — exactly two dotted segments, first is "rust".
_PREFIX = "rust."


def is_bridge_module(module_name: str) -> bool:
    """True iff ``module_name`` is a ``rust.<crate>`` bridge import."""
    clean = module_name.lstrip(".")
    return clean.startswith(_PREFIX) and clean.count(".") == 1


def _crate_of(module_name: str) -> str | None:
    if not is_bridge_module(module_name):
        return None
    return module_name.lstrip(".")[len(_PREFIX) :]


def _gen_root() -> Path:
    """Compiler-managed cache dir for synthesized bridge modules.

    A build artifact (like the ``.jir`` bytecode cache), not a user-authored
    bindings file — nothing here is maintained by hand or can drift from the
    library, since it is regenerated from the library's own metadata.
    """
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    return Path(base) / "jac" / "rust-bridges-gen"


@dataclass
class BridgeSynth:
    """Everything the import hook needs to inject a synthesized bridge module."""

    crate: str
    so_path: str  # absolute path to the resolved .so
    so_basename: str  # the NEEDED soname the synthesized source links
    source: str  # synthesized Jac source text
    meta: BridgeMeta
    skips: list[Skip] = field(default_factory=list)


def synthesize_bridge(
    crate: str, extra_dirs: list[str | Path] | None = None
) -> BridgeSynth | None:
    """Resolve ``rust.<crate>`` and synthesize its Jac source.

    Returns None if no bridge library is found for the crate (so the caller can
    fall through to normal import resolution / diagnostics).  Raises ImportError
    on an ABI-version mismatch — a found-but-incompatible bridge is a hard error,
    never a silent skip.
    """
    lib = find_bridge_lib(crate, extra_dirs)
    if lib is None:
        return None

    meta = parse(read_jac_bridge_section(str(lib)))
    if meta.abi_version != SUPPORTED_ABI:
        raise ImportError(
            f"rust.{crate}: bridge '{lib}' declares ABI version "
            f"{meta.abi_version}, but this jac supports v{SUPPORTED_ABI}. "
            "Rebuild the bridge or upgrade jac."
        )

    na: NaModule = render_na_source(meta, lib.name)
    return BridgeSynth(
        crate=crate,
        so_path=str(lib.resolve()),
        so_basename=lib.name,
        source=na.source,
        meta=meta,
        skips=na.skips,
    )


def materialize_bridge(
    module_name: str, extra_dirs: list[str | Path] | None = None
) -> str | None:
    """Synthesize ``rust.<crate>`` and write it to the cache as a real .na.jac.

    Returns the resolved absolute path, or None if ``module_name`` is not a
    bridge import or no bridge library is found.  Both the na compiler step (via
    ``codeinfo.resolve_native_module``) and the type-checker import hook go
    through this one function, so they agree on the module's identity: the same
    file path is the hub key on both paths, and the module is compiled once.

    The file is rewritten only when its content changes, so its mtime stays
    stable and the module-hub freshness check keeps hitting the cached module.
    """
    crate = _crate_of(module_name)
    if crate is None:
        return None
    synth = synthesize_bridge(crate, extra_dirs)
    if synth is None:
        return None

    out_dir = _gen_root()
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"{crate}.na.jac"
    if not out.is_file() or out.read_text(encoding="utf-8") != synth.source:
        tmp = out.with_name(f"{crate}.na.jac.{os.getpid()}.tmp")
        tmp.write_text(synth.source, encoding="utf-8")
        os.replace(tmp, out)
    return str(out.resolve())
