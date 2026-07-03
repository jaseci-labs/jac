"""Sealed runtime image: manifest-trusted, source-free module loading.

A *sealed image* is a ``_precompiled/`` bundle promoted from "cache that must
justify itself against source" to "artifact trusted by construction": a
build-time ``MANIFEST.json`` maps module fullnames to precompiled JIR (full
compiler) and frozen ``.jbc`` (jac0 bootstrap) entries, so the runtime resolves
modules by *name* with no ``.jac`` sources on disk and no per-load source
re-hashing. Integrity comes from the payload's sha256 trailer at
materialization time; the extracted tree is immutable. See issue #7135
(#6852 Phase 4).

This module is **plain Python with no jaclang dependencies** (like the sibling
``cache_paths.py`` / ``ext_registry.py``) because the frozen-bootstrap path
must work before any ``.jac`` module -- including ``modresolver`` and the
compiler itself -- can load.

Manifest layout (``_precompiled/MANIFEST.json``, format 1)::

    {
      "format": 1,
      "package": "jaclang",
      "python_tag": "cpython-314",
      "jir_format_version": 13,
      "jaclang_version": "0.8.7",
      "modules": {                      # key: source path relative to pkg dir
        "compiler/program.jac": {
          "module": "jaclang.compiler.program",
          "jir": "compiler/program.jir",   # relative to _precompiled/<tag>/
          "package": false,
          "sha256": "..."                  # build-time audit; not re-checked
        }, ...
      },
      "bootstrap": {                    # key: module fullname (jac0 layer)
        "jaclang.jac0core.modresolver": {
          "path": "bootstrap/jac0core.modresolver.jbc",  # rel. _precompiled/
          "src": "jac0core/modresolver.jac",
          "sha256": "..."
        }, ...
      }
    }

Fail-closed rules: a manifest whose ``python_tag`` / ``jir_format_version``
mismatch the running interpreter raises instead of degrading to live
compilation; a sealed lookup miss for a module under a sealed package is an
ImportError at the caller, never a recompile.
"""

from __future__ import annotations

import json
import marshal
import os
import struct
import sys
import types
import zlib
from pathlib import Path

from jaclang.jac0core import ext_registry

MANIFEST_NAME = "MANIFEST.json"
MANIFEST_FORMAT = 1
# Must match jaclang.jac0core.jir.* ; kept literal here because this module
# must import before any .jac module (including jir.jac) can.
PRECOMPILE_SENTINEL = "__PKG_ROOT__"
JIR_FORMAT_VERSION = 13
_HEADER_SIZE = 32
_SECTIONS_MAGIC = b"JIRX"
_SEC_DEBUG_SRC = 0x09
_SEC_TERMINATOR = 0xFF


def _read_debug_section(data: bytes) -> str | None:
    """Extract the zlib'd SEC_DEBUG_SRC section from JIR bytes (pure-Python
    twin of ``jir.read_debug_source``, usable during bootstrap)."""
    try:
        pos = data.find(_SECTIONS_MAGIC, _HEADER_SIZE)
        if pos < 0:
            return None
        pos += len(_SECTIONS_MAGIC)
        while pos < len(data):
            sec_type = data[pos]
            pos += 1
            if sec_type == _SEC_TERMINATOR or pos + 4 > len(data):
                break
            (sec_len,) = struct.unpack_from("<I", data, pos)
            pos += 4
            if pos + sec_len > len(data):
                break
            if sec_type == _SEC_DEBUG_SRC:
                return zlib.decompress(data[pos : pos + sec_len]).decode("utf-8")
            pos += sec_len
    except Exception:
        return None
    return None


def python_tag() -> str:
    """Return the running interpreter's tag, e.g. ``cpython-314``."""
    return f"cpython-{sys.version_info.major}{sys.version_info.minor}"


