"""Project-kind resolution and `jac run` dispatch planning.

A Jac project is one of a fixed set of *kinds* (CLI tool, native app, API
service, full-stack app, library, package, ...). `jac run`, in the presence of
a `jac.toml`, resolves the kind and dispatches to the natural primary action:
execute it, serve it, or build its artifact. The kind is taken from
`[project] kind` when set, otherwise inferred from the entry-point's codespace.

This module is pure planning: it returns a `RunPlan` describing what should
happen. The CLI `run` command consumes the plan and either prints it
(`--show`) or executes it by delegating to the underlying primitive command
(`run` / `start` / `nacompile` / `bundle`).
"""

import os;
import from jaclang.project.config { JacConfig }

# The canonical project-kind table: the single source of truth shared by
# `jac create` (which template/entry-point to scaffold, which plugin a kind
# needs) and `jac run` (which plugin a kind needs to dispatch). Each entry:
#   entry  -- the scaffolded entry-point filename (its codespace suffix)
#   plugin -- the pip package that must be installed for the kind ("" = core)
# Insertion order is the canonical kind order (used in error messages).
glob KIND_SPECS: dict[str, dict[str, str]] = {
         "cli": {"entry": "main.jac", "plugin": ""},
         "native-app": {"entry": "main.na.jac", "plugin": ""},
         "native-binary": {"entry": "main.na.jac", "plugin": ""},
         "shared-library": {"entry": "main.na.jac", "plugin": ""},
         "api-service": {"entry": "main.sv.jac", "plugin": ""},
         "microservices": {"entry": "main.sv.jac", "plugin": ""},
         "pypi-package": {"entry": "lib.jac", "plugin": ""},
         "npm-package": {"entry": "lib.jac", "plugin": ""},
         "fullstack": {"entry": "main.jac", "plugin": "jac-client"},
         "client": {"entry": "main.jac", "plugin": "jac-client"},
         "desktop": {"entry": "main.jac", "plugin": "jac-desktop"},
         "mobile": {"entry": "main.jac", "plugin": "jac-client"}
     },
     # The canonical set of project kinds, derived from KIND_SPECS so the two never
     # drift. Mirrors the jac-project-kinds skill.
     VALID_KINDS: list[str] = list(KIND_SPECS.keys());

"""The pip package a kind requires to run/scaffold ("" when core-supported)."""
def kind_required_plugin(kind: str) -> str {
    return KIND_SPECS.get(kind, {}).get("plugin", "");
}

"""The canonical entry-point filename `jac create` scaffolds for a kind."""
def kind_entry(kind: str) -> str {
    return KIND_SPECS.get(kind, {}).get("entry", "main.jac");
}

"""A resolved plan describing what `jac run` should do for a project.

`action` is one of "execute" (run the entry), "serve" (stand up a server), or
"build" (produce an artifact). `verb` is the underlying primitive command the
dispatcher delegates to (run / start / nacompile / bundle / build). `flags`
are the primitive-specific options. `requires_plugin` names a plugin that must
be installed for the action to actually run (empty when core-supported).
"""
obj RunPlan {
    has kind: str,
        action: str,
        verb: str,
        entry_path: str,
        flags: dict,
        summary: str,
        requires_plugin: str = "";

    """Render the equivalent primitive command line (for --show / docs)."""
    def command_line -> str {
        parts = ["jac", self.verb];
        if self.entry_path {
            parts.append(os.path.basename(self.entry_path));
        }
        for (k, v) in self.flags.items() {
            flag = f"--{k.replace('_', '-')}";
            if isinstance(v, bool) {
                if v {
                    parts.append(flag);
                }
            } else {
                parts.append(flag);
                parts.append(str(v));
            }
        }
        return " ".join(parts);
    }
}

"""Return True if `kind` is a recognized project kind."""
def is_valid_kind(kind: str) -> bool {
    return kind in VALID_KINDS;
}

"""Strip the codespace suffix from an entry filename, leaving the bare stem."""
def _entry_stem(path: str) -> str {
    name = os.path.basename(path);
    for suf in [".na.jac", ".sv.jac", ".cl.jac", ".jac", ".py"] {
        if name.endswith(suf) {
            return name[:-len(suf)];
        }
    }
    return name;
}

"""True when the project opts into the client (cl) codespace via plugin/deps."""
def _has_client(config: JacConfig) -> bool {
    # Strongest signal: jac-client is a project dependency (pip package name).
    if "jac-client" in config.dependencies {
        return True;
    }
    # The client plugin is configured: `[plugins.client]`. The plugins dict is
    # keyed by the short plugin name (the codebase reads it as
    # `get_plugin_config('client')`), not the package name `jac-client`.
    if "client" in config.plugins {
        return True;
    }
    # Explicitly enabled. Entries are plugin identifiers like `jac-client:cli`
    # or `jac-client:*` (package:plugin), so match by package prefix rather
    # than the bare package name.
    for ident in config.plugins_config.enabled {
        if ident == "jac-client" or ident.startswith("jac-client:") {
            return True;
        }
    }
    return False;
}

