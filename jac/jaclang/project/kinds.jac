import os;
import from jaclang.project.apps { AppConfig, implicit_app }
import from jaclang.project.config { JacConfig }
import from jaclang.jac0core.ext_registry { base_stem, MODULE_SUFFIXES }

obj KindSpec {
    has name: str,
        description: str,
        `entry: str,
        action: str,
        verb: str,
        summary: str,
        flags: dict[str, any] = {},
        needs_entry: bool = True,
        output_dir: str = "",
        codespace: str = "",
        ui: str = "",
        has_server: bool = False;
}

glob KIND_SPECS: dict[str, KindSpec] = {
         spec.name: spec
         for spec in [
             KindSpec(
                 name="cli",
                 description="Command-line Jac project",
                 `entry="main.jac",
                 action="execute",
                 verb="run",
                 summary="Execute {kind} entry-point {entry}"
             ),
             KindSpec(
                 name="cli-native",
                 description="Natively-compiled Jac program (compiled and run)",
                 `entry="main.jac",
                 action="execute",
                 verb="run",
                 summary="Execute {kind} entry-point {entry}"
             ),
             KindSpec(
                 name="native-binary",
                 description="Natively-compiled standalone binary (built into dist/)",
                 `entry="main.jac",
                 action="build",
                 verb="native",
                 summary="Build native binary -> {output}",
                 output_dir="dist"
             ),
             KindSpec(
                 name="native-lib",
                 description="Natively-compiled shared library (.so / .dylib / .dll)",
                 `entry="main.jac",
                 action="build",
                 verb="native",
                 summary="Build shared library (.so / .dylib / .dll)",
                 flags={"lib": True}
             ),
             KindSpec(
                 name="service",
                 description="Headless Jac API service (server walkers, no client)",
                 `entry="main.jac",
                 action="serve",
                 verb="run",
                 summary="Serve headless API service",
                 flags={"no_client": True},
                 has_server=True
             ),
             KindSpec(
                 name="service-mesh",
                 description="Jac microservice (server walkers; colocates its service apps)",
                 `entry="main.jac",
                 action="serve",
                 verb="run",
                 summary="Serve microservice consumer (colocates its service apps)",
                 has_server=True
             ),
             KindSpec(
                 name="py-package",
                 description="Distributable Python package (built into a wheel)",
                 `entry="lib.jac",
                 action="build",
                 verb="build",
                 summary="Build PyPI wheel into dist/",
                 flags={"as": "wheel"},
                 needs_entry=False
             ),
             KindSpec(
                 name="js-package",
                 description="Distributable npm package (built into a tarball)",
                 `entry="lib.jac",
                 action="build",
                 verb="build",
                 summary="Build npm package into dist/",
                 flags={"as": "npm"},
                 needs_entry=False,
                 codespace="client",
                 ui="dom"
             ),
             KindSpec(
                 name="web-app",
                 description="Minimal full-stack Jac app (server walkers + client UI)",
                 `entry="main.jac",
                 action="serve",
                 verb="run",
                 summary="Serve full-stack app with client (dev mode)",
                 flags={"dev": True},
                 ui="dom",
                 has_server=True
             ),
             KindSpec(
                 name="web-static",
                 description="Client-only Jac app (runs in the browser, no backend)",
                 `entry="main.jac",
                 action="serve",
                 verb="run",
                 summary="Serve client-only app as a static page (no backend)",
                 ui="dom"
             ),
             KindSpec(
                 name="desktop",
                 description="Jac desktop app (OS webview + native build)",
                 `entry="main.jac",
                 action="serve",
                 verb="run",
                 summary="Run desktop app (OS webview)",
                 ui="dom"
             ),
             KindSpec(
                 name="mobile",
                 description="Jac mobile app (mobUI over React Native)",
                 `entry="main.jac",
                 action="build",
                 verb="build",
                 summary="Build mobile app bundle",
                 ui="mobui"
             )
         ]
     },
     VALID_KINDS: list[str] = list(KIND_SPECS.keys()),
     UI_DOM: str = "dom",
     UI_MOBUI: str = "mobui",
     MOBILE_PLATFORMS: list[str] = ["android", "ios", "web"];

def kind_spec(kind: str) -> KindSpec | None {
    return KIND_SPECS.get(kind);
}

def kind_entry(kind: str) -> str {
    spec = KIND_SPECS.get(kind);
    return spec.`entry if spec else "main.jac";
}

