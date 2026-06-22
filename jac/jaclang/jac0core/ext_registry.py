"""Canonical Jac file-extension / module-resolution registry.

Single source of truth for what a filename *suffix means*: its language, its
codespace (server / client / native), whether it is an annex (impl / test), the
package ``__init__`` variants, and — most importantly — the longest-suffix
matching rule that makes ``.cl.jac`` outrank ``.jac`` and ``.na.impl.jac``
outrank ``.impl.jac``. Before this module that knowledge was re-derived in ~30
places as copy-pasted suffix tuples and hand-rolled ``endswith`` precedence
chains (see issue #6858).

This is **plain Python with no jaclang dependencies** so the pre-runtime
bootstrap (``_jac_finder.py``, ``jac0.py``, ``meta_importer.py``) can import it,
exactly like the sibling ``cache_paths.py``. Jac code consumes it as a normal
``.py`` import::

    import from jaclang.jac0core.ext_registry { is_native_module, base_stem }
"""

from __future__ import annotations

import os

# ---------------------------------------------------------------------------
# Canonical suffix constants
# ---------------------------------------------------------------------------
JAC_SUFFIX = ".jac"
SERVER_SUFFIX = ".sv.jac"
CLIENT_SUFFIX = ".cl.jac"
NATIVE_SUFFIX = ".na.jac"
IMPL_SUFFIX = ".impl.jac"
TEST_SUFFIX = ".test.jac"
STYLE_SUFFIX = ".style.css"

# Codespace name constants (returned by ``codespace_of``).
SERVER = "server"
CLIENT = "client"
NATIVE = "native"

# Codespace variant suffixes, in canonical longest-precedence order. Mirrors
# the former ``bccache._VARIANT_SUFFIXES``.
VARIANT_SUFFIXES = (SERVER_SUFFIX, CLIENT_SUFFIX, NATIVE_SUFFIX)
# Post-``.jac``-strip stem forms of the variants (".sv", ".cl", ".na").
VARIANT_STEM_SUFFIXES = (".sv", ".cl", ".na")
# Annex suffixes and the per-module folder each annex groups under.
ANNEX_SUFFIXES = (IMPL_SUFFIX, TEST_SUFFIX)
ANNEX_FOLDER = {IMPL_SUFFIX: ".impl", TEST_SUFFIX: ".test"}
# Folder-name suffixes that mark a module-scoped annex directory (``foo.impl/``).
ANNEX_FOLDER_SUFFIXES = (".impl", ".test")

# Every Jac *module* file shape the importer / finder probe, precedence order.
MODULE_SUFFIXES = (JAC_SUFFIX, SERVER_SUFFIX, CLIENT_SUFFIX, NATIVE_SUFFIX)
# Package ``__init__`` variants, precedence order.
INIT_FILES = ("__init__.jac", "__init__.sv.jac", "__init__.cl.jac")

# Variant suffix -> codespace name. Plain ``.jac`` is intentionally absent: it
# has no *explicit* codespace, so ``codespace_of`` returns None for it and the
# compiler applies no coercion (matching the historical elif-chain default).
_VARIANT_CODESPACE = {
    SERVER_SUFFIX: SERVER,
    CLIENT_SUFFIX: CLIENT,
    NATIVE_SUFFIX: NATIVE,
}

# Stem suffixes stripped when re-keying MTIR entries in the importer. Native
# (".na") is intentionally excluded to preserve the historical key shape; see
# ``meta_importer.exec_module``.
STEM_REKEY_SUFFIXES = (".impl", ".cl", ".sv")

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
    codespace/annex stem components, so ``foo.cl.jac``, ``foo.na.impl.jac`` and
    ``foo.test.cl.jac`` all reduce to the bare module name ``foo``. A name with
    no recognized extension is returned unchanged.
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
        # Python/JS files carry no codespace/annex stem components.
        return name
    changed = True
    while changed:
        changed = False
        for stem in (".impl", ".test") + VARIANT_STEM_SUFFIXES:
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

    Picks ``.cl.jac`` over ``.jac`` for ``x.cl.jac``. Returns None when the
    file is not a Jac module file (annexes included return their base ``.jac``
    via the longest match only if listed; annexes are not module suffixes).
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


def is_js(path: str) -> bool:
    """True for the ECMAScript family (``.js`` / ``.ts`` / ``.jsx`` / ``.tsx``)."""
    return path.endswith(_JS_SUFFIXES)


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
def codespace_of(path: str) -> str | None:
    """Return ``'server'`` / ``'client'`` / ``'native'`` for an *explicit*
    codespace variant file, else None (plain ``.jac``, annexes, non-Jac).

    This is the classifier the compiler's coercion dispatch keys on: plain
    ``.jac`` yields None so no coercion runs.
    """
    for suf in VARIANT_SUFFIXES:
        if path.endswith(suf):
            return _VARIANT_CODESPACE[suf]
    return None


def is_native_module(path: str) -> bool:
    """True for a ``.na.jac`` native-codespace module file."""
    return path.endswith(NATIVE_SUFFIX)


def is_client_module(path: str) -> bool:
    """True for a ``.cl.jac`` client-codespace module file."""
    return path.endswith(CLIENT_SUFFIX)


def is_server_module(path: str) -> bool:
    """True for a Jac module that lives in the server codespace.

    Server is the default codespace, so this is any ``.jac`` file that is not
    explicitly client (``.cl.jac``), native (``.na.jac``), or an impl annex
    (``.impl.jac``). Plain ``.jac``, ``.sv.jac`` and ``.test.jac`` all qualify.
    """
    return (
        path.endswith(JAC_SUFFIX)
        and not path.endswith(CLIENT_SUFFIX)
        and not path.endswith(NATIVE_SUFFIX)
        and not path.endswith(IMPL_SUFFIX)
    )


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


def is_client_test(path: str) -> bool:
    """True for a ``.test.cl.jac`` client test file."""
    return path.endswith(".test.cl.jac")
