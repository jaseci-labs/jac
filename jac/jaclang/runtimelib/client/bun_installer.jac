"""Bun resolver for jac-client.

bun is contained within the jac ecosystem: acquired once at build time by the
sha256-verified `fetch-bun` step (launcher/payload.zig) and bundled inside the
package, then resolved at runtime by absolute path. It is never placed on PATH
and a system bun is never adopted. See impl/bun_installer.impl.jac for details.
"""

# Canonical pinned bun version. Single source of truth across the project: the
# Zig fetcher (launcher/payload.zig `BUN_VERSION`, kept in lockstep) downloads
# this exact version, and deployment targets (e.g. jac-scale's kubernetes
# target) reuse it to pre-install bun in container images. Bump when a new bun
# release is validated -- update payload.zig's constant to match.
glob BUN_VERSION = "1.3.11";

"""Resolve the absolute path to the bun binary.

bun is bundled inside the runtime and always invoked by absolute path -- never
placed on the user's PATH and a system-installed bun is never adopted, mirroring
how the bundled libpython is hermetic and never falls back to a PATH `python3`.

Resolution order:
  1. JAC_BUN override (an explicit absolute path; power-user / CI escape hatch)
  2. Bundled bun shipped inside the jaclang package -- the single runtime path.
     In a shipped binary, missing = a broken build; in an editable/source
     checkout, run `zig build fetch-bun` to place it. Either way, failing loud
     beats reaching for the network.

Returns the absolute path as a string, or None if unavailable.
"""
def get_bun -> str | None;
