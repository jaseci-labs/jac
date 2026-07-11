"""Content-addressed cache of *proven-clean* Jac format results.

A valid entry proves::

    (content digest + lintfix mode + config fingerprint + formatter stamp) -> clean

On a hit the caller may skip the formatter entirely -- no ``JacProgram``,
no AST, no lint pass, no formatted-output allocation. This is the single
biggest win for pre-commit, where ~all files are already formatted.

Design notes (see ``jac fmt`` / ``jac precommit`` integration in
``cli/commands/impl/analysis.impl.jac``):

* **Content-addressed.** The entry filename *is* the digest, which already
  encodes content + lintfix + config fingerprint + formatter stamp. Renaming
  a clean file does not invalidate it; two clean files with identical bytes
  share one entry.
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

This module deliberately knows nothing about ``JacConfig``, annex files, or
the formatter pipeline: the worker assembles the unit bytes and the effective
config fingerprint and hands them in. That keeps the cache a deep module with
a tiny, pure, easily-tested interface.
"""

from __future__ import annotations

import contextlib
import hashlib
import os
from pathlib import Path

# Bump when the on-disk layout or key composition changes incompatibly.
# Old entries live under a different ``fmt-<schema>`` subdir and are ignored.
FORMAT_CACHE_SCHEMA_VERSION = "v1"

# Marker written into every entry. A file that does not start with this is
# treated as corrupt and deleted on read.
_ENTRY_MARKER = b"JFMTCLEAN\n"


# ---------------------------------------------------------------------------
# Best-effort run stats (fork-safe)
#
# The per-file worker records its outcome on each result dict; ``format()``
# aggregates from the collected results *in the parent* and publishes here.
# Aggregating after the fork/join (rather than mutating a global from workers)
# keeps the counts correct under ``ProcessPoolExecutor``. Single-file runs are
# in-process, so the numbers are exact for tests.
# ---------------------------------------------------------------------------
_LAST_RUN_STATS: dict[str, int] = {"examined": 0, "hits": 0, "misses": 0}


def reset_run_stats() -> None:
    """Zero the published run stats (test/observability hook)."""
    _LAST_RUN_STATS["examined"] = 0
    _LAST_RUN_STATS["hits"] = 0
    _LAST_RUN_STATS["misses"] = 0


def record_run(hits: int, misses: int) -> None:
    """Publish aggregated cache outcome counts for the run just finished."""
    _LAST_RUN_STATS["hits"] = int(hits)
    _LAST_RUN_STATS["misses"] = int(misses)
    _LAST_RUN_STATS["examined"] = int(hits) + int(misses)


def run_stats() -> dict[str, int]:
    """Return a copy of the published run stats."""
    return dict(_LAST_RUN_STATS)


def config_fingerprint(config: object, lintfix: bool) -> str:
    """Return a stable digest of the output-affecting effective config.

    Over-broad is safe (extra misses), under-broad is unsafe (false hits), so
    this leans conservative: it folds in every setting known to influence
    formatter output -- lint selection (only matters under ``lintfix``),
    ``[format]`` options, the active profile, and plugin identities/versions.
    The argument is a resolved ``JacConfig`` (or ``None``).
    """
    if config is None:
        return "none"
    parts: list[str] = [f"lintfix={int(bool(lintfix))}"]
    # Active profile changes which environment/inherits apply.
    parts.append(f"profile={getattr(config, 'active_profile', '') or ''}")
    fmt = getattr(config, "format", None)
    if fmt is not None:
        parts.append(f"outfile={getattr(fmt, 'outfile', '') or ''}")
    if lintfix:
        chk = getattr(config, "check", None)
        lint = getattr(chk, "lint", None) if chk is not None else None
        if lint is not None:
            parts.append("lint.select=" + ",".join(getattr(lint, "select", []) or []))
            parts.append("lint.ignore=" + ",".join(getattr(lint, "ignore", []) or []))
            parts.append("lint.exclude=" + ",".join(getattr(lint, "exclude", []) or []))
    # Plugin identity/version can affect output; include defensively.
    plugins = getattr(config, "plugin_dependencies", None) or {}
    if plugins:
        items = sorted(f"{k}={v}" for k, v in plugins.items())
        parts.append("plugins=" + "|".join(items))
    return hashlib.sha256("\n".join(parts).encode()).hexdigest()


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
    ) -> str:
        """Return the hex digest that identifies a proven-clean unit.

        ``content`` is the canonical unit bytes the caller assembled (main
        file bytes, plus any annex bytes when ``lintfix`` is on). Pure: same
        inputs always yield the same digest.
        """
        h = hashlib.sha256()
        h.update(_frame("stamp", self._stamp.encode()))
        h.update(_frame("lintfix", b"1" if lintfix else b"0"))
        h.update(_frame("cfg", config_fingerprint.encode()))
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
