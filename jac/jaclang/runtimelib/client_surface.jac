"""Single source of truth for the `@jac/runtime` client surface contract.

`@jac/runtime` is a virtual module backed by two runtimes: bare-serve's
`jaclang/runtimelib/client_runtime.cl.jac` (zero npm deps, native JS) and
jac-client's `jac_client/plugin/client_runtime.cl.jac` (React-backed). User
`.cl.jac` code is portable between them only while their public surfaces stay
aligned.

This module declares that surface once. The pieces that used to hardcode their
own copy of it now derive from here instead:

  * the ECMAScript pass asks `runtime_import_source` where each emitted runtime
    symbol is imported from, so the import source lives in one place;
  * the `eject` and HMR bundle paths build their prepended JSX-runtime import
    from `prepended_runtime_import`;
  * the runtime-surface-alignment test derives its expectations from
    `aligned_surface` / `production_surface` / `routing_surface` /
    `compiler_emitted_surface`.

Tiers
  ALIGNED     Must be exported by BOTH runtimes — either user-facing (imported
              via `import from "@jac/runtime"`) or emitted by the compiler.
              Breaking alignment breaks cross-runtime portability.
  PRODUCTION  jac-client only. Bare-serve omits these; they are irreducibly
              tied to React / Zod / react-router, or — like `useRef` — imported
              straight from `react` and so never resolved through the runtime.
"""

enum RuntimeTier { ALIGNED, PRODUCTION }

"""One symbol on the `@jac/runtime` surface.

`source` is the module the compiler imports the symbol from (`@jac/runtime` for
everything the runtimes back, `react` for primitives taken straight from React).
`emitted` marks symbols the compiler references by name in generated code (so
both runtimes must provide them). `prepend` marks the bare global identifiers
the compiler emits without an explicit import node — the bundle paths prepend a
single import statement covering them.
"""
obj RuntimeSymbol {
    has name: str,
        tier: RuntimeTier,
        category: str,
        source: str = "@jac/runtime",
        emitted: bool = False,
        prepend: bool = False;
}

