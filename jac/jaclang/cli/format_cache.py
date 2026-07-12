"""Content-addressed cache of *proven-clean* Jac format results.

A valid entry proves::

    (content digest + lintfix mode + config fingerprint
     + logical path when lintfix + formatter stamp) -> clean

On a hit the caller may skip the formatter entirely -- no ``JacProgram``,
no AST, no lint pass, no formatted-output allocation. This is the single
biggest win for pre-commit, where ~all files are already formatted.

Design notes (see ``jac fmt`` / ``jac precommit`` integration in
``cli/commands/impl/analysis.impl.jac``):

* **Content-addressed.** The entry filename *is* the digest, which already
  encodes content + lintfix + config fingerprint + formatter stamp (and,
  under ``lintfix``, the canonical logical path). Renaming a clean file
  without lintfix does not invalidate it; two clean files with identical
  bytes share one entry. With ``lintfix``, path is part of the key because
  ``lint.exclude`` is path-sensitive.
* **Self-healing.** Every entry carries a magic marker. A file that is
  missing, unreadable, or unrecognisable is a *miss* and is deleted on read,
  so a polluted directory can never produce a false "clean".
* **Best-effort.** ``mark_clean`` never raises; a read-only or unwritable
  cache simply stores less. Cache state is advisory, never an authority over
  formatting.
* **Atomic + concurrency-safe.** Writes go through a process-unique temp file
  followed by ``os.replace`` (POSIX-atomic), so parallel ``fmt`` workers or
  an interrupted run cannot leave a half-written entry. Mirrors the pattern
  in ``jaclang/meta_importer.py``.
* **Version-namespaced.** Entries live under ``<cache_dir>/fmt-<schema>/`` so
  an incompatible future schema discards old state rather than interpreting it.

This module deliberately knows nothing about annex files or the formatter
pipeline orchestration: the worker assembles the unit bytes, effective config
fingerprint, and logical path and hands them in. That keeps the cache a deep
module with a tiny, pure, easily-tested interface.
"""

from __future__ import annotations

import contextlib
import hashlib
import importlib
import os
from pathlib import Path

# Bump when the on-disk layout or key composition changes incompatibly.
# Old entries live under a different ``fmt-<schema>`` subdir and are ignored.
FORMAT_CACHE_SCHEMA_VERSION = "v1"

# Marker written into every entry. A file that does not start with this is
# treated as corrupt and deleted on read.
_ENTRY_MARKER = b"JFMTCLEAN\n"

# Modules whose source affects formatter / lintfix output. Hashed into the
# formatter stamp so development edits invalidate the cache even when the
# package version string is unchanged.
_FORMATTER_PIPELINE_MODULES = (
    "jaclang.compiler.passes.tool.jac_formatter_pass",
    "jaclang.compiler.passes.tool.jac_auto_lint_pass",
    "jaclang.compiler.passes.tool.doc_ir_gen_pass",
    "jaclang.compiler.passes.tool.comment_injection_pass",
    "jaclang.compiler.passes.tool.normalize_pass",
    "jaclang.compiler.passes.tool.unparse_pass",
    "jaclang.compiler.passes.tool.doc_ir",
    "jaclang.jac0core.passes.transform",
)


def _stable_dump(value: object) -> str:
    """Deterministic, order-stable serialization for config fingerprinting."""
    if value is None or isinstance(value, (bool, int, float, str)):
        return repr(value)
    if isinstance(value, (list, tuple)):
        return "[" + ",".join(_stable_dump(v) for v in value) + "]"
    if isinstance(value, dict):
        items = sorted((str(k), _stable_dump(v)) for k, v in value.items())
        return "{" + ",".join(f"{k}:{v}" for k, v in items) + "}"
    # Jac config section objects (FormatConfig, CheckConfig, LintConfig, …).
    attrs: dict[str, object] = {}
    for name in dir(value):
        if name.startswith("_"):
            continue
        try:
            attr = getattr(value, name)
        except Exception:
            continue
        if callable(attr):
            continue
        attrs[name] = attr
    return _stable_dump(attrs)