"""Resolve the project's entry-point to an existing absolute file path.

Uses `[project] entry-point` (default `main.jac`). When that literal path does
not exist, retries the stem against every codespace suffix so a project whose
entry is e.g. `main.na.jac` still resolves even if `entry-point` is unset or
stale. Returns "" when nothing resolves.
"""
def resolve_entry(config: JacConfig, project_root: str) -> str {
    ep = config.project.entry_point or "main.jac";
    direct = ep if os.path.isabs(ep) else os.path.join(project_root, ep);
    if os.path.isfile(direct) {
        return os.path.abspath(direct);
    }
    stem = _entry_stem(ep);
    # Search the entry-point's own directory for a sibling codespace file. Note
    # os.path.join drops `project_root` when `os.path.dirname(ep)` is absolute --
    # which is the intended behavior: an absolute entry-point is searched at its
    # own location, while a relative one stays anchored under the project root.
    base = os.path.join(project_root, os.path.dirname(ep), stem);
    for suf in [".jac", ".na.jac", ".sv.jac", ".cl.jac", ".py"] {
        cand = base + suf;
        if os.path.isfile(cand) {
            return os.path.abspath(cand);
        }
    }
    return "";
}

"""Resolve the project kind: explicit `[project] kind`, else inferred.

Inference uses the entry-point's codespace suffix and client-plugin presence:
`.na.jac` -> native-app, `.sv.jac` -> api-service, `.cl.jac` -> fullstack, a
plain `.jac` -> fullstack when jac-client is configured else cli.
"""
def resolve_project_kind(config: JacConfig, entry_path: str) -> str {
    explicit = config.project.kind.strip() if config.project.kind else "";
    if explicit {
        return explicit;
    }
    if entry_path.endswith(".na.jac") {
        return "native-app";
    }
    if entry_path.endswith(".sv.jac") {
        return "api-service";
    }
    if entry_path.endswith(".cl.jac") {
        return "fullstack";
    }
    if _has_client(config) {
        return "fullstack";
    }
    return "cli";
}

"""Serve flags for a plan, carrying the project's [serve] port when non-default.

Keeps `jac run --show` clean for the common case (default 8000) while ensuring
a custom `[serve] port` from jac.toml is forwarded to `start`.
"""
def _serve_flags(config: JacConfig, base: dict) -> dict {
    if config.serve.port != 8000 {
        base["port"] = config.serve.port;
    }
    return base;
}

"""Build the RunPlan for a project, or None if no entry/kind can be resolved.

The caller validates `config.project.kind` against `is_valid_kind` first so an
unknown explicit kind produces a precise error rather than a silent default.
"""
def plan_project_run(config: JacConfig, project_root: str) -> (RunPlan | None) {
    entry_path = resolve_entry(config, project_root);
    kind = resolve_project_kind(config, entry_path);
    # pypi/npm bundle the whole project and need no runnable entry.
    needs_entry = kind not in ["pypi-package", "npm-package"];
    if needs_entry and not entry_path {
        return None;
    }
    stem = _entry_stem(entry_path) if entry_path else config.project.name;
    if kind in ["cli", "native-app"] {
        return RunPlan(
            kind=kind,
            action="execute",
            verb="run",
            entry_path=entry_path,
            flags={},
            summary=f"Execute {kind} entry-point {os.path.basename(entry_path)}"
        );
    }
    if kind == "native-binary" {
        out = os.path.join(project_root, "dist", stem);
        return RunPlan(
            kind=kind,
            action="build",
            verb="nacompile",
            entry_path=entry_path,
            flags={"output": out},
            summary=f"Build native binary -> {out}"
        );
    }
    if kind == "shared-library" {
        return RunPlan(
            kind=kind,
            action="build",
            verb="nacompile",
            entry_path=entry_path,
            flags={"shared": True},
            summary="Build shared library (.so / .dylib / .dll)"
        );
    }
    if kind == "api-service" {
        return RunPlan(
            kind=kind,
            action="serve",
            verb="start",
            entry_path=entry_path,
            flags=_serve_flags(config, {"no_client": True}),
            summary="Serve headless API service"
        );
    }
    if kind == "microservices" {
        return RunPlan(
            kind=kind,
            action="serve",
            verb="start",
            entry_path=entry_path,
            flags=_serve_flags(config, {}),
            summary="Serve microservice consumer (auto-starts providers)"
        );
    }
    if kind == "fullstack" {
        return RunPlan(
            kind=kind,
            action="serve",
            verb="start",
            entry_path=entry_path,
            flags=_serve_flags(config, {"dev": True}),
            summary="Serve full-stack app with client (dev mode)",
            requires_plugin=kind_required_plugin(kind)
        );
    }
    if kind == "client" {
        return RunPlan(
            kind=kind,
            action="serve",
            verb="start",
            entry_path=entry_path,
            flags=_serve_flags(config, {}),
            summary="Serve client-only app as a static page (no backend)",
            requires_plugin=kind_required_plugin(kind)
        );
    }
    if kind == "desktop" {
        return RunPlan(
            kind=kind,
            action="serve",
            verb="start",
            entry_path=entry_path,
            flags={"client": "desktop"},
            summary="Run desktop app (OS webview)",
            requires_plugin=kind_required_plugin(kind)
        );
    }
    if kind == "pypi-package" {
        return RunPlan(
            kind=kind,
            action="build",
            verb="bundle",
            entry_path="",
            flags={"target": "wheel"},
            summary="Build PyPI wheel into dist/"
        );
    }
    if kind == "npm-package" {
        return RunPlan(
            kind=kind,
            action="build",
            verb="bundle",
            entry_path="",
            flags={"target": "npm"},
            summary="Build npm package into dist/"
        );
    }
    if kind == "mobile" {
        return RunPlan(
            kind=kind,
            action="build",
            verb="build",
            entry_path=entry_path,
            flags={"client": "mobile"},
            summary="Build mobile app bundle",
            requires_plugin=kind_required_plugin(kind)
        );
    }
    return None;
}
