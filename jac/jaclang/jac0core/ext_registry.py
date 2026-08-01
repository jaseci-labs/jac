"""Canonical Jac file-extension / module-resolution registry.

Single source of truth for what a filename *suffix means*: its language,
whether it is an annex (impl / test), the package ``__init__`` variants, and
the longest-suffix matching rule that makes ``.impl.jac`` and ``.test.jac``
outrank ``.jac``. Codespaces are never spelled in filenames. Before
this module that knowledge was re-derived in ~30 places as copy-pasted suffix
tuples and hand-rolled ``endswith`` precedence chains (see issue #6858).

This is **plain Python with no jaclang dependencies** so the pre-runtime
bootstrap (``_jac_finder.py``, ``jac0.py``, ``meta_importer.py``) can import it,
exactly like the sibling ``cache_paths.py``. Jac code consumes it as a normal
``.py`` import::

    import from jaclang.jac0core.ext_registry { base_stem, is_annex }
"""

from __future__ import annotations

import os

# ---------------------------------------------------------------------------
# Canonical suffix constants
# ---------------------------------------------------------------------------
JAC_SUFFIX = ".jac"
IMPL_SUFFIX = ".impl.jac"
TEST_SUFFIX = ".test.jac"

# The retired codespace markers: placement is inferred (or pinned/forced),
# never spelled in the filename. Kept only so the migration diagnostics can
# name what they found.
RETIRED_NATIVE_SUFFIX = ".na.jac"
RETIRED_CLIENT_SUFFIX = ".cl.jac"

# Codespace name constants.
SERVER = "server"
CLIENT = "client"
NATIVE = "native"

# Annex suffixes and the per-module folder each annex groups under.
ANNEX_SUFFIXES = (IMPL_SUFFIX, TEST_SUFFIX)
ANNEX_FOLDER = {IMPL_SUFFIX: ".impl", TEST_SUFFIX: ".test"}
# Folder-name suffixes that mark a module-scoped annex directory (``foo.impl/``).

# Every Jac *module* file shape the importer / finder probe, precedence order.
MODULE_SUFFIXES = (JAC_SUFFIX,)
# Package ``__init__`` variants, precedence order.
INIT_FILES = ("__init__.jac",)

# Stem suffixes stripped when re-keying MTIR entries in the importer.
STEM_REKEY_SUFFIXES = (".impl",)

# Language base extensions, longest first, used by ``base_stem`` /
# ``language_of``.
_PY_SUFFIXES = (".pyi", ".py")
_JS_SUFFIXES = (".jsx", ".tsx", ".js", ".ts")


# ---------------------------------------------------------------------------
# Longest-suffix matching — the single shared precedence rule
# ---------------------------------------------------------------------------
def base_stem(filename: str) -> str:
    """Return ``filename``'s basename minus its full recognized suffix.

    This is the one shared longest-suffix matcher that replaces every
    hand-rolled ``endswith`` precedence chain. It strips the language base
    extension (``.jac`` / ``.py`` / ``.js`` family) and then any trailing
    annex stem components, so ``foo.impl.jac`` and ``foo.test.jac`` reduce to
    the bare module name ``foo``. A name with no recognized extension is
    returned unchanged.
    """
    name = os.path.basename(filename)
    base = ""
    if name.endswith(JAC_SUFFIX):
        base = JAC_SUFFIX
    else:
        for suf in _PY_SUFFIXES + _JS_SUFFIXES:
            if name.endswith(suf):
                base = suf
                break
    if not base:
        return name
    name = name[: -len(base)]
    if base != JAC_SUFFIX:
        # Python/JS files carry no annex stem components.
        return name
    changed = True
    while changed:
        changed = False
        for stem in (".impl", ".test"):
            if name.endswith(stem):
                name = name[: -len(stem)]
                changed = True
                break
    return name


def strip_suffix(path: str) -> str:
    """Return ``path`` with its recognized Jac/py/js suffix removed but the
    directory portion preserved (unlike ``base_stem``, which also drops the
    directory). ``/a/b/foo.test.jac`` -> ``/a/b/foo``; a path with no
    recognized suffix is returned unchanged.
    """
    name = os.path.basename(path)
    stem = base_stem(name)
    removed = len(name) - len(stem)
    if removed <= 0:
        return path
    return path[:-removed]


def match_module_suffix(filename: str) -> str | None:
    """Return the longest ``MODULE_SUFFIXES`` entry ``filename`` ends with.

    Returns None when the file is not a Jac module file (annexes are not
    module suffixes).
    """
    best = None
    for suf in MODULE_SUFFIXES:
        if filename.endswith(suf) and (best is None or len(suf) > len(best)):
            best = suf
    return best


