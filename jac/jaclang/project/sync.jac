"""Automatic project-environment sync (auto-install).

jac.toml is the single source of truth for a project's dependencies. This
module makes the Python side of that promise real at execution time: before a
project's code runs (`jac run` / `jac start` / `jac enter` / `jac test`), the
resolved dependency plan -- the same plan `jac install` applies, including the
capability closure -- is compared against the venv's sync marker and installed
when anything is missing.

The marker (<venv>/jac-sync.json) records the exact pip specs ever applied to
the project venv. It is maintained by PythonProvider at its install/uninstall
chokepoints and dies with the venv, so an up-to-date run costs one JSON read.

npm dependencies are deliberately not synced here: the client bundler owns
node_modules and installs it while generating package.json, the derived
manifest it is keyed to. One materialization point per ecosystem.

Opt out with `[install] auto = false` in jac.toml, or the JAC_AUTO_INSTALL
environment variable (0/false/off/no disables, 1/true/on/yes forces on),
which takes precedence over the config.
"""

import os;
import from jaclang.cli.console { console }
import from jaclang.project.config { JacConfig, get_config }


def auto_install_enabled(config: JacConfig | None = None) -> bool {
    env = os.environ.get("JAC_AUTO_INSTALL", "").strip().lower();
    if env in ("0", "false", "off", "no") {
        return False;
    }
    if env in ("1", "true", "on", "yes") {
        return True;
    }
    return config.install.auto if config is not None else True;
}


"""Bring the project venv in line with jac.toml before executing project code.

Returns True when the environment is usable (synced, already up to date, or
sync intentionally skipped); False when a sync was attempted and failed, in
which case execution should still proceed -- the environment may well be
usable and the import error, if any, will carry its own hint.
"""
def ensure_project_env(
    config: JacConfig | None = None, include_dev: bool = False
) -> bool {
    import from jaclang.project.providers {
        InstallContext,
        get_python_provider,
        resolve_plan
    }
    import from jaclang.project.pyvenv { sync_marker_satisfies }
    if config is None {
        config = get_config();
    }
    if config is None or config.project_root is None {
        return True;
    }
    if not auto_install_enabled(config) {
        return True;
    }
    try {
        plan = resolve_plan(config, include_dev=include_dev);
    } except Exception as e {
        console.warning(f"Could not resolve project dependencies: {e}");
        return False;
    }
    python_deps = plan.for_ecosystem("python");
    if not python_deps {
        return True;
    }
    python = get_python_provider();
    required = python.specs_for(python_deps);
    if sync_marker_satisfies(config.get_venv_dir(), required) {
        return True;
    }
    console.info(
        f"Installing project dependencies from jac.toml "
        f"({len(required)} package(s))..."
    );
    if python.install_all(config, python_deps, InstallContext()) {
        return True;
    }
    console.warning(
        "Dependency sync failed; continuing with the existing environment. "
        "Run 'jac install' to retry, or set JAC_AUTO_INSTALL=0 to silence "
        "auto-install."
    );
    return False;
}


"""Suggest the jac-install fix for a ModuleNotFoundError raised by project code."""
def module_not_found_hint(exc: BaseException | None) -> str | None {
    found: ModuleNotFoundError | None = None;
    cur = exc;
    depth = 0;
    while cur is not None and depth < 8 {
        if isinstance(cur, ModuleNotFoundError) {
            found = cur;
            break;
        }
        cur = cur.__cause__ or cur.__context__;
        depth += 1;
    }
    if found is None or not found.name {
        return None;
    }
    config = get_config();
    if config is None {
        return None;
    }
    top = found.name.split(".")[0];
    wanted = top.lower().replace("_", "-");
    declared: set[str] = set();
    for section in [config.dependencies, config.dev_dependencies] {
        for name in section.keys() {
            base = name[:name.index("[")] if "[" in name else name;
            declared.add(base.strip().lower().replace("_", "-"));
        }
    }
    for name in config.git_dependencies.keys() {
        declared.add(name.strip().lower().replace("_", "-"));
    }
    if wanted in declared {
        return (
            f"'{top}' is declared in jac.toml but missing from the project "
            f"venv — run 'jac install'."
        );
    }
    return f"'{top}' is not declared in jac.toml — add it with 'jac install {top}'.";
}
