"""A space a native app runs in its own process that isn't native: a
cpython space, its code objects run by embedded CPython. The app carries the
crossings between them in-process, each way through the other side's port:
the app's own spaces' calls to the cpython space go to the space's (its
stdjac.app's `in_process`), and the space's calls to the app's spaces come
back through the app's (stdjac.remote's carry_in_process, on each side).
Its graph and its store are its own, as every space's are; its scheduled
functions run on the app's loop, and its jobs in copies of the app's
program. A program the build makes this module part of registers it as it
starts."""

import json;
import sys;
import importlib;

"""Load cpython space `dir` (its code objects, its runtime, and
@jac/space.json: its modules and its main module) into embedded CPython: its
main module (stdjac.app's), imported, started (its graph opened)."""
def load_cpython_space(space: str, dir: str) -> any {
    sys_ = importlib.import_module("sys");
    sys_.path.insert(0, dir);
    runtime = importlib.import_module("_jac");
    main = runtime.install(dir, False);
    # Its jobs run in copies of this program, which hand them back to it
    # (run_cpython_job).
    importlib.import_module("rt.stdjac.server").set_job_command(
        sys.orig_argv[0:len(sys.orig_argv) - len(sys.argv) + 1], space
    );
    return main;
}

"""Start cpython space `space` from `dir`, which this program reaches
in-process from then on; its calls to the program's own spaces, `mine`, come
back through `port`. Its scheduled functions, as ticks for the program's loop."""
def run_cpython_space(
    space: str,
    dir: str,
    mine: list[str],
    port: Callable[[str, bytes, str, bool], tuple[int, bytes]],
) -> list[Scheduled] {
    main = load_cpython_space(space, dir);
    remote = importlib.import_module("rt.stdjac.remote");
    for sp in mine {
        remote.carry_in_process(sp, port);
    }
    its_port = main.in_process;
    carry_in_process(
        space,
        lambda (path: str, body: bytes, caller: str, trusted: bool) -> tuple[int, bytes] {
            reply = its_port(path, body, caller, trusted);
            status: int = reply[0];
            got: bytes = reply[1];
            return (status, got);
        },
    );
    work: list[Scheduled] = [];
    for t in main.space_scheduled() {
        work.append(space_scheduled(t));
    }
    return work;
}

"""`t`, a scheduled function of a cpython space (its stdjac.server's
Scheduled), as the program that runs the space schedules it."""
def space_scheduled(t: any) -> Scheduled {
    name: str = t.name;
    every: float = t.every;
    work = t.run;
    return Scheduled(name=name, every=every, run=lambda { work() });
}

"""Run job `name` of cpython space `space` (its code at `dir`) on `input`,
telling `note` how it goes, in a copy of this program the project's jobs
started for it: its result."""
def run_cpython_job(
    space: str, dir: str, name: str, input: any, note: Callable[[str, str], None]
) -> any {
    load_cpython_space(space, dir);
    # (Its input and its result are JSON's values on each side, and cross
    # between this program and its CPython as JSON's text, as a call's do.)
    theirs = importlib.import_module("json");
    out = importlib.import_module("rt.stdjac.server").run_job(
        name, theirs.loads(json.dumps(input)), note
    );
    return json.loads(str(theirs.dumps(out)));
}

glob _cpython_host: bool = register_space_host(
    "cpython",
    SpaceHost(
        start=lambda (
            space: str,
            dir: str,
            mine: list[str],
            port: Callable[[str, bytes, str, bool], tuple[int, bytes]],
        ) -> list[Scheduled] { return run_cpython_space(space, dir, mine, port); },
        job=lambda (
            space: str, dir: str, name: str, input: any, note: Callable[[str, str], None]
        ) -> any { return run_cpython_job(space, dir, name, input, note); },
    ),
);