glob CLIENT_RUNTIME_SURFACE: list[RuntimeSymbol] = [
         # ---- JSX factory (emitted as a bare global; prepended as a bundle import) -
         RuntimeSymbol(
             name="__jacJsx",
             tier=RuntimeTier.ALIGNED,
             category="jsx",
             emitted=True,
             prepend=True
         ),
         # ---- Walker / function calls ------------------------------------------
         RuntimeSymbol(
             name="__jacSpawn",
             tier=RuntimeTier.ALIGNED,
             category="walker",
             emitted=True,
             prepend=True
         ),
         RuntimeSymbol(name="jacSpawn", tier=RuntimeTier.ALIGNED, category="walker"),
         RuntimeSymbol(
             name="__jacCallFunction",
             tier=RuntimeTier.ALIGNED,
             category="walker",
             emitted=True
         ),
         # ---- Reactive hooks (emitted for `has` fields / event abilities) ------
         RuntimeSymbol(
             name="useState", tier=RuntimeTier.ALIGNED, category="hooks", emitted=True
         ),
         RuntimeSymbol(
             name="useEffect", tier=RuntimeTier.ALIGNED, category="hooks", emitted=True
         ),
         # `useRef` is imported straight from `react`, so it never resolves through
         # the runtime: `Ref[T]` fields are a jac-client-only capability today.
         RuntimeSymbol(
             name="useRef",
             tier=RuntimeTier.PRODUCTION,
             category="hooks",
             source="react",
             emitted=True
         ),
         # ---- View wrappers (emitted for `try`/`awaiting`/`except` JSX) ---------
         RuntimeSymbol(
             name="JacAwaiting", tier=RuntimeTier.ALIGNED, category="view", emitted=True
         ),
         RuntimeSymbol(
             name="JacClientErrorBoundary",
             tier=RuntimeTier.ALIGNED,
             category="view",
             emitted=True
         ),
         # ---- Routing (React Router v6-shaped) ---------------------------------
         RuntimeSymbol(name="Router", tier=RuntimeTier.ALIGNED, category="routing"),
         RuntimeSymbol(name="Routes", tier=RuntimeTier.ALIGNED, category="routing"),
         RuntimeSymbol(name="Route", tier=RuntimeTier.ALIGNED, category="routing"),
         RuntimeSymbol(name="Link", tier=RuntimeTier.ALIGNED, category="routing"),
         RuntimeSymbol(name="Navigate", tier=RuntimeTier.ALIGNED, category="routing"),
         RuntimeSymbol(name="Outlet", tier=RuntimeTier.ALIGNED, category="routing"),
         RuntimeSymbol(
             name="useNavigate", tier=RuntimeTier.ALIGNED, category="routing"
         ),
         RuntimeSymbol(
             name="useLocation", tier=RuntimeTier.ALIGNED, category="routing"
         ),
         RuntimeSymbol(name="useParams", tier=RuntimeTier.ALIGNED, category="routing"),
         RuntimeSymbol(name="useRouter", tier=RuntimeTier.ALIGNED, category="routing"),
         RuntimeSymbol(name="navigate", tier=RuntimeTier.ALIGNED, category="routing"),
         # ---- Auth -------------------------------------------------------------
         RuntimeSymbol(name="jacSignup", tier=RuntimeTier.ALIGNED, category="auth"),
         RuntimeSymbol(name="jacLogin", tier=RuntimeTier.ALIGNED, category="auth"),
         RuntimeSymbol(name="jacLogout", tier=RuntimeTier.ALIGNED, category="auth"),
         RuntimeSymbol(name="jacIsLoggedIn", tier=RuntimeTier.ALIGNED, category="auth"),
         # ---- Browser storage shims --------------------------------------------
         RuntimeSymbol(
             name="__getLocalStorage", tier=RuntimeTier.ALIGNED, category="browser"
         ),
         RuntimeSymbol(
             name="__setLocalStorage", tier=RuntimeTier.ALIGNED, category="browser"
         ),
         RuntimeSymbol(
             name="__removeLocalStorage", tier=RuntimeTier.ALIGNED, category="browser"
         ),
         # ---- Auto-cache layer (runtime-agnostic; backed by both runtimes) -----
         RuntimeSymbol(
             name="__getEndpointEffects", tier=RuntimeTier.ALIGNED, category="cache"
         ),
         RuntimeSymbol(
             name="__getCacheState", tier=RuntimeTier.ALIGNED, category="cache"
         ),
         RuntimeSymbol(name="__isFresh", tier=RuntimeTier.ALIGNED, category="cache"),
         RuntimeSymbol(name="__cacheGet", tier=RuntimeTier.ALIGNED, category="cache"),
         RuntimeSymbol(name="__cacheSet", tier=RuntimeTier.ALIGNED, category="cache"),
         RuntimeSymbol(
             name="__evictOldest", tier=RuntimeTier.ALIGNED, category="cache"
         ),
         RuntimeSymbol(name="__overlaps", tier=RuntimeTier.ALIGNED, category="cache"),
         RuntimeSymbol(
             name="__invalidateEndpoint", tier=RuntimeTier.ALIGNED, category="cache"
         ),
         RuntimeSymbol(
             name="__cachedEndpointCall", tier=RuntimeTier.ALIGNED, category="cache"
         ),
         RuntimeSymbol(
             name="__doWalkerFetch", tier=RuntimeTier.ALIGNED, category="cache"
         ),
         RuntimeSymbol(
             name="__doFuncFetch", tier=RuntimeTier.ALIGNED, category="cache"
         ),
         # ---- Client error reporting -------------------------------------------
         RuntimeSymbol(
             name="__jacReportError", tier=RuntimeTier.ALIGNED, category="error"
         ),
         RuntimeSymbol(
             name="__jacInstallErrorHandlers",
             tier=RuntimeTier.ALIGNED,
             category="error"
         ),
         RuntimeSymbol(
             name="__jacReactErrorHandler", tier=RuntimeTier.ALIGNED, category="error"
         ),
         # ---- Production tier: jac-client only, React / Zod / react-router bound -
         RuntimeSymbol(name="JacForm", tier=RuntimeTier.PRODUCTION, category="form"),
         RuntimeSymbol(name="useJacForm", tier=RuntimeTier.PRODUCTION, category="form"),
         RuntimeSymbol(name="JacSchema", tier=RuntimeTier.PRODUCTION, category="form"),
         RuntimeSymbol(
             name="__createJacSchema", tier=RuntimeTier.PRODUCTION, category="form"
         ),
         RuntimeSymbol(name="AuthGuard", tier=RuntimeTier.PRODUCTION, category="auth"),
         RuntimeSymbol(
             name="ErrorFallback", tier=RuntimeTier.PRODUCTION, category="error"
         ),
         RuntimeSymbol(
             name="errorOverlay", tier=RuntimeTier.PRODUCTION, category="error"
         ),
         RuntimeSymbol(
             name="__getApiBaseUrl", tier=RuntimeTier.PRODUCTION, category="browser"
         )
     ];

