"""Builds the Jac client runtime as a publishable npm package (@jaseci/runtime).

A standalone npm package compiled from `.cl.jac` references runtime globals such
as `__jacJsx`; those resolve to this package, which compiles the bare-serve Jac
client runtime to a single ESM module and re-exports its public API.

The compiled runtime source is **framework-aware**: it is the active backend's
`runtime_source_basename()` (`client_runtime.cl.jac` for React/Preact,
`solid_runtime.cl.jac` for Solid), resolved through `runtimelib/runtime_source`.
A React/Preact build publishes the React-independent `@jaseci/runtime`; a Solid
build publishes `@jaseci/runtime-solid`, compiled from the Solid shim and pulling
in **no** React-ecosystem package. Pass `framework` explicitly to target a
specific backend, or leave it `""` to use the project's active backend.
"""

import from pathlib { Path }

glob RUNTIME_PKG_NAME: str = "@jaseci/runtime";

"""The 34 framework-agnostic symbols that every `@jac/runtime` shim MUST re-export:
the public API `def:pub` surface (navigate, jacSpawn, auth, …) plus the `__`-prefixed
internal helpers used by generated code. The surface-parity test in
`test_npm_publish.jac` checks every shim against this set; framework-specific extras
are allowed, but none may omit these."""
glob CORE_RUNTIME_SYMBOLS: set[str] = set(
         [
             "navigate",
             "jacSpawn",
             "jacSignup",
             "jacLogin",
             "jacLogout",
             "jacIsLoggedIn",
             "jacSsoLogin",
             "jacSetToken",
             "__createJacSchema",
             "__jacSpawn",
             "__jacCallFunction",
             "__normalizeIdentity",
             "__normalizeCredential",
             "__jacClearCache",
             "__jacDesktopBroker",
             "__jacPollBrokerSession",
             "__jacSleep",
             "__getApiBaseUrl",
             "__getLocalStorage",
             "__setLocalStorage",
             "__removeLocalStorage",
             "__getEndpointEffects",
             "__getCacheState",
             "__isFresh",
             "__cacheGet",
             "__cacheSet",
             "__evictOldest",
             "__doWalkerFetch",
             "__doFuncFetch",
             "__cachedEndpointCall",
             "__invalidateEndpoint",
             "__overlaps",
             "__jacReportError",
             "__jacInstallErrorHandlers"
         ]
     );

"""The runtime's public API symbol names (its top-level def/glob surface) for
   `framework` (`""` = active backend).

   This same set drives runtime-import detection in npm_sources, so a module that
   uses any of these names gets an import wired to the runtime package."""
def runtime_api_names(framework: str = "") -> set[str];

"""Compile the Jac client runtime for `framework` to a single ESM JavaScript
   string (cached per framework; `""` = active backend)."""
def compile_runtime_js(framework: str = "") -> str;

"""npm package name for `framework`'s runtime (`""` = active backend).

   React/Preact share `client_runtime.cl.jac` and publish as `@jaseci/runtime`;
   any other backend gets a `@jaseci/runtime-<framework>` suffix (e.g.
   `@jaseci/runtime-solid`) so distinct runtimes never collide on the registry."""
def runtime_pkg_name(framework: str = "") -> str;

"""Public API names actually declared at top level in `js`, sorted — the symbols
   appended to the runtime module's `export {...}` clause. Resolved against
   `framework`'s API surface (`""` = active backend)."""
def runtime_export_names(js: str, framework: str = "") -> list[str];

"""Build the runtime npm tarball bytes for `version` (e.g. the jaclang version).

   `pkg_name` defaults to `runtime_pkg_name(framework)`; `framework` defaults to
   the active backend."""
def build_runtime_tarball(
    version: str, pkg_name: str = "", framework: str = ""
) -> bytes;

"""Build the runtime tarball and write it to output_dir; returns the Path."""
def build_runtime_to(
    output_dir: Path, version: str, pkg_name: str = "", framework: str = ""
) -> Path;

"""Resolve peer dependency version ranges for bare-package imports in `js`.

Raises `ValueError` when the compiled runtime imports a package that is not in
the canonical `_PEER_VERSIONS` map."""
def runtime_peer_deps(js: str) -> dict[str, str];
