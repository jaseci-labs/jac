"""Sealed runtime image: manifest-trusted JIR module loading.

A *sealed image* is a ``_precompiled/`` bundle promoted from "cache that must
justify itself against source" to "artifact trusted by construction": a
build-time ``MANIFEST.json`` maps module fullnames to precompiled JIR, so the
runtime resolves modules by *name* with no per-load source re-hashing. The
``.jac`` sources ship alongside the JIRs -- for tracebacks, ``inspect``, and
as fallback when a JIR is unreadable -- but a sealed load never consults them.
Integrity: images explicitly registered via ``register_image`` are hash-checked
against the manifest at registration; the jaclang image inside a single binary
is covered by the payload's sha256 trailer at materialization time instead.
See issue #7135 (#6852 Phase 4).

Both compile tiers share ONE JIR container and ONE manifest tree. Full-compiler
modules carry a normal JIR; jac0-compiled bootstrap modules (jac0core/*, which
the full compiler depends on and whose JIR reader is itself a jac0core module)
carry a JIR flagged ``"bootstrap": true`` and are loaded by ``bootstrap_code``
via the pure-Python section reader below -- no ``.jac`` machinery, so the tier
works before any ``.jac`` (including ``modresolver`` / ``jir`` / the compiler)
can load. jac0 stays the compiler for that tier; only the container is unified.

This module is therefore **plain Python with no jaclang dependencies** (like the
sibling ``cache_paths.py`` / ``ext_registry.py``).

Manifest layout (``_precompiled/MANIFEST.json``, format 3; format 2 = the
same without kind/capabilities/entry/payloads and remains loadable)::

    {
      "format": 3,
      "kind": "web-app",                # optional: project kind (app images)
      "capabilities": ["has-entry", "has-server", "has-client"],  # optional
      "entry": {"module": "app.main", "path": "main.jac"},        # optional
      "package": "jaclang",
      "python_tag": "cpython-314",
      "jir_format_version": 13,
      "jaclang_version": "0.8.7",
      "modules": {                      # key: source path relative to pkg dir
        "compiler/program.jac": {
          "module": "jaclang.compiler.program",
          "jir": "compiler/program.jir",   # relative to _precompiled/<tag>/
          "package": false,
          "sha256": "..."                  # checked by register_image
        },
        "jac0core/modresolver.jac": {
          "module": "jaclang.jac0core.modresolver",
          "jir": "jac0core/modresolver.jir",
          "package": false,
          "sha256": "...",
          "bootstrap": true                # jac0 tier; load via bootstrap_code
        }, ...
      },
      "payloads": {                     # optional non-module payloads, baked at
        ".jac/serve_manifest.json": "...",   # bundle time; key: pkg-relative
        ".jac/client/dist/client.abc.js": "..."  # posix path, value: sha256
      }
    }

Fail-closed rules: a manifest whose ``python_tag`` / ``jir_format_version``
mismatch the running interpreter raises instead of degrading to live
compilation; a sealed lookup miss for a module under a sealed package is an
ImportError at the caller, never a recompile.
"""

from __future__ import annotations

import hashlib
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
MANIFEST_FORMAT = 3
# Format 3 adds optional app metadata (kind / capabilities / entry) and
# payloads on top of format 2's module map; format-2 images stay loadable.
MANIFEST_FORMATS_ACCEPTED = (2, MANIFEST_FORMAT)
# Must match jaclang.jac0core.jir.* ; kept literal here because this module
# must import before any .jac module (including jir.jac) can. This is the whole
# point of the bootstrap tier: jac0core modules are loaded from their JIR by the
# pure-Python section reader below, so they need none of the .jac machinery
# (jir.jac's reader is itself a jac0core module).
PRECOMPILE_SENTINEL = "__PKG_ROOT__"
JIR_FORMAT_VERSION = 16
_HEADER_SIZE = 32
_SECTIONS_MAGIC = b"JIRX"
_SEC_BYTECODE = 0x02
_SEC_DEBUG_SRC = 0x09
_SEC_TERMINATOR = 0xFF


def _read_section(data: bytes, want: int) -> bytes | None:
    """Return the raw bytes of JIR section ``want``, or None. Pure-Python twin of
    ``jir.read_sections`` usable during bootstrap (before any .jac can load)."""
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
            if sec_type == want:
                return data[pos : pos + sec_len]
            pos += sec_len
    except Exception:
        return None
    return None


def python_tag() -> str:
    """Return the running interpreter's tag, e.g. ``cpython-314``."""
    return f"cpython-{sys.version_info.major}{sys.version_info.minor}"