def config_fingerprint(config: object, lintfix: bool) -> str:
    """Return a stable digest of the output-affecting effective config.

    Over-broad is safe (extra misses), under-broad is unsafe (false hits).
    Rather than maintaining a manual field list that drifts, this fingerprints
    the complete effective ``[format]`` section always, and the complete
    effective ``[check]`` section (including ``suppress`` /
    ``suppress_categories`` / nested ``lint``) whenever ``lintfix`` is on.
    The argument is a resolved ``JacConfig`` (or ``None``).
    """
    if config is None:
        return "none"
    parts: list[str] = [f"lintfix={int(bool(lintfix))}"]
    parts.append(f"profile={getattr(config, 'active_profile', '') or ''}")
    parts.append("format=" + _stable_dump(getattr(config, "format", None)))
    if lintfix:
        parts.append("check=" + _stable_dump(getattr(config, "check", None)))
    plugins = getattr(config, "plugin_dependencies", None) or {}
    if plugins:
        items = sorted(f"{k}={v}" for k, v in plugins.items())
        parts.append("plugins=" + "|".join(items))
    return hashlib.sha256("\n".join(parts).encode()).hexdigest()


def canonical_logical_path(path: str, project_root: str | None = None) -> str:
    """Return a stable, slash-normalized logical path for cache keys.

    Prefer project-relative form so the same tree at two checkout locations
    shares entries; fall back to the normalized absolute/local path.
    """
    norm = os.path.normpath(path)
    if project_root:
        try:
            rel = os.path.relpath(norm, os.path.normpath(project_root))
            if not rel.startswith(".."):
                return rel.replace(os.sep, "/")
        except ValueError:
            pass
    return norm.replace(os.sep, "/")


def default_format_cache_dir(anchor: Path | str) -> Path:
    """Default ``.jac/cache`` location when no project config is available."""
    base = Path(anchor)
    # Prefer the parent of a source file. Treat ``*.jac`` as a file even when
    # the path does not currently exist (caller may pass a logical path).
    if base.is_file() or base.suffix == ".jac":
        base = base.parent
    return base.resolve() / ".jac" / "cache"


def _module_source_bytes(modname: str) -> bytes:
    """Best-effort source bytes for ``modname`` (``.jac`` preferred over ``.py``)."""
    try:
        mod = importlib.import_module(modname)
    except Exception:
        return b""
    file_path = getattr(mod, "__file__", None)
    if not file_path:
        return b""
    path = Path(file_path)
    candidates = [
        path.with_suffix(".jac"),
        path.parent / "impl" / f"{path.stem}.impl.jac",
        path,
    ]
    # Also pull sibling impl package files when the module lives under passes/tool.
    if path.parent.name == "tool":
        impl = path.parent / "impl" / f"{path.stem}.impl.jac"
        candidates.insert(1, impl)
    chunks: list[bytes] = []
    seen: set[str] = set()
    for candidate in candidates:
        key = str(candidate)
        if key in seen or not candidate.is_file():
            continue
        seen.add(key)
        try:
            chunks.append(candidate.read_bytes())
        except OSError:
            continue
    return b"\0".join(chunks)


def formatter_pipeline_revision() -> str:
    """Fingerprint formatter-pipeline sources for the cache stamp.

    Package version alone is too weak during development: editing a format or
    lint pass must invalidate entries even when ``jac_version()`` is unchanged.
    """
    h = hashlib.sha256()
    for modname in _FORMATTER_PIPELINE_MODULES:
        h.update(modname.encode())
        h.update(b"\0")
        h.update(_module_source_bytes(modname))
        h.update(b"\0")
    return h.hexdigest()[:16]


