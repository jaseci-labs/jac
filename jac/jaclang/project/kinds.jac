import os;
import from jaclang.project.config { JacConfig }
import from jaclang.jac0core.ext_registry { base_stem, codespace_of, MODULE_SUFFIXES }

glob KIND_SPECS: dict[str, dict[str, str]] = {
         "cli": {"entry": "main.jac", "plugin": ""},
         "native-app": {"entry": "main.na.jac", "plugin": ""},
         "native-binary": {"entry": "main.na.jac", "plugin": ""},
         "shared-library": {"entry": "main.na.jac", "plugin": ""},
         "api-service": {"entry": "main.sv.jac", "plugin": ""},
         "microservices": {"entry": "main.sv.jac", "plugin": ""},
         "pypi-package": {"entry": "lib.jac", "plugin": ""},
         "npm-package": {"entry": "lib.jac", "plugin": ""},
         "fullstack": {"entry": "main.jac", "plugin": ""},
         "client": {"entry": "main.jac", "plugin": ""},
         "desktop": {"entry": "main.jac", "plugin": ""},
         "mobile": {"entry": "main.jac", "plugin": ""}
     },
     VALID_KINDS: list[str] = list(KIND_SPECS.keys());

def kind_required_plugin(kind: str) -> str {
    return KIND_SPECS.get(kind, {}).get("plugin", "");
}

def kind_entry(kind: str) -> str {
    return KIND_SPECS.get(kind, {}).get("entry", "main.jac");
}

obj RunPlan {
    has kind: str,
        action: str,
        verb: str,
        entry_path: str,
        flags: dict,
        summary: str,
        requires_plugin: str = "";

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

def is_valid_kind(kind: str) -> bool {
    return kind in VALID_KINDS;
}

def _entry_stem(path: str) -> str {
    return base_stem(path);
}

def _has_client(config: JacConfig) -> bool {
    if "jac-client" in config.dependencies {
        return True;
    }

    if "client" in config.plugins {
        return True;
    }

    for ident in config.plugins_config.enabled {
        if ident == "jac-client" or ident.startswith("jac-client:") {
            return True;
        }
    }
    return False;
}

def resolve_entry(config: JacConfig, project_root: str) -> str {
    ep = config.project.entry_point or "main.jac";
    direct = ep if os.path.isabs(ep) else os.path.join(project_root, ep);
    if os.path.isfile(direct) {
        return os.path.abspath(direct);
    }
    stem = _entry_stem(ep);

    base = os.path.join(project_root, os.path.dirname(ep), stem);
    for suf in list(MODULE_SUFFIXES) + [".py"] {
        cand = base + suf;
        if os.path.isfile(cand) {
            return os.path.abspath(cand);
        }
    }
    return "";
}

def resolve_project_kind(config: JacConfig, entry_path: str) -> str {
    explicit = config.project.kind.strip() if config.project.kind else "";
    if explicit {
        return explicit;
    }
    entry_codespace = codespace_of(entry_path);
    if (entry_codespace == 'native') {
        return "native-app";
    }
    if (entry_codespace == 'server') {
        return "api-service";
    }
    if (entry_codespace == 'client') {
        return "fullstack";
    }
    if _has_client(config) {
        return "fullstack";
    }
    return "cli";
}

def _serve_flags(config: JacConfig, base: dict) -> dict {
    if config.serve.port != 8000 {
        base["port"] = config.serve.port;
    }
    return base;
}

def plan_project_run(config: JacConfig, project_root: str) -> (RunPlan | None) {
    entry_path = resolve_entry(config, project_root);
    kind = resolve_project_kind(config, entry_path);

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