def _patch_code_filenames(
    code: types.CodeType, find: str, replace: str
) -> types.CodeType:
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
        # Optional non-module payloads baked into the image (prebuilt client
        # dist, serve manifest, ...): pkg-relative posix path -> sha256.
        self.payloads: dict[str, str] = manifest.get("payloads") or {}
        # Optional app metadata (format 3): what this artifact IS, so a
        # downloaded bundle dispatches with no project config present.
        self.kind: str = manifest.get("kind", "")
        self.capabilities: list[str] = manifest.get("capabilities") or []
        self.entry: dict = manifest.get("entry") or {}
        # fullname -> (entry, src_relpath). One tree: full-compiler modules and
        # jac0-compiled bootstrap modules share the JIR container + manifest;
        # ``entry["bootstrap"]`` flags the jac0 tier (loaded via bootstrap_code).
        self.index: dict[str, tuple[dict, str]] = {}
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
                self.index[fullname] = (entry, src)

    def find(self, fullname: str) -> tuple[dict, str] | None:
        """Return ``(entry, src_relpath)`` for a sealed module, or None."""
        return self.index.get(fullname)

    def virtual_origin(self, src_relpath: str) -> str:
        """The path the module *would* have if sources were shipped. Used for
        ``__file__`` / ``co_filename`` continuity; the file need not exist."""
        return str(self.pkg_dir / src_relpath)

    def jir_path(self, entry: dict) -> Path:
        return self.jir_dir / entry["jir"]

    def _jir_bytes(self, fullname: str) -> bytes | None:
        found = self.index.get(fullname)
        if found is None:
            return None
        try:
            return self.jir_path(found[0]).read_bytes()
        except OSError:
            return None

    def debug_source(self, fullname: str) -> str | None:
        """Source text from a sealed JIR's optional debug section, or None.

        Present only in ``--debug-src`` (dev) sealed images; release images
        strip it. Used by the loader's ``get_source`` so ``linecache`` can show
        real source lines in tracebacks without shipping ``.jac`` files.
        """
        data = self._jir_bytes(fullname)
        if data is None:
            return None
        sec = _read_section(data, _SEC_DEBUG_SRC)
        return zlib.decompress(sec).decode("utf-8") if sec is not None else None

    def verify(self) -> None:
        """Hash every indexed JIR against its manifest ``sha256`` (fail-closed).

        Run for explicitly registered images, whose bytes have no other
        integrity cover; the jaclang image inside a single binary skips this
        because the payload's sha256 trailer already covers the whole tree.
        """
        for entry, _src in self.index.values():
            path = self.jir_path(entry)
            try:
                digest = hashlib.sha256(path.read_bytes()).hexdigest()
            except OSError as exc:
                raise RuntimeError(f"sealed image: cannot read {path}: {exc}") from exc
            if digest != entry.get("sha256"):
                raise RuntimeError(
                    f"sealed image: {path} does not match its manifest sha256"
                )
        for rel, want in self.payloads.items():
            if os.path.isabs(rel) or ".." in Path(rel).parts:
                raise RuntimeError(f"sealed image: illegal payload path {rel!r}")
            path = self.pkg_dir / rel
            try:
                digest = hashlib.sha256(path.read_bytes()).hexdigest()
            except OSError as exc:
                raise RuntimeError(f"sealed image: cannot read {path}: {exc}") from exc
            if digest != want:
                raise RuntimeError(
                    f"sealed image: payload {path} does not match its manifest sha256"
                )

    def bootstrap_code(self, fullname: str) -> types.CodeType | None:
        """Code object for a bootstrap-tier module, extracted from its JIR's
        bytecode section by the pure-Python reader -- no jir.jac, no running
        jaclang. This is what makes the jac0core layer loadable at boot."""
        found = self.index.get(fullname)
        if found is None or not found[0].get("bootstrap"):
            return None
        data = self._jir_bytes(fullname)
        if data is None:
            return None
        raw = _read_section(data, _SEC_BYTECODE)
        if raw is None:
            return None
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
    if manifest.get("format") not in MANIFEST_FORMATS_ACCEPTED:
        raise RuntimeError(
            f"sealed image {manifest_path}: unsupported manifest format "
            f"{manifest.get('format')!r} (runtime supports "
            f"{MANIFEST_FORMATS_ACCEPTED})"
        )
    tag = manifest.get("python_tag")
    if tag != python_tag():
        raise RuntimeError(
            f"sealed image {manifest_path}: built for {tag}, running {python_tag()}"
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
        # JAC_NO_SEAL disables sealed loading so jaclang runs from source. It is
        # set while BUILDING the seal: the staged jaclang imports itself to run
        # the precompiler, and must not sealed-load the very manifest it is about
        # to (re)generate -- which may still be an older/incompatible format.
        if not os.environ.get("JAC_NO_SEAL"):
            pkg_dir = Path(__file__).resolve().parent.parent
            image = load_image(pkg_dir / "_precompiled")
            if image is not None:
                _images.insert(0, image)
    for img in _images:
        if img.package == "jaclang":
            return img
    return None


def register_image(precompiled_dir: str | Path) -> SealedImage | None:
    """Register an additional sealed image (e.g. a sealed user app).

    The image's JIRs are hash-verified against the manifest before any of them
    can be loaded; a tampered or corrupted JIR raises rather than reaching
    ``marshal.loads``.
    """
    image = load_image(precompiled_dir)
    if image is not None:
        image.verify()
        _images.append(image)
    return image


def find_module(fullname: str) -> tuple[SealedImage, dict, str] | None:
    """Resolve ``fullname`` across all sealed images.

    Returns ``(image, entry, src_relpath)`` or None.
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
