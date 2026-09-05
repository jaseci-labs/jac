"""The declared bootstrap (jac0) seed set.

Tier membership used to be a path test ("is the file under jac0core/?"),
which coupled *where a module lives* to *which compiler compiles it* and
let the bootstrap directory accrete everything the seed-visible code
touched. This manifest is now the single authority: a .jac file is
compiled by the jac0 seed transpiler (and flagged ``"bootstrap": true``
at seal time) iff it is covered here. Directory entries end with ``/``
and cover their whole subtree; file entries name one module. Paths are
POSIX-style, relative to the ``jaclang`` package directory.

This module must stay pure Python with no jaclang imports: the meta
importer consults it before any .jac module can load. CI checks that
every covered module actually compiles under jac0 and that no seed
module imports outside the seed set at module scope (a hoisted import
deadlocks bootstrap) -- see scripts/check_seed_manifest.py.

Moving a seed module is a two-line change: git mv the file, update its
entry here. Entries that do not exist on disk fail loudly at boot.
"""

from __future__ import annotations

import os

# Everything the jac0 tier compiles. Directory entries cover subtrees.
# compiler/passes/ and compiler/backends/ are deliberately listed file by
# file (or py/-subtree): their siblings (main/, ecmascript/, native/,
# tool/) are full-compiler modules and must never join the seed set by
# directory accident.
SEED_PATHS: tuple[str, ...] = (
    "compiler/frontend/",
    "compiler/driver/",
    "compiler/placement/",
    "compiler/backends/py/",
    "compiler/backends/fmt_kernel.jac",
    "compiler/passes/annex_weave.jac",
    "compiler/passes/ast_gen/",
    "compiler/passes/ast_validation_pass.jac",
    "compiler/passes/boundary_analysis_pass.jac",
    "compiler/passes/decl_impl_match_pass.jac",
    "compiler/passes/endpoint_effect_pass.jac",
    "compiler/passes/semantic_analysis_pass.jac",
    "compiler/passes/sym_tab_build_pass.jac",
    "compiler/passes/transform.jac",
    "compiler/native_scope.jac",
    "compiler/native_compiler.jac",
    "compiler/jc_unit.jac",
    "compiler/jc_materialize.jac",
    "compiler/passes/uni_pass.jac",
    "compiler/tools/treeprinter.jac",
    "runtime/runtime.jac",
    "runtime/archetype.jac",
    "runtime/constructs.jac",
    "runtime/graph_query.jac",
    "runtime/interop_bridge.jac",
    "runtime/traceback_render.jac",
    "runtime/debugger.jac",
    "runtime/portability.jac",
    "runtime/scalars.jac",
    "runtime/osp_kernel.jac",
    "runtime/osp_kernel_sv.jac",
    "runtime/osp_graph.jac",
    "runtime/osp_graph_sv.jac",
    "runtime/osp_model.jac",
    "runtime/osp_tag.jac",
    "lib/jaclib.jac",
    "compiler/driver/mtp.jac",
    "cli/cli_boot.jac",
    "jac0core/cli_boot.jac",
    "project/tomlio.jac",
)

# Modules with no bytecode meaning: they import C symbols (the kernel
# roots and the fused-binary shims) or live under the native standard
# library. The roster lives here, in the pure-Python tier, because the jac0
# sweep and the seed-manifest gate must skip them before any .jac module can
# load; `placement_facts.native_only` is the compiler's view of the same
# data and the only predicate the driver, the seal and the link plan
# consult. Tier stamping (is_seed_source) is unaffected.
NATIVE_ONLY_REL: tuple[str, ...] = (
    "compiler/jc_unit.jac",
    "compiler/jc_materialize.jac",
    "dist/fused/embed.jac",
    "dist/fused/_libc.jac",
)
NATIVE_ONLY_DIR_REL: tuple[str, ...] = ("runtime/na_stdlib",)


def is_native_only(rel_path: str) -> bool:
    """Whether a jaclang-package-relative POSIX path has no bytecode meaning."""
    if rel_path in NATIVE_ONLY_REL:
        return True
    return any(rel_path.startswith(d + "/") for d in NATIVE_ONLY_DIR_REL)


def seed_abs_entries(jaclang_dir: str) -> tuple[tuple[str, ...], frozenset[str]]:
    """Resolve the manifest against a jaclang package dir.

    Returns (dir_prefixes, file_paths): absolute directory prefixes (each
    ending in os.sep) and absolute file paths. Raises if an entry names
    nothing on disk, so a rename that forgets the manifest fails at boot
    instead of silently changing a module's tier.
    """
    dirs: list[str] = []
    files: set[str] = set()
    for entry in SEED_PATHS:
        native = entry.rstrip("/").replace("/", os.sep)
        full = os.path.join(jaclang_dir, native)
        if entry.endswith("/"):
            if not os.path.isdir(full):
                raise RuntimeError(
                    f"bootstrap_manifest: seed directory {entry!r} does not "
                    f"exist under {jaclang_dir}"
                )
            dirs.append(full + os.sep)
        else:
            if not os.path.isfile(full):
                raise RuntimeError(
                    f"bootstrap_manifest: seed module {entry!r} does not "
                    f"exist under {jaclang_dir}"
                )
            files.add(full)
    return tuple(dirs), frozenset(files)


def is_seed_source(rel_path: str) -> bool:
    """Whether a jaclang-package-relative POSIX path is in the seed set.

    This is the membership test the sealer uses to stamp ``"bootstrap":
    true`` on manifest entries, so the sealed image and the live tree
    agree on tier membership by construction.
    """
    for entry in SEED_PATHS:
        if entry.endswith("/"):
            if rel_path.startswith(entry):
                return True
        elif rel_path == entry:
            return True
    return False