def _patch_code_filenames(code: types.CodeType, find: str, replace: str) -> types.CodeType:
    """Recursively rewrite ``co_filename`` (pure-Python twin of
    ``jac0core.compiler.patch_co_filenames_bytes``, which is itself a .jac
    module and therefore unavailable while bootstrapping)."""
    consts = tuple(
        _patch_code_filenames(c, find, replace) if isinstance(c, types.CodeType) else c
        for c in code.co_consts
    )
    return code.replace(
        co_filename=code.co_filename.replace(find, replace), co_consts=consts
    )


class SealedImage:
    """One sealed ``_precompiled`` bundle: manifest + name-keyed module index."""

    def __init__(self, precompiled_dir: Path, manifest: dict) -> None:
        self.precompiled_dir = precompiled_dir
        self.pkg_dir = precompiled_dir.parent
        self.manifest = manifest
        self.package: str = manifest.get("package", "")
        self.jir_dir = precompiled_dir / manifest.get("python_tag", python_tag())
        # fullname -> ("jir" | "bootstrap", entry, src_relpath)
        self.index: dict[str, tuple[str, dict, str]] = {}
        self._build_index()

    def _build_index(self) -> None:
        # MODULE_SUFFIXES precedence: when foo.jac and foo.cl.jac both map to
        # one fullname, earlier (shorter) suffixes win -- same rule the
        # filesystem finder applies. Process in precedence-sorted order and
        # keep first.
        def precedence(src: str) -> tuple[int, str]:
            name = os.path.basename(src)
            for i, init in enumerate(ext_registry.INIT_FILES):
                if name == init:
                    return (i, src)
            suf = ext_registry.match_module_suffix(name)
            try:
                rank = ext_registry.MODULE_SUFFIXES.index(suf)
            except ValueError:
                rank = len(ext_registry.MODULE_SUFFIXES)
            return (rank, src)

        modules: dict[str, dict] = self.manifest.get("modules", {})
        for src in sorted(modules, key=precedence):
            entry = modules[src]
            fullname = entry.get("module")
            if fullname and fullname not in self.index:
                self.index[fullname] = ("jir", entry, src)
        for fullname, entry in self.manifest.get("bootstrap", {}).items():
            # Bootstrap wins over any full-compiler jir for the same name:
            # the jac0 layer must never route through the full compiler.
            self.index[fullname] = ("bootstrap", entry, entry.get("src", ""))

    def find(self, fullname: str) -> tuple[str, dict, str] | None:
        """Return ``(kind, entry, src_relpath)`` for a sealed module, or None."""
        return self.index.get(fullname)

    def owns(self, fullname: str) -> bool:
        """True when ``fullname`` falls under this image's package namespace."""
        return fullname == self.package or fullname.startswith(self.package + ".")

    def virtual_origin(self, src_relpath: str) -> str:
        """The path the module *would* have if sources were shipped. Used for
        ``__file__`` / ``co_filename`` continuity; the file need not exist."""
        return str(self.pkg_dir / src_relpath)

    def jir_path(self, entry: dict) -> Path:
        return self.jir_dir / entry["jir"]

    def jir_bytes(self, fullname: str) -> bytes | None:
        found = self.find(fullname)
        if found is None or found[0] != "jir":
            return None
        return self.jir_path(found[1]).read_bytes()

    def debug_source(self, fullname: str) -> str | None:
        """Source text from a sealed JIR's optional debug section, or None.

        Present only in ``--debug-src`` (dev) sealed images; release images
        strip it. Used by the loader's ``get_source`` so ``linecache`` can show
        real source lines in tracebacks without shipping ``.jac`` files.
        """
        found = self.find(fullname)
        if found is None or found[0] != "jir":
            return None
        try:
            data = self.jir_path(found[1]).read_bytes()
        except OSError:
            return None
        return _read_debug_section(data)

    def bootstrap_code(self, fullname: str) -> types.CodeType | None:
        found = self.find(fullname)
        if found is None or found[0] != "bootstrap":
            return None
        raw = (self.precompiled_dir / found[1]["path"]).read_bytes()
        code = marshal.loads(raw)  # noqa: S302 -- trusted sealed artifact
        return _patch_code_filenames(code, PRECOMPILE_SENTINEL, str(self.pkg_dir))


