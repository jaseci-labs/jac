"""A cold rebuild of the compiler does bounded work.

After a purge or an edit inside the compiler digest roots, the next jac
command recompiles every compiler module it loads. This test performs that
rebuild in a subprocess with an isolated cache and asserts the shape of the
work through counters, never through time: each dependency is ingested about
once, the unit collector fires on its budget rather than on every module, no
interface is encoded inside a codegen-driven closure, and the peak memory of
the process stays under a ceiling with room to spare.

The program the rebuild runs is a two-line entry that imports only `gc`, which
keeps it on the Python lane (a module with nothing but a print is placed
native, and a cold native build is a different measurement). The counters
are read by the driver once it has run. A program that imported a compiler module to
read them would be compiled by the kernel, which asks the host for that
module's interface; building the interfaces of compiler modules is a cost of
its own (there is no prebuilt catalog of them yet) and would be measured
here on top of the rebuild.

It takes minutes, which is why it lives alone in this file: the runner
parallelizes across files, so a slow file costs wall time only for itself.
It forces the rerouted compiler source so the rebuild is of this checkout
whatever lane it runs in."""
import json;
import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { cache_env, compiler_python_command, JAC_ROOT }

glob SYMTAB_PER_MODULE: float = 1.75,
     COLLECT_EVERY: int = 16,
     COLLECT_SLACK: int = 8,
     PEAK_RSS_CEILING_MB: int = 4096,
     PROBE_SRC: str = (
         "import gc;\n\n"
         "with entry {\n"
         "    print(\"rebuilt\", gc.isenabled());\n"
         "}\n"
     ),
     DRIVER: str = (
         "import atexit, gc, json, resource, sys\n"
         "from unittest.mock import patch\n"
         "collect = patch('gc.collect', wraps=gc.collect).start()\n"
         "def report():\n"
         "    usage = [resource.getrusage(w).ru_maxrss\n"
         "             for w in (resource.RUSAGE_SELF, resource.RUSAGE_CHILDREN)]\n"
         "    print('PEAK_RSS=' + str(max(usage)), flush=True)\n"
         "    from jaclang.runtime.runtime import JacRuntime\n"
         "    a = JacRuntime.get_selfhost().program.analysis\n"
         "    print('SELFHOST=' + json.dumps({\n"
         "        'runs': dict(a.pass_runs),\n"
         "        'events': dict(a.cache_events),\n"
         "        'collections': collect.call_count\n"
         "    }), flush=True)\n"
         "atexit.register(report)\n"
         "from jaclang.cli.cli_boot import start_cli\n"
         "sys.argv = ['jac', 'run', sys.argv[1]]\n"
         "start_cli()"
     );

"""Convert a `PEAK_RSS=` report from the driver to MB.

The driver reports its own peak and its children's, so the figure covers the
rebuild alone. `RUSAGE_CHILDREN` read here would also count every earlier
child of a pooled test worker."""
def _peak_mb(stdout: str) -> int {
    peak = 0;
    for line in stdout.splitlines() {
        if line.startswith("PEAK_RSS=") {
            peak = int(line[len("PEAK_RSS="):]);
        }
    }
    assert peak > 0 , f"no PEAK_RSS= line in stdout:\n{stdout[-1500:]}";
    if sys.platform == "darwin" {
        return int(peak // (1024 * 1024));
    }
    return int(peak // 1024);
}

def _cold_rebuild -> tuple[int, dict[str, any], int] {
    work = tempfile.mkdtemp();
    probe = os.path.join(work, "probe.jac");
    with open(probe, "w") as fh {
        fh.write(PROBE_SRC);
    }
    env: dict[str, str] = dict(os.environ);
    env["HOME"] = work;
    env.update(cache_env(os.path.join(work, "cache")));
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
        compiler_python_command(DRIVER, probe, compiler_root=JAC_ROOT),
        cwd=JAC_ROOT,
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
    return (compiled, payload, _peak_mb(proc.stdout), );
}

test "a cold compiler rebuild ingests each dependency about once and collects on its budget" {
    (compiled, payload, peak_mb) = _cold_rebuild();
    runs = payload["runs"];
    events = payload["events"];
    # The compiled count names Jac bytecode modules. Stub trees belong to
    # individual import sessions and have their own ingestion counter.
    stub_ingest = events.get("stub_ingest", 0);
    symtab = runs.get("SymTabBuildPass", 0) - stub_ingest;
    assert symtab <= SYMTAB_PER_MODULE * compiled , (
        f"dependencies were re-ingested: {symtab} Jac symbol-table runs for {compiled} "
        f"modules (bound {SYMTAB_PER_MODULE} per module; events: {events})"
    );
    collections = int(payload["collections"]);
    assert collections <= compiled // COLLECT_EVERY + COLLECT_SLACK , (
        f"explicit collection ran {collections} times for {compiled} modules; the budget "
        f"allows one per {COLLECT_EVERY} releases plus {COLLECT_SLACK}"
    );
    assert events.get("iface_encode", 0) == 0 , (
        f"a codegen-driven rebuild encoded interfaces (events: {events})"
    );
    assert peak_mb <= PEAK_RSS_CEILING_MB , (
        f"the rebuild peaked at {peak_mb} MB of RSS, above the {PEAK_RSS_CEILING_MB} MB ceiling"
    );
}
