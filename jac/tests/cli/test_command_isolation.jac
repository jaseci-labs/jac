"""Selected-command import isolation guard.

The lazy-dispatch contract (PLAN.md Priority 0 "Eliminate command-package
fan-out") requires that loading a selected command's handler imports only its
owning command module (plus documented shared helpers) -- not the entire
``jaclang.cli.commands`` registration set.

Historically ``commands/__init__.jac`` imported every registration module, so
importing any one handler (e.g. ``jaclang.cli.commands.execution``) eagerly
pulled in all ~15 siblings. That package-init fan-out is now gone; this test
keeps it gone.

Each command is exercised in a fresh subprocess so ``sys.modules`` caching
cannot mask leakage across cases. We measure modules imported by
``load_handler(name)`` alone (no handler execution), because cross-command
imports inside handlers are intentionally local/deferred and must not fire at
load time.
"""

import json;
import os;
import subprocess;
import sys;
import from pathlib { Path }
import from tests.support { JAC_ROOT }

glob REPO: str = str(Path(JAC_ROOT).parent),
     # The authoritative core registration modules (must match the
     # _CORE_REGISTRATION_MODULES list in jaclang/cli/registry.jac). Loading any
     # single command must not import registration modules outside this command's
     # owning module.
     REGISTRATION_SHORT: set[str] = {
         "execution",
         "analysis",
         "build",
         "transform",
         "project",
         "guide",
         "eject",
         "tools",
         "config",
         "db",
         "nacompile",
         "ai",
         "code",
         "browse"
     },
     # Commands representative of every family: core runtime (run), compiler
     # analysis (check), config/filesystem (config), pure tool (guide), client
     # (build), and a hidden tool command (dot -> tools).
     TARGET_COMMANDS: list[str] = ["run", "check", "config", "guide", "build", "dot"],
     PROBE_SINGLE: str = """
import sys, json, os
sys.path.insert(0, os.environ['JAC_BENCH_ROOT'])
from jaclang.cli.loader import load_handler
load_handler(sys.argv[1])
mods = sorted(m for m in sys.modules if m.startswith('jaclang.cli.commands.'))
print('PROBE=' + json.dumps(mods))
""",
     OWNING_PROBE: str = """
import sys, json, os
sys.path.insert(0, os.environ['JAC_BENCH_ROOT'])
from jaclang.cli.manifest import get_command_meta
names = json.loads(sys.argv[1])
out = {}
for n in names:
    m = get_command_meta(n)
    hm = (m.handler_module if m else '') or ''
    if hm.startswith('jaclang.cli.commands.'):
        out[n] = hm.split('.')[-1]
print('OWNING=' + json.dumps(out))
""";

def _env -> dict[str, str] {
    env = dict(os.environ);
    env["JAC_BENCH_ROOT"] = JAC_ROOT;
    return env;
}

def _command_owning_module -> dict[str, str] {
    # Source of truth is the compact route table in jaclang.cli.manifest; read
    # it in a subprocess so importing jaclang here cannot pollute the isolation
    # probes below.
    proc = subprocess.run(
        [sys.executable, "-c", OWNING_PROBE, json.dumps(TARGET_COMMANDS)],
        cwd=REPO,
        capture_output=True,
        text=True,
        env=_env()
    );
    assert proc.returncode == 0 , (
        f"owning-module probe failed (rc={proc.returncode}):\n{proc.stderr[-1500:]}"
    );
    for line in proc.stdout.splitlines() {
        if line.startswith("OWNING=") {
            return json.loads(line.split("=", 1)[1]);
        }
    }
    raise AssertionError(f"no OWNING= line in stdout:\n{proc.stdout[-1000:]}");
}

def _parse_probe(stdout: str) -> list[str] {
    for line in stdout.splitlines() {
        if line.startswith("PROBE=") {
            return json.loads(line.split("=", 1)[1]);
        }
    }
    raise AssertionError(f"no PROBE= line in stdout:\n{stdout[-1000:]}");
}

test "loading handler imports no sibling registration module" {
    owning = _command_owning_module();
    env = _env();
    for cmd_name in TARGET_COMMANDS {
        assert cmd_name in owning , (
            f"{cmd_name!r} not found in manifest; update TARGET_COMMANDS or the "
            "manifest handler_module."
        );
        proc = subprocess.run(
            [sys.executable, "-c", PROBE_SINGLE, cmd_name],
            cwd=REPO,
            capture_output=True,
            text=True,
            env=env
        );
        assert proc.returncode == 0 , (
            f"load_handler({cmd_name!r}) probe failed (rc={proc.returncode}):\n"
            f"stderr:\n{proc.stderr[-1500:]}"
        );
        imported = _parse_probe(proc.stdout);
        short = {m.split(".")[-1] for m in imported};
        leaked = sorted(short & REGISTRATION_SHORT - {owning[cmd_name]});
        # Only the owning registration module may load; no sibling registration
        # module is permitted.
        assert not leaked , (
            f"load_handler({cmd_name!r}) (owning={owning[cmd_name]!r}) leaked "
            f"sibling registration modules: {leaked}. Imported command modules: "
            f"{imported}"
        );
    }
}
