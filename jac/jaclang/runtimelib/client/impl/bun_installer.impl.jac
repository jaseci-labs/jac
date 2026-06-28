"""Implementation of the bun resolver.

bun is contained entirely within the jac ecosystem. It is acquired once, at
build time, by the sha256-verified `fetch-bun` step in launcher/payload.zig:

  * Normal/release builds bundle a target-matched bun into the payload, inside
    the package at jaclang/runtimelib/client/_bun/<bun>.
  * Editable / source checkouts place the host bun into the same path via
    `zig build fetch-bun` (run by fresh_env.sh and on demand).

There is a single resolution path at runtime -- the bundled binary, located
relative to `__file__` -- and it is always invoked by absolute path, never
placed on PATH and never resolved from a system install (the contained model the
bundled libpython uses). The legacy Python on-demand downloader is gone: the Zig
fetcher is the one, verified way bun enters the tree.
"""

import os;
import platform;
import sys;

import from jaclang.cli.console { console }


"""Locate the bundled bun shipped inside the jaclang package, or an explicit
JAC_BUN override. Returns an absolute path or None.

Mirrors the native LLVM/desktop shim resolution (`_find_shim`): bun is bundled
at jaclang/runtimelib/client/_bun/<bun> (placed by the payload build / the
fetch-bun step, like the native shims) and located relative to `__file__`, so it
resolves both in the packed single-binary runtime (where site/ is materialized
to the cache) and in an editable tree that has it placed. Honors a JAC_BUN
absolute-path override -- the contained equivalent of pointing at a custom
binary, without ever consulting the user's PATH."""
def _find_bundled_bun -> str | None {
    override = os.environ.get("JAC_BUN", None);
    if override {
        if os.path.isfile(override) {
            return override;
        }
        # An explicit override that points nowhere is a mistake worth surfacing,
        # not silently papering over with the bundled copy.
        console.warning(
            f"JAC_BUN is set to '{override}' but no file exists there; "
            "ignoring it and using the bundled bun.",
            emoji=False
        );
    }
    is_windows = platform.system() == "Windows";
    bun_name = "bun.exe" if is_windows else "bun";
    # This module lives at jaclang/runtimelib/client/impl/; bun sits one dir up,
    # under client/_bun/<bun_name>. __file__-relative works in the editable tree
    # (its dir is not on sys.path) and in the materialized payload alike.
    here = os.path.dirname(os.path.abspath(__file__));
    client_dir = os.path.dirname(here);
    cand = os.path.join(client_dir, "_bun", bun_name);
    if os.path.isfile(cand) {
        return cand;
    }
    # Payload fallback: the bundled site/ is on sys.path.
    for p in sys.path {
        if not p {
            continue;
        }
        alt = os.path.join(p, "jaclang", "runtimelib", "client", "_bun", bun_name);
        if os.path.isfile(alt) {
            return alt;
        }
    }
    return None;
}


"""Ensure `path` has the executable bit (POSIX only; no-op on Windows / errors).

The runtime payload tar is extracted mode-agnostically (runtime.zig uses
`.mode_mode = .ignore`), so the bundled bun materializes as 0o644. bun is the
first *spawned* executable in that tree (libpython and the native shims are
dlopened), so jac restores its exec bit here -- the materialized tree lives in
the user's own cache and is writable."""
def _ensure_executable(path: str) {
    if platform.system() == "Windows" {
        return;
    }
    # chmod is idempotent and cheap; always (re)assert the exec bit rather than
    # probing first (avoids a needless stat and any access-mode edge cases).
    try {
        os.chmod(path, 0o755);
    } except OSError as e {
        # A failure here (read-only cache, odd perms after an upgrade) would
        # otherwise surface later as a cryptic EACCES when bun is spawned, so
        # name the real cause now.
        console.warning(
            f"Could not set the executable bit on bundled bun at {path}: {e}",
            emoji=False
        );
    }
}


"""Resolve the absolute path to the bun binary; None if unavailable.

bun is contained within the jac ecosystem: bundled inside the runtime and always
invoked by absolute path. It is never added to PATH and a system bun is never
adopted. See this module's header and the bun_installer.jac interface doc.
"""
impl get_bun -> str | None {
    bundled = _find_bundled_bun();
    if bundled is not None {
        _ensure_executable(bundled);
        return bundled;
    }
    # No bundled bun and no override. In a shipped binary this means a broken
    # build; in an editable/source checkout it means bun was never placed. Fail
    # loudly with the one verified way to fix it -- never reach for the network
    # here (that is the dependency the bundling removes).
    console.error(
        "bun is not available in this jac runtime. Shipped binaries bundle it "
        "(a missing copy indicates a broken build); for an editable/source "
        "checkout run `zig build fetch-bun`, or set JAC_BUN to an absolute bun "
        "path.",
        emoji=False
    );
    return None;
}