def is_valid_kind(kind: str) -> bool {
    return kind in KIND_SPECS;
}

def kind_ui(kind: str) -> str {
    spec = KIND_SPECS.get(kind);
    return spec.ui if spec else "";
}

def kind_has_client(kind: str) -> bool {
    return bool(kind_ui(kind));
}

def kind_is_mobui(kind: str) -> bool {
    return kind_ui(kind) == UI_MOBUI;
}

obj RunPlan {
    has spec: KindSpec,
        entry_path: str,
        flags: dict[str, any],
        summary: str,
        app: str = "";

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
        parts = ["jac", "build", "--native"]
            if self.verb == "native"
            else ["jac", self.verb];
        if self.app {
            parts.append(self.app);
        } elif self.entry_path {
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

def resolve_entry(config: JacConfig, project_root: str, app: AppConfig) -> str {
    ep = (
        app.entry_point
        or (config.project.entry_point if app.implicit else "")
        or kind_entry(app.kind)
    );
    base_dir = app.root_dir(project_root) or os.path.abspath(project_root);
    direct = ep if os.path.isabs(ep) else os.path.join(base_dir, ep);
    if os.path.isfile(direct) {
        return os.path.abspath(direct);
    }
    stem = _entry_stem(ep);

    base = os.path.join(base_dir, os.path.dirname(ep), stem);
    for suf in list(MODULE_SUFFIXES) + [".py"] {
        cand = base + suf;
        if os.path.isfile(cand) {
            return os.path.abspath(cand);
        }
    }
    return "";
}

def resolve_app_kind(config: JacConfig, app: AppConfig, entry_path: str) -> str {
    explicit = app.kind.strip() if app.kind else "";
    if explicit {
        return explicit;
    }
    if not app.implicit {
        return "cli";
    }
    project_kind = config.project.kind.strip() if config.project.kind else "";
    if project_kind {
        return project_kind;
    }
    import from jaclang.compiler.placement.placement_facts { pinned_module_space }
    entry_pin = pinned_module_space(entry_path) if entry_path else '';
    if (entry_pin == 'native') {
        return "cli-native";
    }
    if (entry_pin == 'client') {
        return "web-app";
    }
    if _has_client(config) {
        return "web-app";
    }
    return "cli";
}

def plan_app_run(
    config: JacConfig, project_root: str, app: AppConfig, entry_override: str = ""
) -> RunPlan {
    eff = config.effective_for_app(app.name) if app.name in config.apps else config;
    entry_path = (
        os.path.abspath(entry_override)
            if entry_override
            else resolve_entry(eff, project_root, app)
    );
    kind = resolve_app_kind(eff, app, entry_path);
    spec = KIND_SPECS.get(kind);
    if spec is None {
        raise ValueError(
            f"App '{app.name}' has unknown kind '{kind}'; expected one of "
            f"{', '.join(VALID_KINDS)}"
        );
    }
    if spec.needs_entry and not entry_path {
        raise ValueError(
            f"App '{app.name}' ({spec.name}) has no entry file; expected "
            f"{app.entry_path(project_root)}"
        );
    }
    if not spec.needs_entry and not entry_override {
        entry_path = "";
    }

    flags = dict(spec.flags);
    output = "";
    if spec.output_dir {
        stem = _entry_stem(entry_path) if entry_path else app.name;
        out_dir = (
            os.path.join(project_root, spec.output_dir)
                if app.implicit
                else os.path.join(project_root, spec.output_dir, app.name)
        );
        output = os.path.join(out_dir, stem);
        flags["output"] = output;
    }
    if app.platform {
        flags["platform"] = app.platform;
    }

    if spec.action == "serve" and eff.serve.port != 8000 {
        flags["port"] = eff.serve.port;
    }

    return RunPlan(
        spec=spec,
        entry_path=entry_path,
        flags=flags,
        summary=spec.summary.format(
            kind=spec.name, `entry=os.path.basename(entry_path), output=output
        ),
        app="" if app.implicit else app.name
    );
}

def plan_workspace(config: JacConfig, project_root: str) -> list[RunPlan] {
    apps = list(config.apps.values()) or [implicit_app(config)];
    return [plan_app_run(config, project_root, app) for app in apps];
}
