import os;
import from enum { StrEnum }

enum ArchAction(StrEnum) { INIT = "init", SYNC = "sync", GRAPH = "graph" }

def _parse_action(action: str) -> (ArchAction | None);

def _project_root -> (str | None);

def _write_arch(arch_path: str, text: str);

def _strip_modules(paths: list[str]) -> int;

def _arch_target(directory: str) -> (str | None);

def _arch_files(root_dir: str) -> list[str];

def _arch_init(force: bool, strip: bool, directory: str) -> int;

def _arch_sync(strip: bool, directory: str, prune: bool = False) -> int;

def _sync_one(arch_path: str, strip: bool, prune: bool) -> int;

def _arch_graph(fmt: str, output: str, directory: str) -> int;

def _refused(plan: ArchPlan) -> bool;

impl arch(
    action: str = "graph",
    scope: str = "",
    strip: bool = False,
    prune: bool = False,
    force: bool = False,
    format: str = "mermaid",
    output: str = ""
) -> int {
    verb = _parse_action(action);
    if verb is None {
        console.error(f"unknown action: {action} (expected init, sync or graph)");
        return 2;
    }
    if scope and not os.path.isdir(scope) {
        console.error(
            f"'{scope}' is not a directory; `jac arch` takes the directory an archwire.jac governs"
        );
        return 2;
    }
    if verb == ArchAction.INIT {
        return _arch_init(force, strip, scope);
    }
    if verb == ArchAction.SYNC {
        return _arch_sync(strip, scope, prune);
    }
    return _arch_graph(format, output, scope);
}

impl _parse_action(action: str) -> (ArchAction | None) {
    try {
        return ArchAction(action);
    } except ValueError {
        return None;
    }
}

impl _project_root -> (str | None) {
    cfg = get_config();
    if cfg is None or cfg.project_root is None {
        console.error(
            "no jac.toml found; run `jac arch` inside a project",
            hint="archwire.jac lives beside jac.toml",
        );
        return None;
    }
    return str(cfg.project_root);
}

impl _write_arch(arch_path: str, text: str) {
    import tempfile;
    (fd, tmp) = tempfile.mkstemp(
        dir=os.path.dirname(arch_path) or ".", prefix=".arch.", suffix=".tmp"
    );
    try {
        with os.fdopen(fd, "w") as f {
            f.write(text);
        }
        os.replace(tmp, arch_path);
    } except BaseException as err {
        if os.path.exists(tmp) {
            os.unlink(tmp);
        }
        raise err;
    }
}

impl _refused(plan: ArchPlan) -> bool {
    if not plan.refusal {
        return False;
    }
    console.error(plan.refusal, hint=plan.hint or None);
    return True;
}

impl _strip_modules(paths: list[str]) -> int {
    session = tool_session();
    changed = 0;
    for path in paths {
        annexes = [
            *discover_annex_files(path, ".impl.jac"),
            *discover_annex_files(path, ".test.jac")
        ];
        for target in [path, *annexes] {
            fixed = session.lint_fix(target);
            format_failed = any([diag.code == "E5051" for diag in fixed.errors]);
            stripped = any(
                [diag.code in ("W3053", "W3054") for diag in fixed.warnings]
            );
            if format_failed or not stripped or not fixed.text {
                continue;
            }
            if fixed.text != read_file_with_encoding(target) {
                with open(target, "w") as f {
                    f.write(fixed.text);
                }
                changed += 1;
            }
        }
    }
    return changed;
}

impl _arch_target(directory: str) -> (str | None) {
    if directory {
        return os.path.abspath(directory);
    }
    return _project_root();
}

impl _arch_files(root_dir: str) -> list[str] {
    found: list[str] = [];
    for (dirpath, dirnames, filenames) in os.walk(root_dir) {
        dirnames[:] = sorted(
            [
                d
                for d in dirnames
                if not d.startswith(".")
                    and d not in ("node_modules", "__pycache__")
                    and not os.path.isfile(os.path.join(dirpath, d, "jac.toml"))
            ]
        );
        if ARCH_FILE_NAME in filenames {
            found.append(os.path.join(dirpath, ARCH_FILE_NAME));
        }
    }
    return drop_git_ignored(found, cwd=root_dir);
}

impl _arch_init(force: bool, strip: bool, directory: str) -> int {
    root_dir = _arch_target(directory);
    if root_dir is None {
        return 1;
    }
    arch_path = os.path.join(root_dir, ARCH_FILE_NAME);
    if os.path.exists(arch_path) and not force {
        console.error(
            f"{arch_path} already exists",
            hint="use `jac arch sync` to extend it, or --force to rewrite it"
        );
        return 1;
    }
    plan = tool_session(root_dir).arch_plan(arch_path, "init");
    if _refused(plan) {
        return 1;
    }
    _write_arch(arch_path, plan.text);
    console.success(
        f"wrote {ARCH_FILE_NAME}: {plan.added} wired names and {plan.rules} rules "
        f"sealing {len(plan.modules)} modules"
    );
    if strip {
        changed = _strip_modules(plan.modules);
        console.print(f"stripped wired imports from {changed} files");
    }
    return 0;
}

impl _arch_sync(strip: bool, directory: str, prune: bool = False) -> int {
    root_dir = _arch_target(directory);
    if root_dir is None {
        return 1;
    }
    targets = [os.path.join(root_dir, ARCH_FILE_NAME)]
        if directory
        else _arch_files(root_dir);
    if not targets {
        console.error(
            f"no {ARCH_FILE_NAME} under {root_dir}", hint="run `jac arch init` first"
        );
        return 1;
    }
    status = 0;
    for arch_path in targets {
        status = max(status, _sync_one(arch_path, strip, prune));
    }
    return status;
}

impl _sync_one(arch_path: str, strip: bool, prune: bool) -> int {
    plan = tool_session(os.path.dirname(arch_path)).arch_plan(arch_path, "sync", prune);
    if _refused(plan) {
        return 1;
    }
    _write_arch(arch_path, plan.text);
    console.success(
        f"{arch_path}: added {plan.added} wired names, removed {plan.dropped} unused,"
        f" {plan.rules_added} rules added or widened"
    );
    if strip or plan.fed {
        changed = _strip_modules(plan.modules if strip else plan.fed);
        console.print(f"stripped wired and dead imports from {changed} files");
    }
    return 0;
}

impl _arch_graph(fmt: str, output: str, directory: str) -> int {
    root_dir = _arch_target(directory);
    if root_dir is None {
        return 1;
    }
    arch_path = os.path.join(root_dir, ARCH_FILE_NAME);
    plan = tool_session(root_dir).arch_plan(arch_path, "graph", graph_format=fmt);
    if _refused(plan) {
        return 1;
    }
    if output {
        with open(output, "w") as f {
            f.write(plan.text);
        }
        console.success(f"wrote {output}");
        return 0;
    }
    console.print(plan.text, end="");
    return 0;
}
