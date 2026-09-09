"""A cold rebuild of the compiler does bounded work.

After a purge or an edit inside the compiler digest roots, the next jac
command recompiles every compiler module it loads. This test performs that
rebuild in a subprocess with an isolated cache and asserts the shape of the
work through counters, never through time: each dependency is ingested about
once, the unit collector fires on its budget rather than on every module, no
interface is encoded inside a codegen-driven closure, and the peak memory of
the process stays under a ceiling with room to spare.

It takes minutes, which is why it lives alone in this file: the runner
parallelizes across files, so a slow file costs wall time only for itself.
It forces the rerouted compiler source so the rebuild is of this checkout
whatever lane it runs in."""
import json;
import os;
import resource;
import subprocess;
import sys;
import tempfile;
import jaclang;

glob JACLANG_DIR: str = os.path.dirname(os.path.realpath(str(jaclang.__file__))),
     SYMTAB_PER_MODULE: float = 1.75,
     COLLECT_EVERY: int = 16,
     COLLECT_SLACK: int = 8,
     PEAK_RSS_CEILING_MB: int = 4096,
     PROBE_SRC: str = (
         "import gc;\n"
         "import json;\n"
         "import from jaclang.runtime.runtime { JacRuntime }\n\n"
         "with entry {\n"
         "    a = JacRuntime.get_selfhost().program.analysis;\n"
         "    print(\"SELFHOST=\" + json.dumps({\n"
         "        \"runs\": a.pass_runs,\n"
         "        \"events\": a.cache_events,\n"
         "        \"gen2\": gc.get_stats()[2][\"collections\"]\n"
         "    }));\n"
         "}\n"
     ),
     DRIVER: str = (
         "import sys; from jaclang.cli.cli_boot import start_cli; "
         "sys.argv = ['jac', 'run', sys.argv[1]]; start_cli()"
     );

def _peak_children_mb -> int {
    peak = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss;
    if sys.platform == "darwin" {
        return int(peak // (1024 * 1024));
    }
    return int(peak // 1024);
}

def _cold_rebuild -> tuple[int, dict, int] {
    work = tempfile.mkdtemp();
    probe = os.path.join(work, "probe.jac");
    with open(probe, "w") as fh {
        fh.write(PROBE_SRC);
    }
    env = dict(os.environ);
    env["HOME"] = work;
    env["XDG_CACHE_HOME"] = os.path.join(work, "cache");
    env["LOCALAPPDATA"] = os.path.join(work, "cache");
    for knob in [
        "JAC_NO_DEV_SOURCE",
        "JAC_NO_UNIT_EVICT",
        "JAC_REBUILD",
        "JAC_PRECOMPILE_LIMIT",
        "JAC_UNIT_COLLECT_EVERY",
        "JAC_UNIT_COLLECT_GROWTH_MB"
    ] {
        env.pop(knob, None);
    }
    proc = subprocess.run(
        [sys.executable, "-c", DRIVER, probe],
        cwd=os.path.dirname(JACLANG_DIR),
        capture_output=True,
        text=True,
        env=env
    );
    assert proc.returncode == 0 , (
        f"the cold rebuild failed (rc={proc.returncode}):\n{proc.stderr[-3000:]}"
    );
    compiled = proc.stderr.count("  Compiling ");
    if compiled == 0 and "jac dev mode" not in proc.stderr {
        testskip(
            "the checkout's compiler is not rerouted here (a bare checkout or a "
            "sealed lane), so there is no cold rebuild to measure"
        );
    }
    assert compiled > 0 , (
        "no rebuild happened: the probe ran on a warm compiler with the checkout "
        "rerouted, so the cache was not isolated"
    );
    payload: (dict[str, any] | None) = None;
    for line in proc.stdout.splitlines() {
        if line.startswith("SELFHOST=") {
            payload = json.loads(line[len("SELFHOST="):]);
        }
    }
    assert payload is not None , f"no SELFHOST= line in stdout:\n{proc.stdout[-1500:]}";
    return (compiled, payload, _peak_children_mb(), );
}

test "a cold compiler rebuild ingests each dependency about once and collects on its budget" {
    (compiled, payload, peak_mb) = _cold_rebuild();
    runs = payload["runs"];
    events = payload["events"];
    symtab = runs.get("SymTabBuildPass", 0);
    assert symtab <= SYMTAB_PER_MODULE * compiled , (
        f"dependencies were re-ingested: {symtab} symbol-table runs for {compiled} "
        f"modules (bound {SYMTAB_PER_MODULE} per module; events: {events})"
    );
    gen2 = int(payload["gen2"]);
    assert gen2 <= compiled // COLLECT_EVERY + COLLECT_SLACK , (
        f"the unit collector fired {gen2} times for {compiled} modules; the budget "
        f"allows one per {COLLECT_EVERY} releases plus {COLLECT_SLACK}"
    );
    assert events.get("iface_encode", 0) == 0 , (
        f"a codegen-driven rebuild encoded interfaces (events: {events})"
    );
    assert peak_mb <= PEAK_RSS_CEILING_MB , (
        f"the rebuild peaked at {peak_mb} MB of RSS, above the {PEAK_RSS_CEILING_MB} MB ceiling"
    );
}
