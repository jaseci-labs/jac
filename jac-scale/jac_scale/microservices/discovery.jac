"""Zero-config discovery of microservices from `sv import` / `to sv:` markers.

`jac start <entry>.jac` should "just work" for an app that splits itself into
services with `sv import`, without requiring a `[plugins.scale.microservices]`
config block. This module scans the entry file's directory for the two source
markers that define the service graph:

  - a file containing a real `to sv:` statement declares itself a service, and
  - `sv import from <module> { ... }` references another module as a service.

It returns a default routes map `{module_name: prefix}` covering the union of
both (prefixes via `derive_prefix`, so they match what `jac setup microservice`
would write), which the orchestrator turns into a service registry.

v0 limitation: the scan is non-recursive over the entry file's own directory.
Services reachable only through transitive imports in nested subpackages are not
detected; declare those explicitly with `jac setup microservice`.
"""

import re;
import from pathlib { Path }
import from jac_scale.microservices.setup { derive_prefix }

# Real statements only: `sv import from <module>` and `to sv:`. Both are
# matched against comment/docstring-stripped lines so the example apps'
# docstrings (which literally contain "sv import from ...") never count.
glob _SV_IMPORT_RE = re.compile(r"^sv\s+import\s+from\s+([A-Za-z_][A-Za-z0-9_]*)");
glob _TO_SV_RE = re.compile(r"^to\s+sv\s*:");
glob _DOC_DELIMS = ('"""', "'''");


"""Yield source lines with `#` comments and `\"\"\"`/`'''` docstrings removed.

Tracks a single open docstring delimiter at a time; this is a line-oriented
heuristic, not a full lexer, but it is enough to keep the marker regexes from
matching documentation text (the fixtures embed `sv import from ...` inside
their module docstrings).
"""
def _code_lines(text: str) -> list[str] {
    out: list[str] = [];
    in_doc: bool = False;
    doc_delim: str = "";
    for raw in text.splitlines() {
        line = raw.strip();
        if in_doc {
            # Inside a docstring: only a matching closing delimiter ends it.
            # Use startswith (mirroring the opening check) so an embedded
            # `"""`/`'''` in the body (e.g. a code example) does not close
            # the docstring early and leak its remaining lines to the marker
            # regexes as false-positive services.
            if line.startswith(doc_delim) {
                in_doc = False;
            }
            continue;
        }
        if not line or line.startswith("#") {
            continue;
        }
        for delim in _DOC_DELIMS {
            if line.startswith(delim) {
                rest = line[len(delim):];
                if delim in rest {
                    # Opens and closes on the same line (single-line docstring).
                    line = "";
                } else {
                    in_doc = True;
                    doc_delim = delim;
                    line = "";
                }
                break;
            }
        }
        if line {
            out.append(line);
        }
    }
    return out;
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
    enabled: bool | None,
    is_sv_sibling: bool,
    scale_flag: bool,
    has_services: bool
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
"""
def discover_sv_services(entry_file: str) -> dict[str, str] {
    entry_path = Path(entry_file);
    # Accept either an entry file (scan its directory, exclude the entry
    # module) or a directory (scan it, exclude nothing). The directory form
    # lets the orchestrator fall back to a working-directory scan when it is
    # called without the original entry path.
    if entry_path.is_dir() {
        root_dir = entry_path;
        entry_stem: str = "";
    } else {
        root_dir = entry_path.parent;
        if not str(root_dir) {
            root_dir = Path(".");
        }
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
        is_service_file: bool = False;
        for line in _code_lines(text) {
            if _TO_SV_RE.match(line) {
                is_service_file = True;
            }
            m = _SV_IMPORT_RE.match(line);
            if m {
                services.add(m.group(1));
            }
        }
        if is_service_file {
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