"""The declared symbol for `name`, or `None` if it is not part of the surface."""
def runtime_symbol(name: str) -> (RuntimeSymbol | None) {
    for sym in CLIENT_RUNTIME_SURFACE {
        if sym.name == name {
            return sym;
        }
    }
    return None;
}

"""Whether `name` is a declared `@jac/runtime` surface symbol."""
def is_runtime_symbol(name: str) -> bool {
    return runtime_symbol(name) is not None;
}

"""Module the compiler imports `name` from.

Returns the declared source (`@jac/runtime`, or `react` for React primitives).
Undeclared names fall back to `@jac/runtime` — the historical default — so an
unforeseen emission never breaks a build; the alignment test is what guards
against undeclared compiler emissions.
"""
def runtime_import_source(name: str) -> str {
    sym = runtime_symbol(name);
    if sym is not None {
        return sym.source;
    }
    return "@jac/runtime";
}

# The export-surface helpers describe what the runtime *files* export, so they
# exclude react-sourced symbols (e.g. `useRef`) — those resolve straight from
# `react` via the compiler and are never exported by either runtime.
def _exports_with_tier(tier: RuntimeTier) -> set[str] {
    return {
        sym.name
        for sym in CLIENT_RUNTIME_SURFACE
        if sym.tier == tier and sym.source == "@jac/runtime"
    };
}

"""Names both runtimes must export (the portability contract)."""
def aligned_surface -> set[str] {
    return _exports_with_tier(RuntimeTier.ALIGNED);
}

"""Names only jac-client exports (bare-serve omits). Excludes react-sourced
symbols like `useRef`, which the compiler takes straight from `react`."""
def production_surface -> set[str] {
    return _exports_with_tier(RuntimeTier.PRODUCTION);
}

"""The routing subset — must match exactly across runtimes."""
def routing_surface -> set[str] {
    return {
        sym.name
        for sym in CLIENT_RUNTIME_SURFACE
        if sym.category == "routing"
    };
}

"""Names the compiler emits that resolve through `@jac/runtime`.

React-sourced emissions (e.g. `useRef`) are excluded — they never touch the
runtime — so every name here must be exported by both runtimes.
"""
def compiler_emitted_surface -> set[str] {
    return {
        sym.name
        for sym in CLIENT_RUNTIME_SURFACE
        if sym.emitted and sym.source == "@jac/runtime"
    };
}

"""The single import statement the bundle paths prepend for the bare global
identifiers the compiler emits (`__jacJsx`, `__jacSpawn`)."""
def prepended_runtime_import -> str {
    names = [
        sym.name
        for sym in CLIENT_RUNTIME_SURFACE
        if sym.prepend
    ];
    return 'import {' + ", ".join(names) + '} from "@jac/runtime";';
}
