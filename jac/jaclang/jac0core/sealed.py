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

Manifest layout (``_precompiled/MANIFEST.json``, format 4; format 3 = the
same without native_artifacts, format 2 also without
kind/capabilities/entry/payloads -- both remain loadable)::

    {
      "format": 4,
      "kind": "web-app",                # optional: project kind (app images)
      "capabilities": ["has-entry", "has-server", "has-client"],  # optional
      "entry": {"module": "app.main", "path": "main.jac"},        # optional
      "package": "jaclang",
      "python_tag": "cpython-314",
      "jir_format_version": 13,
      "jaclang_version": "0.8.7",
      "compiler_digest": "409:9f2c...",  # optional: the compiler that built
                                         # this image (jir.compiler_source_digest;
                                         # informational -- the seal already
                                         # verified every JIR against it, see #8178)
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
MANIFEST_FORMAT = 6
# Format 3 adds optional app metadata (kind / capabilities / entry) and
# payloads on top of format 2's module map; format 4 adds the optional
# ``native_artifacts`` map (AOT-compiled compiler modules: shared library +
# marshal layout per fullname); format 5 adds the optional ``placement`` map
# (pkg-relative source path -> list of codespaces the module emits into,
# persisted by the seal so downstream tools read placement instead of
# re-deriving it). Format 6 adds the mandatory-for-jaclang ``native`` record
# ({"roots": [fullname...], "skip_reason": None | "platform:<prefix>"}): the
# build's own statement of which modules it sealed natively, which
# ``load_image`` enforces (#8139 Step 1, "sealed means served"). Older APP
# images stay loadable; a jaclang image must be current format -- the image
# ships with the very code that loads it, so skew means a stale or partial
# install.
MANIFEST_FORMATS_ACCEPTED = (2, 3, 4, 5, MANIFEST_FORMAT)
# Must match jaclang.jac0core.jir.* ; kept literal here because this module
# must import before any .jac module (including jir.jac) can. This is the whole
# point of the bootstrap tier: jac0core modules are loaded from their JIR by the
# pure-Python section reader below, so they need none of the .jac machinery
# (jir.jac's reader is itself a jac0core module).
PRECOMPILE_SENTINEL = "__PKG_ROOT__"
JIR_FORMAT_VERSION = 20
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


_ARCH_ALIASES = {
    "arm64": "aarch64",
    "aarch64": "aarch64",
    "x86_64": "x86_64",
    "amd64": "x86_64",
}


def _triple_matches_host(triple: str) -> bool:
    """Whether an artifact's LLVM target triple matches this machine.

    Checks the arch token and the OS token; anything unparseable passes so an
    unusual but working triple never bricks a build. This is the check that
    rejects a wrong-platform artifact by name instead of leaving it to an
    incidental dlopen failure.
    """
    import platform

    arch = triple.split("-", 1)[0].lower()
    want = _ARCH_ALIASES.get(platform.machine().lower())
    have = _ARCH_ALIASES.get(arch)
    if want and have and want != have:
        return False
    low = triple.lower()
    if "darwin" in low or "macos" in low:
        return sys.platform == "darwin"
    if "linux" in low:
        return sys.platform.startswith("linux")
    if "windows" in low or "win32" in low:
        return sys.platform.startswith("win")
    return True


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
        # Optional AOT native artifacts (format 4): fullname -> entry with
        # ``lib`` / ``layout`` (precompiled-dir-relative paths), ``triple``,
        # and per-file sha256 digests.
        self.native_artifacts: dict[str, dict] = (
            manifest.get("native_artifacts") or {}
        )
        # Optional placement facts (format 5): pkg-relative posix source path
        # -> codespaces the module emits into (["server"], ["client"], ...).
        # The compiler's verdict, persisted; consumers must not re-derive it.
        self.placement: dict[str, list[str]] = manifest.get("placement") or {}
        # fullname -> (entry, src_relpath). One tree: full-compiler modules and
        # jac0-compiled bootstrap modules share the JIR container + manifest;
        # ``entry["bootstrap"]`` flags the jac0 tier (loaded via bootstrap_code).
        self.index: dict[str, tuple[dict, str]] = {}
        self._build_index()

    def _build_index(self) -> None:
        # MODULE_SUFFIXES precedence: earlier (shorter) suffixes win -- same
        # rule the filesystem finder applies. Process in precedence-sorted
        # order and keep first.
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

    def native_artifact(self, fullname: str) -> tuple[str, dict] | None:
        """Resolve a sealed AOT native artifact for ``fullname``.

        Returns ``(lib_abspath, layout_dict)`` after hash-verifying both
        files against the manifest, or None only when the image carries no
        artifact entry for the module at all.
        An entry that exists but is corrupt, unreadable, or built for another
        platform RAISES: sealed builds serve the native tier with no bytecode
        fallback, so a broken artifact is a broken install and must be loud,
        never a silent downgrade (#8139 Step 1).
        """
        entry = self.native_artifacts.get(fullname)
        if not entry:
            return None

        def _bad(reason: str) -> RuntimeError:
            return RuntimeError(
                f"sealed native artifact for {fullname} is unusable: {reason}."
                " Reinstall or rebuild this jac payload."
            )

        lib_rel = entry.get("lib", "")
        layout_rel = entry.get("layout", "")
        if not lib_rel or not layout_rel:
            raise _bad("manifest entry lacks lib/layout paths")
        expected_triple = entry.get("triple", "")
        if expected_triple and not _triple_matches_host(expected_triple):
            raise _bad(f"artifact targets {expected_triple}, not this platform")
        for rel in (lib_rel, layout_rel):
            if os.path.isabs(rel) or ".." in Path(rel).parts:
                raise _bad(f"illegal artifact path {rel!r}")
        lib_path = self.precompiled_dir / lib_rel
        layout_path = self.precompiled_dir / layout_rel
        try:
            lib_bytes = lib_path.read_bytes()
            layout_bytes = layout_path.read_bytes()
        except OSError as exc:
            raise _bad(f"cannot read artifact files ({exc})") from exc
        if hashlib.sha256(lib_bytes).hexdigest() != entry.get("lib_sha256"):
            raise _bad(f"{lib_path.name} fails its manifest sha256")
        if hashlib.sha256(layout_bytes).hexdigest() != entry.get("layout_sha256"):
            raise _bad(f"{layout_path.name} fails its manifest sha256")
        try:
            layout_dict = json.loads(layout_bytes)
        except ValueError as exc:
            raise _bad(f"{layout_path.name} is not valid JSON") from exc
        return (str(lib_path), layout_dict)

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


def _enforce_native_seal(manifest: dict, pdir: Path, manifest_path: Path) -> None:
    """The invariant's runtime consumer: sealed means served (#8139 Step 1).

    A jaclang image is loaded by the very code it was built from, so its
    manifest is the build's own statement of what it sealed natively. Enforce
    it: every declared native root resolves to an on-disk artifact for this
    host, or the image refuses to load. A build that skipped the native seal
    is valid only where no native backend exists (the recorded platform), so
    a bytecode-only image can never quietly serve a native-capable host.
    """
    if manifest.get("format") != MANIFEST_FORMAT:
        raise RuntimeError(
            f"sealed jaclang image {manifest_path}: manifest format "
            f"{manifest.get('format')!r} is not the current {MANIFEST_FORMAT}. "
            "The image ships with the code that loads it, so a format behind "
            "the runtime means a stale or partially updated install; rebuild "
            "the payload."
        )
    native = manifest.get("native")
    if not isinstance(native, dict):
        raise RuntimeError(
            f"sealed jaclang image {manifest_path}: manifest carries no "
            "native seal record; the build did not run the native seal. "
            "Rebuild the payload."
        )
    reason = native.get("skip_reason")
    if reason:
        # A recorded skip is only legitimate where no native backend exists.
        # The runtime does not take the manifest's word for that: a skip
        # stamp naming a native-capable platform is a build defect, and
        # honoring it would be silent degradation on exactly the hosts the
        # invariant protects.
        host_capable = not sys.platform.startswith("win")
        prefix = ""
        if isinstance(reason, str) and reason.startswith("platform:"):
            prefix = reason.split(":", 1)[1]
        if host_capable or not prefix or not sys.platform.startswith(prefix):
            raise RuntimeError(
                f"sealed jaclang image {manifest_path}: built without its "
                f"native seal ({reason!r}) but this host ({sys.platform}) "
                "has a native backend. Rebuild the payload on, or for, this "
                "platform."
            )
        return
    roots = native.get("roots") or []
    if not roots:
        raise RuntimeError(
            f"sealed jaclang image {manifest_path}: native seal record "
            "declares no roots. Rebuild the payload."
        )
    artifacts = manifest.get("native_artifacts") or {}
    for fullname in roots:
        entry = artifacts.get(fullname)
        if not entry:
            raise RuntimeError(
                f"sealed jaclang image {manifest_path}: declared native root "
                f"{fullname} has no artifact entry. Rebuild the payload."
            )
        triple = entry.get("triple", "")
        if triple and not _triple_matches_host(triple):
            raise RuntimeError(
                f"sealed jaclang image {manifest_path}: native root "
                f"{fullname} targets {triple}, not this platform. This image "
                "was built for a different machine; reinstall the right "
                "payload."
            )
        for key in ("lib", "layout"):
            rel = entry.get(key, "")
            if not rel or os.path.isabs(rel) or ".." in Path(rel).parts:
                raise RuntimeError(
                    f"sealed jaclang image {manifest_path}: native root "
                    f"{fullname} has an illegal {key} path {rel!r}."
                )
            if not (pdir / rel).is_file():
                raise RuntimeError(
                    f"sealed jaclang image {manifest_path}: native root "
                    f"{fullname} is missing its artifact file {rel}. The "
                    "install is incomplete; reinstall or rebuild the payload."
                )


def load_image(precompiled_dir: str | Path) -> SealedImage | None:
    """Load and validate a sealed image; None when no manifest is present.

    Raises RuntimeError (fail-closed) when a manifest exists but targets a
    different interpreter or JIR format, or -- for a jaclang image -- cannot
    serve its declared native roots on this host. Silently ignoring any of
    these would degrade to live compilation or the bytecode tier, which a
    sealed build does not have (#8139).
    """
    pdir = Path(precompiled_dir)
    manifest_path = pdir / MANIFEST_NAME
    try:
        raw = manifest_path.read_bytes()
    except OSError:
        return None
    # An image exists, so the bootstrap-tier escape hatches must not: both
    # were build/dev-time flags (the seal build no longer needs either), and
    # honoring them here would be exactly the silent degradation the seal
    # forbids. Refuse loudly instead of guessing which tier the caller meant.
    for flag in ("JAC_NO_SEAL", "JAC_SEAL_NO_NATIVE"):
        if os.environ.get(flag):
            raise RuntimeError(
                f"{flag} is set, but {manifest_path} is a sealed image. "
                "Sealed installs have no source/bytecode fallback tier to "
                f"select; unset {flag} (it is meaningful only while building "
                "a seal from a source tree)."
            )
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
    if manifest.get("package") == "jaclang":
        _enforce_native_seal(manifest, pdir, manifest_path)
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
        # No env gate here by design: an image next to the package either
        # loads or raises. The seal build (which regenerates the manifest and
        # must run unsealed) removes any seeded manifest before this module
        # can probe, so "no manifest" IS the build/dev tier -- a build stage,
        # not a mode anyone selects (#8139 Step 1).
        pkg_dir = Path(__file__).resolve().parent.parent
        image = load_image(pkg_dir / "_precompiled")
        if image is not None:
            _images.insert(0, image)
    for img in _images:
        if img.package == "jaclang":
            return img
    return None


def native_tier_required() -> bool:
    """Whether this process runs from a jaclang image that sealed native roots.

    True means the bytecode tier is not a legal answer for sealed modules:
    the #8139 tripwire raises instead of letting a compile path quietly run
    the Python body of a module the image claims to serve natively. False
    covers dev source trees (no image) and images legitimately built without
    a native seal (platforms with no native backend).
    """
    image = _jaclang_image()
    if image is None:
        return False
    native = image.manifest.get("native") or {}
    return bool(native.get("roots"))


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


def native_artifact_for(fullname: str) -> tuple[str, dict] | None:
    """Sealed AOT native artifact for ``fullname`` across all images.

    Returns ``(lib_abspath, layout_dict)`` or None when no image carries an
    entry. Integrity problems raise; see ``SealedImage.native_artifact``.
    """
    _jaclang_image()
    for img in _images:
        found = img.native_artifact(fullname)
        if found is not None:
            return found
    return None


def native_artifact_names() -> list[str]:
    """Every module fullname any loaded image carries a native artifact for.

    The pass-serving binder enumerates these at first pass construction to
    bind each sealed pass artifact; resolution and integrity stay with
    ``native_artifact_for``.
    """
    _jaclang_image()
    names: list[str] = []
    for img in _images:
        for fullname in img.native_artifacts:
            if fullname not in names:
                names.append(fullname)
    return names


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
