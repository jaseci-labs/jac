"""Zero-config service discovery for microservice mode.

A project is a microservice app when it ships sibling `.jac` modules that
expose server endpoints - i.e. a module with a `to sv:` section (or an
explicit `sv def:pub` / `sv walker:pub` at module scope). Each such module
is a service; the project entry-point is the gateway and is never itself a
service. The gateway-facing route prefix is derived by convention
(`derive_prefix`), identical to what `jac setup microservice` would write.

This lets `[plugins.scale.microservices]` and its `routes` table be optional:
`jac start main.jac` (local) and `jac start main.jac --scale` (K8s) both
discover the same service set from source, with or without an explicit
config block. An explicit routes block always wins - discovery only fills
the gap when none is declared.

Discovery is pure and memoized per (project_root, entry) so the hot config
path - `get_microservices_config()` is read on every sv RPC for the timeout -
parses the source tree at most once per process.
"""

import os;
import logging;
import from pathlib { Path }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { SymbolAccess, Tokens as Tok }
import from jac_scale.microservices.setup {
    scan_jac_files,
    derive_module_name,
    derive_prefix
}

glob _logger = logging.getLogger(__name__),
     # {cache_key: {module_name: prefix}}. cache_key folds project root + entry so
     # a process that deploys several projects (tests) does not cross-pollinate.
     _discovery_cache: dict[str, dict[str, str]] = {};


"""Parse a single .jac file to its AST (no semantic analysis). None on any
parse/read error - a malformed sibling must not break discovery for the
rest of the project."""
def _parse_module(file_path: str) -> any {
    import from jaclang.jac0core.compiler { JacCompiler }
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.helpers { read_file_with_encoding }
    try {
        src_text = read_file_with_encoding(file_path);
        return JacCompiler().parse_str(
            source_str=src_text, file_path=file_path, target_program=JacProgram()
        );
    } except Exception as e {
        _logger.debug(f"discovery: could not parse {file_path}: {e}");
        return None;
    }
}


"""True if a `to sv:` block (or sv-prefixed element) body exposes at least
one public ability or public walker - the HTTP-callable endpoints that make
a module a service."""
def _block_exposes_endpoint(body: any) -> bool {
    for el in body {
        if isinstance(el, uni.Ability) and el?.access_type == SymbolAccess.PUBLIC {
            return True;
        }
        if (
            isinstance(el, uni.Archetype)
            and el?.arch_kind == "walker"
            and el?.access_type == SymbolAccess.PUBLIC
        ) {
            return True;
        }
    }
    return False;
}


"""True if `mod` declares server endpoints intended for the gateway.

The intentional marker is an explicit server context: a `to sv:` ServerBlock
(implicit block) or a top-level element carrying the `sv` prefix token. We do
NOT treat a plain `def:pub` in a default-context `.jac` as a service marker -
that would misclassify every ordinary server module (and the gateway itself)
as a microservice. Only an explicit `sv` intent counts."""
def _module_is_service(mod: any) -> bool {
    if mod is None or not mod?.body {
        return False;
    }
    for item in mod.body {
        if isinstance(item, uni.ServerBlock) and _block_exposes_endpoint(item.body) {
            return True;
        }
        # Explicit `sv def:pub` / `sv walker:pub` written as a single
        # prefixed statement at module scope (no `to sv:` header). The
        # parser left-attaches a KW_SERVER token onto the statement's kids.
        if _block_exposes_endpoint([item]) {
            for k in (item.kid or []) {
                if isinstance(k, uni.Token) and k?.name == Tok.KW_SERVER {
                    return True;
                }
            }
        }
    }
    return False;
}


"""Resolve the project entry-point (the gateway) so it is excluded from the
service set. Reads `[project].entry-point`; falls back to `main.jac`."""
def _resolve_entry_stem(project_root: str, entry_file: str | None) -> str {
    if entry_file {
        return Path(entry_file).stem;
    }
    try {
        import from jac_scale.config_loader { get_scale_config }
        cfg = get_scale_config(Path(project_root)).get_jac_config();
        ep = str(getattr(cfg, "entry_point", "") or "main.jac");
        return Path(ep).stem;
    } except Exception as e {
        _logger.debug(f"discovery: entry-point resolution fell back to 'main': {e}");
        return "main";
    }
}


"""Discover the service modules of a project as a {module_name: prefix} map.

Scans `project_root` for `.jac` modules that expose server endpoints,
excludes the entry-point (gateway) and client/impl/native sources, and maps
each surviving module name to its conventional gateway prefix. Memoized per
(project_root, entry)."""
def discover_services(
    project_root: str = ".", entry_file: str | None = None
) -> dict[str, str] {
    abs_root = os.path.abspath(project_root);
    entry_stem = _resolve_entry_stem(project_root, entry_file);
    cache_key = f"{abs_root}::{entry_stem}";
    if cache_key in _discovery_cache {
        return dict(_discovery_cache[cache_key]);
    }

    routes: dict[str, str] = {};
    for rel in scan_jac_files(project_root) {
        # scan_jac_files already drops build/cache dirs; here we drop the
        # codespaces that are never standalone services.
        if rel.endswith((".cl.jac", ".impl.jac", ".na.jac", ".test.jac")) {
            continue;
        }
        module_name = derive_module_name(rel);
        if module_name == entry_stem {
            continue;  # entry-point is the gateway, not a service
        }
        if module_name in routes {
            continue;
        }
        mod = _parse_module(os.path.join(abs_root, rel));
        if _module_is_service(mod) {
            routes[module_name] = derive_prefix(module_name);
        }
    }

    _discovery_cache[cache_key] = dict(routes);
    if routes {
        _logger.info(
            f"Auto-discovered {len(routes)} microservice(s) from source: "
            f"{', '.join(sorted(routes.keys()))}"
        );
    }
    return dict(routes);
}


"""Fill an ms_config's `routes` (and flip `enabled`) from source discovery
when no explicit routes table is declared.

This is the single chokepoint for zero-config activation, called from the
real start/deploy/runtime entry points (the `jac start` pre-hook, the K8s
manifest builder, the in-pod gateway + sv-registry) rather than from the
generic config reader - so a plain `get_microservices_config()` stays a pure
config read with no filesystem scan. An explicit routes block always wins;
discovery only fills the gap. Returns a new dict; the input is not mutated."""
def resolve_microservices_config(
    ms_config: dict[str, any], project_root: str = ".", entry_file: str | None = None
) -> dict[str, any] {
    out: dict[str, any] = dict(ms_config);
    if out.get("routes") {
        return out;  # explicit routes win; no discovery
    }
    discovered = discover_services(project_root, entry_file);
    if discovered {
        out["routes"] = discovered;
        out["enabled"] = True;
    }
    return out;
}


"""Clear the discovery memo (tests, or after a source change in a long-lived
process)."""
def reset_discovery_cache {
    _discovery_cache.clear();
}
