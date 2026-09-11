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
# compiler/analysis/, compiler/lowering/, and compiler/backends/ are deliberately listed file by
# file (or py/-subtree): their siblings (backends/es/, backends/native/,
# backends/common/primitives.jac, the analysis passes) are full-compiler
# modules and must never join the seed set by directory accident.
SEED_PATHS: tuple[str, ...] = (
    "compiler/frontend/parser/",
    "compiler/frontend/diagnostics.jac",
    "compiler/frontend/diagnostic_utils.jac",
    "compiler/frontend/source_locations.jac",
    "compiler/frontend/source_io.jac",
    "compiler/pipeline/",
    "compiler/session/",
    "compiler/bootstrap/",
    "compiler/ir/",
    "build/",
    "compiler/analysis/placement/",
    "compiler/analysis/binding/context_pass.jac",
    "compiler/analysis/binding/bindings.jac",
    "compiler/analysis/binding/facts_pass.jac",
    "compiler/analysis/interfaces/facts.jac",
    "compiler/analysis/binding/absorb_pass.jac",
    "compiler/analysis/binding/imports_pass.jac",
    "compiler/analysis/binding/import_classification.jac",
    "compiler/analysis/binding/client_dependencies_pass.jac",
    "compiler/analysis/binding/facts.jac",
    "compiler/analysis/binding/module_facts.jac",
    "compiler/analysis/boundaries/facts_pass.jac",
    "compiler/analysis/boundaries/native_import_pass.jac",
    "compiler/analysis/boundaries/serving_pass.jac",
    "compiler/analysis/boundaries/facts.jac",
    "compiler/analysis/boundaries/classify.jac",
    "compiler/analysis/comptime/imports_pass.jac",
    "compiler/analysis/interfaces/interface_pass.jac",
    "compiler/backends/common/artifacts.jac",
    "compiler/backends/native/naming.jac",
    "compiler/backends/native/initialization.jac",
    "compiler/analysis/capabilities/native_policy.jac",
    "compiler/analysis/boundaries/identity.jac",
    "compiler/backends/common/artifact_store.jac",
    "compiler/api.jac",
    "compiler/backends/py/",
    "compiler/backends/common/ast_gen_base.jac",
    "compiler/backends/common/kernel_units.jac",
    "compiler/backends/common/fmt_kernel.jac",
    "compiler/frontend/annexes.jac",
    "compiler/analysis/binding/ast_validation_pass.jac",
    "compiler/lowering/graph_lowering_pass.jac",
    "compiler/analysis/boundaries/boundary_analysis_pass.jac",
    "compiler/analysis/binding/decl_impl_match_pass.jac",
    "compiler/analysis/boundaries/endpoint_effect_pass.jac",
    "compiler/analysis/binding/semantic_analysis_pass.jac",
    "compiler/analysis/binding/sym_tab_build_pass.jac",
    "compiler/pipeline/pass_base.jac",
    "compiler/bootstrap/native_scope.jac",
    "compiler/analysis/types/field_semantics.jac",
    "compiler/frontend/kernel/adapter.jac",
    "compiler/frontend/kernel/unit.jac",
    "compiler/frontend/kernel/materialize.jac",
    "compiler/pipeline/uni_pass.jac",
    "compiler/tools/treeprinter.jac",
    "runtime/runtime.jac",
    "runtime/object_model.jac",
    "runtime/object_interop.jac",
    "runtime/region.jac",
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
    "compiler/analysis/binding/osp_facts.jac",
    "compiler/analysis/binding/osp_model.jac",
    "runtime/osp_tag.jac",
    "lib/jaclib.jac",
    "compiler/lowering/mtir.jac",
    "cli/cli_boot.jac",
    "jac0core/cli_boot.jac",
    "project/__init__.jac",
    "project/tomlio.jac",
    "project/apps.jac",
    "project/app_kinds.jac",
)

# Modules that live under a seed directory but belong to the native
# toolchain tier: jac build --native --lib builds them into a shared library, and they
# never execute as bytecode (extern `import from c` declarations have no
# Python lowering). The jac0 sweep and the seed-manifest gate skip them;
# tier stamping (is_seed_source) is unaffected, which also keeps them out
# of the full-compiler seal sweep.
NATIVE_ONLY_SEEDS: tuple[str, ...] = (
    "compiler/frontend/kernel/unit.jac",
    "compiler/frontend/kernel/materialize.jac",
)


def is_native_only_seed(rel_path: str) -> bool:
    """Whether a jaclang-package-relative POSIX path is a native-tier unit
    that jac0 must not compile even though a seed directory covers it."""
    return rel_path in NATIVE_ONLY_SEEDS


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