# ---------------------------------------------------------------------------
# Language classification
# ---------------------------------------------------------------------------
def is_jac(path: str) -> bool:
    """True for any Jac file (plain, codespace variant, or annex)."""
    return path.endswith(JAC_SUFFIX)


def is_python(path: str) -> bool:
    """True for ``.py`` / ``.pyi`` files."""
    return path.endswith(_PY_SUFFIXES)


def language_of(path: str) -> str:
    """Classify ``path`` as ``'jac'`` / ``'pyi'`` / ``'py'`` / ``'js'`` / ``'other'``."""
    if path.endswith(JAC_SUFFIX):
        return "jac"
    if path.endswith(".pyi"):
        return "pyi"
    if path.endswith(".py"):
        return "py"
    if path.endswith(_JS_SUFFIXES):
        return "js"
    return "other"


# ---------------------------------------------------------------------------
# Codespace classification
# ---------------------------------------------------------------------------
def is_retired_native_marker(path: str) -> bool:
    """True for a file still carrying the retired ``.na.jac`` marker.

    Exists solely to power the migration diagnostic; nothing resolves or
    classifies through this.
    """
    return path.endswith(RETIRED_NATIVE_SUFFIX) or path.endswith(".na.impl.jac")


def is_retired_client_marker(path: str) -> bool:
    """True for a file still carrying the retired ``.cl.jac`` marker.

    Exists solely to power the migration diagnostic; nothing resolves or
    classifies through this.
    """
    return path.endswith(RETIRED_CLIENT_SUFFIX) or path.endswith(".cl.impl.jac")


def is_server_module(path: str) -> bool:
    """True for a Jac module file that is not an impl annex.

    Placement is a compile-time decision, never a filename property; this
    only distinguishes module files from ``.impl.jac`` annexes.
    """
    return path.endswith(JAC_SUFFIX) and not path.endswith(IMPL_SUFFIX)


# ---------------------------------------------------------------------------
# Annex classification
# ---------------------------------------------------------------------------
def is_annex(path: str) -> bool:
    """True for an ``.impl.jac`` or ``.test.jac`` annex file."""
    return path.endswith(ANNEX_SUFFIXES)


def is_impl(path: str) -> bool:
    """True for an ``.impl.jac`` annex file."""
    return path.endswith(IMPL_SUFFIX)


def is_test(path: str) -> bool:
    """True for a ``.test.jac`` test annex file."""
    return path.endswith(TEST_SUFFIX)


# Tool-owned directory names that never hold importable Jac source; pruned from
# the namespace-package subtree walk (dot-prefixed dirs -- .git, .venv, .jac --
# are pruned by the leading-dot rule below).
_WALK_SKIP_DIRS = frozenset({"__pycache__", "node_modules"})


def _subtree_has_jac(directory: str) -> bool:
    """True if a ``.jac`` source exists in *directory* or below (early-exit).

    Each directory's own files are inspected before descending, so a leaf
    package whose ``.jac`` files sit right there returns without recursing.
    Unreadable directories are skipped, subdirectories are not followed through
    symlinks (which avoids symlink cycles), and tool-owned trees that never hold
    Jac source (``__pycache__``, ``node_modules``, dot-directories) are pruned to
    bound the walk in deep project trees.
    """
    stack = [directory]
    while stack:
        try:
            scan = os.scandir(stack.pop())
        except OSError:
            continue
        with scan:
            subdirs: list[str] = []
            for entry in scan:
                try:
                    if entry.is_dir(follow_symlinks=False):
                        name = entry.name
                        if not name.startswith(".") and name not in _WALK_SKIP_DIRS:
                            subdirs.append(entry.path)
                    elif entry.is_file() and is_jac(entry.name):
                        return True
                except OSError:
                    continue
            stack.extend(subdirs)
    return False


def is_jac_namespace_package(directory: str) -> bool:
    """True when *directory* is an implicit Jac namespace package (PEP 420).

    A namespace package has no ``__init__`` of any kind, yet belongs to Jac
    because a ``.jac`` source lives somewhere in its subtree. This is what lets
    Python's per-component import machinery descend through an *intermediate*
    package: in ``import from engine.math.vec3 { ... }`` the directory
    ``engine/`` may hold only the ``math/`` subpackage and no ``.jac`` file of
    its own, but must still be claimed so ``import engine`` succeeds -- mirroring
    how ``modresolver`` joins the whole dotted path against a search root in one
    shot (the native runner's path). A directory that is a regular package
    (any ``__init__``) or whose subtree holds no Jac source is left to Python's
    own ``PathFinder`` (issue #7211).
    """
    if os.path.isfile(os.path.join(directory, "__init__.py")):
        return False
    for init_name in INIT_FILES:
        if os.path.isfile(os.path.join(directory, init_name)):
            return False
    return _subtree_has_jac(directory)