def frame_unit(parts: list[bytes]) -> bytes:
    """Length-framed concatenation of byte parts (unambiguous cache content).

    Each part is prefixed with its byte length, so the concatenation has a
    unique parse: two adjacent parts can never be re-split into a different
    interpretation (unlike a plain ``b"".join``, where ``[b"ab", b"c"]`` and
    ``[b"a", b"bc"]`` both collapse to ``b"abc"``). Workers assemble a unit --
    main file bytes plus any annex bytes -- and should frame it here rather
    than rolling their own scheme, so the framing convention lives in the one
    module that owns the key format. The result is fed to ``make_key`` as the
    ``content``.
    """
    return b"".join(f"{len(p)}:".encode() + p for p in parts)


# Length-prefixed frame so that concatenating components cannot create
# ambiguous keys (e.g. content ending in a byte equal to the separator).
def _frame(label: str, payload: bytes) -> bytes:
    return f"{label}:{len(payload)}:".encode() + payload


class FormatCache:
    """Pure content-addressed store of proven-clean format results."""

    __slots__ = ("_cache_dir", "_enabled", "_stamp", "_root")

    def __init__(
        self,
        cache_dir: Path | str | None,
        *,
        enabled: bool = True,
        formatter_stamp: str = "",
    ) -> None:
        self._enabled = bool(enabled) and cache_dir is not None
        self._stamp = formatter_stamp or ""
        if self._enabled:
            self._cache_dir = Path(cache_dir)  # type: ignore[arg-type]
            self._root = self._cache_dir / f"fmt-{FORMAT_CACHE_SCHEMA_VERSION}"
        else:
            self._cache_dir = None  # type: ignore[assignment]
            self._root = None  # type: ignore[assignment]

    # -- key construction ---------------------------------------------------

    def make_key(
        self,
        content: bytes,
        *,
        lintfix: bool,
        config_fingerprint: str,
        logical_path: str = "",
    ) -> str:
        """Return the hex digest that identifies a proven-clean unit.

        ``content`` is the canonical unit bytes the caller assembled (main
        file bytes, plus any annex bytes when ``lintfix`` is on). When
        ``lintfix`` is on, ``logical_path`` is also folded in because lint
        exclude matching is path-sensitive. Pure: same inputs always yield
        the same digest.
        """
        h = hashlib.sha256()
        h.update(_frame("stamp", self._stamp.encode()))
        h.update(_frame("lintfix", b"1" if lintfix else b"0"))
        h.update(_frame("cfg", config_fingerprint.encode()))
        if lintfix:
            h.update(_frame("path", logical_path.encode()))
        h.update(_frame("content", content))
        return h.hexdigest()

    def entry_path(self, key: str) -> Path:
        """On-disk path for ``key`` (also the corruption-recovery hook)."""
        assert self._root is not None  # only meaningful when enabled
        return self._root / key

    # -- store --------------------------------------------------------------

    def is_clean(self, key: str) -> bool:
        """True iff a valid clean entry exists for ``key``.

        Never raises: a missing, unreadable, or corrupt entry is a miss, and
        a corrupt entry is deleted so the cache self-heals.
        """
        if not self._enabled or self._root is None:
            return False
        path = self._root / key
        try:
            data = path.read_bytes()
        except OSError:
            return False
        if not data.startswith(_ENTRY_MARKER):
            # Polluted/stale file at this digest -- expunge and miss.
            with contextlib.suppress(OSError):
                path.unlink()
            return False
        return True

    def mark_clean(self, key: str) -> None:
        """Record that ``key`` is a proven-clean unit. Best-effort, never raises."""
        if not self._enabled or self._root is None:
            return
        path = self._root / key
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            # Process-unique temp + atomic replace: parallel workers and
            # interrupted runs cannot read a half-written entry.
            tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
            try:
                tmp.write_bytes(_ENTRY_MARKER)
                os.replace(tmp, path)
            finally:
                with contextlib.suppress(OSError):
                    tmp.unlink()
        except OSError:
            # Read-only dir, full disk, permission flip mid-run -- the cache
            # is advisory; never break the formatter over a cache write.
            return
