"""The lazy sv-to-sv spawn must wait on the configured boot health budget.

`ensure_sv_service` shells out to `jac start <mod>.jac --no-client` and waits
for the child's /healthz. The orchestrated path already waits
`boot_health_timeout` (60s) for exactly this and lets an operator raise it;
the lazy path took `wait_for_health`'s 15s signature default and read no
config, so a service whose cold start exceeds 15s could never come up and
every retry was killed partway through warming.

These run a real `jac start` subprocess against a real temp project and a real
config load. Nothing here is stubbed: the child is the actual CLI, the budget
comes from a real jac.toml, and the assertions are on whether the service
answers.
"""

import os;
import shutil;
import tempfile;
import time;
import from pathlib { Path }
import from jaclang.runtimelib { sv_client }
import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }
import from jaclang.scale.plugin { JacScalePlugin, stop_sv_sibling }

# Long enough to blow the old hardcoded 15s budget, short enough to keep the
# test near half a minute. The child stays silent while it sleeps, so this also
# covers the stall case: no log output at all for the whole window.
glob _SLOW_BOOT_SECONDS: float = 18.0,
     _BUDGET_SECONDS: float = 120.0;

glob _SLOW_PEER_SRC: str = 'import time;\n'
     '\n'
     'with entry {\n'
     f'    time.sleep({_SLOW_BOOT_SECONDS});\n'
     '}\n'
     '\n'
     'def:pub ping() -> int {\n'
     '    return 1;\n'
     '}\n';

glob _DEAD_PEER_SRC: str = 'with entry {\n'
     '    raise RuntimeError("peer refuses to boot");\n'
     '}\n'
     '\n'
     'def:pub ping() -> int {\n'
     '    return 1;\n'
     '}\n';

# Appends its own pid on module entry, so the file counts how many child
# processes were actually started regardless of which one won the port.
glob _PID_PEER_SRC: str = 'import os;\n'
     'import time;\n'
     '\n'
     'with entry {\n'
     '    with open("spawn_pids.txt", "a") as f {\n'
     '        f.write(str(os.getpid()) + "\\n");\n'
     '    }\n'
     '    time.sleep(3.0);\n'
     '}\n'
     '\n'
     'def:pub ping() -> int {\n'
     '    return 1;\n'
     '}\n';


def _make_project(module_name: str, source: str, budget: float | None) -> str {
    project_dir = tempfile.mkdtemp(prefix="jac-sv-budget-");
    proj = Path(project_dir);
    (proj / f"{module_name}.jac").write_text(source);
    toml = '[project]\n'
    'name = "svbudget"\n'
    'entry-point = "main.jac"\n'
    '\n'
    '[scale.microservices]\n';
    if budget is not None {
        toml += f"boot_health_timeout = {budget}\n";
    }
    toml += '\n[scale.microservices.routes]\n' f'{module_name} = "/{module_name}"\n';
    (proj / "jac.toml").write_text(toml);
    reset_scale_config();
    get_scale_config(project_dir=proj);
    return project_dir;
}


def _teardown(module_name: str, project_dir: str) {
    if module_name in sv_client._registry {
        sv_client.unregister(module_name);
    }
    stop_sv_sibling(module_name);
    reset_scale_config();
    shutil.rmtree(project_dir, ignore_errors=True);
}


test "a slow-booting sv-to-sv service comes up within the configured budget" {
    module_name = "svbudget_slow_peer";
    project_dir = _make_project(module_name, _SLOW_PEER_SRC, _BUDGET_SECONDS);
    started = time.time();
    try {
        JacScalePlugin.ensure_sv_service(module_name, project_dir);
        elapsed = time.time() - started;
        url = sv_client._registry.get(module_name, "");
        assert url , (
            f"service never registered after {elapsed:.1f}s; the spawn budget "
            "did not survive a boot slower than the old 15s default"
        );
        assert elapsed > _SLOW_BOOT_SECONDS , (
            f"came up in {elapsed:.1f}s, faster than the module's own "
            f"{_SLOW_BOOT_SECONDS}s sleep - the fixture is not exercising a slow boot"
        );
    } finally {
        _teardown(module_name, project_dir);
    }
}


test "concurrent first calls to one service spawn exactly one sibling" {
    import from concurrent.futures { ThreadPoolExecutor }
    module_name = "svbudget_pid_peer";
    project_dir = _make_project(module_name, _PID_PEER_SRC, _BUDGET_SECONDS);
    try {
        def _one(_i: int) -> str {
            JacScalePlugin.ensure_sv_service(module_name, project_dir);
            return sv_client._registry.get(module_name, "");
        }
        executor = ThreadPoolExecutor(max_workers=2);
        try {
            urls = list(executor.map(_one, range(2)));
        } finally {
            executor.shutdown(`wait=True);
        }
        assert all([u for u in urls]) , f"a caller returned unregistered: {urls}";
        assert len(set(urls)) == 1 , f"callers registered different URLs: {urls}";

        pid_file = Path(project_dir) / "spawn_pids.txt";
        pids = [
            line
            for line in pid_file.read_text().splitlines()
            if line.strip()
        ];
        assert len(pids) == 1 , (
            f"{len(pids)} service processes were started for one module "
            f"(pids {pids}); concurrent first calls must share one spawn, or the "
            "loser's process leaks with no handle left to stop it"
        );
    } finally {
        _teardown(module_name, project_dir);
    }
}


test "a child that dies is reported as an exit, not as a health timeout" {
    module_name = "svbudget_dead_peer";
    project_dir = _make_project(module_name, _DEAD_PEER_SRC, _BUDGET_SECONDS);
    started = time.time();
    raised = "";
    try {
        try {
            JacScalePlugin.ensure_sv_service(module_name, project_dir);
        } except RuntimeError as err {
            raised = str(err);
        }
        elapsed = time.time() - started;
        assert raised , "a child that raises at import must fail the spawn";
        assert "exited" in raised , (
            f"a dead child must be reported as an exit, got: {raised}"
        );
        assert elapsed < _BUDGET_SECONDS , (
            f"a dead child was waited on for {elapsed:.1f}s; death is observable "
            "immediately and must not burn the whole budget"
        );
    } finally {
        _teardown(module_name, project_dir);
    }
}
