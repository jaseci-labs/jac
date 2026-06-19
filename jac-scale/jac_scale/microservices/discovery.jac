"""Zero-config discovery of microservices from `sv import` / `to sv:` markers.

`jac start <entry>.jac` should "just work" for an app that splits itself into
services with `sv import`, without requiring a `[plugins.scale.microservices]`
config block. This module finds the service graph by parsing the entry file's
sibling `.jac` modules with the real Jac parser and inspecting their AST for the
two service markers:

  - a module that exposes a server section (`to sv:` or `sv { ... }`) declares
    itself a service, and
  - an explicit `sv import from <module>` references another module as a peer
    service.

It returns a default routes map `{module_name: prefix}` covering the union of
both (prefixes via `derive_prefix`, so they match what `jac setup microservice`
would write), which the orchestrator turns into a service registry.

Why the parser instead of line regexes: the markers are then recognized exactly
as the compiler sees them. `sv import from cart_app` text inside a docstring is
classified by the parser as a string literal, never a statement, so it can never
become a false-positive service (no comment/docstring pre-stripping heuristic is
needed); the `sv { ... }` block form is detected as well as the `to sv:` section
form; and the imported module name is read from the same `base_module_name`
getter the compiler's boundary analysis uses, so static discovery and the
runtime stay in lockstep.

Scope: the scan is over the entry file's own directory and is deliberately
non-recursive. That matches the runtime's `ensure_sv_service` resolution, which
looks each peer up flat as `<dir>/<module>.jac` - a service in a nested
subpackage cannot be spawned by the runtime either, so it is not a service the
gateway can route to.
"""

import jaclang.jac0core.unitree as uni;
import from pathlib { Path }
import from jaclang.jac0core.parser { parse }
import from jac_scale.microservices.setup { derive_prefix }

# The parser tags EVERY `import` with `code_context == SERVER` (that is the
# default code context), so code_context cannot tell an `sv import` from a plain
# one. The reliable discriminator is the leading `sv` keyword token the parser
# prepends as the statement's first kid for an explicit server-context prefix;
# we match it by token name. (Validated against the k8s_e2e fixture.)
glob _SV_PREFIX_TOK: str = "KW_SERVER";


"""Server markers found in one parsed module.

`sv_import_targets` are the bare module names from this module's
`sv import from <name>` statements (peers it consumes). `is_service` is True when
the module exposes any server section (`to sv:` or `sv { ... }`), i.e. it
declares itself a service.
"""
obj ModuleMarkers {
    has sv_import_targets: list[str],
        is_service: bool;
}


"""Parse `text` and extract its server markers, or None if it cannot be parsed.

Parse-only (no type-check) so it works on an in-progress project whose modules
may not yet fully resolve. The parser still returns a (possibly partial) module
tree on recoverable errors, so we extract whatever markers it found rather than
discarding the file on the first unrelated syntax slip; only a hard parse
failure (no tree) drops the file - it could not be a healthy service anyway.
"""
def scan_markers(text: str, file_path: str) -> ModuleMarkers | None {
    try {
        (mod, _had_error) = parse(text, file_path=file_path);
    } except Exception {
        return None;
    }
    if mod is None {
        return None;
    }
    targets: list[str] = [];
    for imp in mod.get_all_sub_nodes(uni.Import) {
        first = imp.kid[0] if imp.kid else None;
        is_sv = (
            (first is not None)
            and (first?.name == _SV_PREFIX_TOK)
            and (imp.from_loc is not None)
        );
        if is_sv {
            name = imp.from_loc.base_module_name;
            if name {
                targets.append(name);
            }
        }
    }
    is_service = len(mod.get_all_sub_nodes(uni.ServerBlock)) > 0;
    return ModuleMarkers(sv_import_targets=targets, is_service=is_service);
}


"""Tri-state gate deciding whether `jac start` enters LOCAL microservice mode.

Pure (no I/O) so it is unit-testable without a HookContext. `enabled` is the
tri-state config value (True/False/None); `has_services` is whether discovery
found any `sv import` / `to sv:` services next to the entry file.

  - sibling child or --scale or explicit `enabled = false` -> never enter
  - explicit `enabled = true` -> always enter (routes filled from discovery)
  - `enabled` unset (None) -> enter only when services were discovered
"""
def should_enter_local_ms(
    enabled: bool | None, is_sv_sibling: bool, scale_flag: bool, has_services: bool
) -> bool {
    if is_sv_sibling or scale_flag or (enabled is False) {
        return False;
    }
    if enabled is True {
        return True;
    }
    return has_services;
}


"""Discover sv-import services next to `entry_file`.

Returns `{module_name: prefix}` for every service module found, excluding the
entry/gateway module itself (it is never a spawned peer). Prefixes come from
`derive_prefix` so they match `jac setup microservice` output. Returns an empty
dict for a monolith (no markers), which is the regression guard that keeps
non-microservice apps on the plain `jac start` path.

Accepts either an entry file (scans its directory, excludes the entry module) or
a directory (scans it, excludes nothing - the orchestrator's working-directory
fallback when it has no original entry path).
"""
def discover_sv_services(entry_file: str) -> dict[str, str] {
    entry_path = Path(entry_file);
    if entry_path.is_dir() {
        root_dir = entry_path;
        entry_stem: str = "";
    } else {
        # Path("main.jac").parent is Path(".") (the cwd), so a bare filename
        # already scans the cwd; the is_dir() guard below handles bad paths.
        root_dir = entry_path.parent;
        entry_stem: str = entry_path.stem;
    }
    if not root_dir.is_dir() {
        return {};
    }
    services: set[str] = set();

    for jac_file in sorted(root_dir.glob("*.jac")) {
        try {
            text = jac_file.read_text(encoding="utf-8");
        } except Exception {
            continue;
        }
        markers = scan_markers(text, str(jac_file));
        if markers is None {
            continue;
        }
        for target in markers.sv_import_targets {
            services.add(target);
        }
        if markers.is_service {
            services.add(jac_file.stem);
        }
    }

    # The entry module is the gateway/client host, never a spawned peer.
    services.discard(entry_stem);

    routes: dict[str, str] = {};
    for name in sorted(services) {
        routes[name] = derive_prefix(name);
    }
    return routes;
}
