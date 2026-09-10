import os;
import from jaclang.jac0core.ext_registry { base_stem }
import from jaclang.project.apps { AppConfig, implicit_app }
import from jaclang.project.config { JacConfig }

import from jaclang.project.app_kinds {
    KindSpec,
    KIND_SPECS,
    VALID_KINDS,
    UI_DOM,
    UI_MOBUI,
    MOBILE_PLATFORMS,
    kind_spec,
    kind_entry,
    is_valid_kind,
    kind_ui,
    kind_has_client,
    kind_is_mobui
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
    path = app.entry_path(project_root);
    return path if os.path.isfile(path) else "";
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
        stem = base_stem(entry_path) if entry_path else app.name;
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
