import os;
import from jaclang.project.config { JacConfig }
import from jaclang.jac0core.ext_registry { base_stem, codespace_of, MODULE_SUFFIXES }

obj KindSpec {
    has name: str,
        description: str,
        entry: str,
        action: str,
        verb: str,
        summary: str,
        flags: dict[str, any] = {},
        needs_entry: bool = True,
        output_dir: str = "";
}

glob KIND_SPECS: dict[str, KindSpec] = {
         spec.name: spec
         for spec in [
             KindSpec(
                 name="cli",
                 description="Command-line Jac project",
                 entry="main.jac",
                 action="execute",
                 verb="run",
                 summary="Execute {kind} entry-point {entry}"
             ),
             KindSpec(
                 name="cli-native",
                 description="Natively-compiled Jac program (compiled and run)",
                 entry="main.na.jac",
                 action="execute",
                 verb="run",
                 summary="Execute {kind} entry-point {entry}"
             ),
             KindSpec(
                 name="native-binary",
                 description="Natively-compiled standalone binary (built into dist/)",
                 entry="main.na.jac",
                 action="build",
                 verb="nacompile",
                 summary="Build native binary -> {output}",
                 output_dir="dist"
             ),
             KindSpec(
                 name="native-lib",
                 description="Natively-compiled shared library (.so / .dylib / .dll)",
                 entry="main.na.jac",
                 action="build",
                 verb="nacompile",
                 summary="Build shared library (.so / .dylib / .dll)",
                 flags={"shared": True}
             ),
             KindSpec(
                 name="service",
                 description="Headless Jac API service (server walkers, no client)",
                 entry="main.sv.jac",
                 action="serve",
                 verb="start",
                 summary="Serve headless API service",
                 flags={"no_client": True}
             ),
             KindSpec(
                 name="service-mesh",
                 description="Jac microservice (server walkers; auto-starts providers)",
                 entry="main.sv.jac",
                 action="serve",
                 verb="start",
                 summary="Serve microservice consumer (auto-starts providers)"
             ),
             KindSpec(
                 name="py-package",
                 description="Distributable Python package (built into a wheel)",
                 entry="lib.jac",
                 action="build",
                 verb="build",
                 summary="Build PyPI wheel into dist/",
                 flags={"as": "wheel"},
                 needs_entry=False
             ),
             KindSpec(
                 name="js-package",
                 description="Distributable npm package (built into a tarball)",
                 entry="lib.jac",
                 action="build",
                 verb="build",
                 summary="Build npm package into dist/",
                 flags={"as": "npm"},
                 needs_entry=False
             ),
             KindSpec(
                 name="web-app",
                 description="Minimal full-stack Jac app (server walkers + client UI)",
                 entry="main.jac",
                 action="serve",
                 verb="start",
                 summary="Serve full-stack app with client (dev mode)",
                 flags={"dev": True}
             ),
             KindSpec(
                 name="web-static",
                 description="Client-only Jac app (runs in the browser, no backend)",
                 entry="main.jac",
                 action="serve",
                 verb="start",
                 summary="Serve client-only app as a static page (no backend)"
             ),
             KindSpec(
                 name="desktop",
                 description="Jac desktop app (OS webview + nacompile)",
                 entry="main.jac",
                 action="serve",
                 verb="start",
                 summary="Run desktop app (OS webview)",
                 flags={"client": "desktop"}
             ),
             KindSpec(
                 name="mobile",
                 description="Jac mobile client app (Capacitor + Vite)",
                 entry="main.jac",
                 action="build",
                 verb="build",
                 summary="Build mobile app bundle",
                 flags={"client": "mobile"}
             )
         ]
     },
     VALID_KINDS: list[str] = list(KIND_SPECS.keys());

def kind_spec(kind: str) -> KindSpec | None {
    return KIND_SPECS.get(kind);
}

def kind_entry(kind: str) -> str {
    spec = KIND_SPECS.get(kind);
    return spec.entry if spec else "main.jac";
}

def is_valid_kind(kind: str) -> bool {
    return kind in KIND_SPECS;
}

obj RunPlan {
    has spec: KindSpec,
        entry_path: str,
        flags: dict[str, any],
        summary: str;

    has kind: str {
        getter {
            return self.spec.name;
        }
    }

    has action: str {
        getter {
            return self.spec.action;
        }
    }

    has verb: str {
        getter {
            return self.spec.verb;
        }
    }

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
        return "cli-native";
    }
    if (entry_codespace == 'server') {
        return "service";
    }
    if (entry_codespace == 'client') {
        return "web-app";
    }
    if _has_client(config) {
        return "web-app";
    }
    return "cli";
}

def plan_project_run(config: JacConfig, project_root: str) -> (RunPlan | None) {
    entry_path = resolve_entry(config, project_root);
    spec = KIND_SPECS.get(resolve_project_kind(config, entry_path));
    if spec is None {
        return None;
    }
    if spec.needs_entry and not entry_path {
        return None;
    }
    if not spec.needs_entry {
        entry_path = "";
    }

    flags = dict(spec.flags);
    output = "";
    if spec.output_dir {
        stem = _entry_stem(entry_path) if entry_path else config.project.name;
        output = os.path.join(project_root, spec.output_dir, stem);
        flags["output"] = output;
    }

    if spec.action == "serve" and config.serve.port != 8000 {
        flags["port"] = config.serve.port;
    }

    return RunPlan(
        spec=spec,
        entry_path=entry_path,
        flags=flags,
        summary=spec.summary.format(
            kind=spec.name, entry=os.path.basename(entry_path), output=output
        )
    );
}