def load_image(precompiled_dir: str | Path) -> SealedImage | None:
    """Load and validate a sealed image; None when no manifest is present.

    Raises RuntimeError (fail-closed) when a manifest exists but targets a
    different interpreter or JIR format -- silently ignoring it would degrade
    to live compilation of a source-free tree.
    """
    pdir = Path(precompiled_dir)
    manifest_path = pdir / MANIFEST_NAME
    try:
        raw = manifest_path.read_bytes()
    except OSError:
        return None
    manifest = json.loads(raw)
    if manifest.get("format") != MANIFEST_FORMAT:
        raise RuntimeError(
            f"sealed image {manifest_path}: unsupported manifest format "
            f"{manifest.get('format')!r} (runtime supports {MANIFEST_FORMAT})"
        )
    tag = manifest.get("python_tag")
    if tag != python_tag():
        raise RuntimeError(
            f"sealed image {manifest_path}: built for {tag}, "
            f"running {python_tag()}"
        )
    if manifest.get("jir_format_version") != JIR_FORMAT_VERSION:
        raise RuntimeError(
            f"sealed image {manifest_path}: JIR format "
            f"{manifest.get('jir_format_version')} != {JIR_FORMAT_VERSION}"
        )
    return SealedImage(pdir, manifest)


# ---------------------------------------------------------------------------
# Image registry. The jaclang image is discovered lazily from the package
# location; app images (sealed user bundles, #7135 phase G) register
# explicitly via register_image().
# ---------------------------------------------------------------------------
_images: list[SealedImage] = []
_jaclang_probed = False


def _jaclang_image() -> SealedImage | None:
    global _jaclang_probed
    if not _jaclang_probed:
        _jaclang_probed = True
        pkg_dir = Path(__file__).resolve().parent.parent
        image = load_image(pkg_dir / "_precompiled")
        if image is not None:
            _images.insert(0, image)
    for img in _images:
        if img.package == "jaclang":
            return img
    return None


def register_image(precompiled_dir: str | Path) -> SealedImage | None:
    """Register an additional sealed image (e.g. a sealed user app)."""
    image = load_image(precompiled_dir)
    if image is not None:
        _images.append(image)
    return image


def is_sealed() -> bool:
    """True when jaclang itself runs from a sealed image."""
    return _jaclang_image() is not None


def find_module(fullname: str) -> tuple[SealedImage, str, dict, str] | None:
    """Resolve ``fullname`` across all sealed images.

    Returns ``(image, kind, entry, src_relpath)`` or None.
    """
    _jaclang_image()  # ensure lazy probe ran
    for img in _images:
        found = img.find(fullname)
        if found is not None:
            return (img, *found)
    return None


def source_for(fullname: str) -> str | None:
    """Debug source text for a sealed module across all images, or None."""
    found = find_module(fullname)
    if found is None:
        return None
    return found[0].debug_source(fullname)


def owner_image(fullname: str) -> SealedImage | None:
    """The sealed image whose package namespace covers ``fullname``, if any."""
    _jaclang_image()
    for img in _images:
        if img.owns(fullname):
            return img
    return None


def image_for_bundle_dir(bundle_dir: str | Path) -> SealedImage | None:
    """Map a ``_precompiled`` directory back to its loaded sealed image.

    Used by the compiler's precompiled-bundle lookup to decide between
    manifest trust (sealed) and source re-hash validation (unsealed cache).
    """
    _jaclang_image()
    resolved = Path(bundle_dir).resolve()
    for img in _images:
        if img.precompiled_dir.resolve() == resolved:
            return img
    return None
