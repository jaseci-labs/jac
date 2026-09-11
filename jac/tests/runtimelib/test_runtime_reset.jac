"""Per-run runtime state is reset in one place, and that place cannot drift.

`JacRuntime` carries the process-global handles a run needs: the compiler,
the program, the thread pool, the execution context, the loaded-module table.
Anything that reuses a process across runs -- the test pool's fork workers, a
language server, an embedded host -- has to put those back to a clean state
between runs, or the previous run's compilation unit stays reachable.

Doing that from the caller is how a slot gets missed: `_fresh_jac_state`
reset four of the five and left `compiler` behind, which kept a `JacCompiler`
and its internal program alive for the life of the worker. The reset belongs
next to the declarations, and the last test here fails if a new slot is added
without deciding what the reset does with it.

The project-config pin is per-run state too: `get_config_for_path` lets an
explicit `set_config` win over file-anchored resolution for every path in
the process, so a pin one test leaves behind rewrites what every later test
compiles under (main went red on exactly this: a leaked repo-root pin put
`no-print` in force for a dynamic module synthesized under /tmp). The reset
captures the run's pin state the first time it runs and puts it back before
every test.
"""

import types;
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.project.config { JacConfig, get_explicit_config, set_config }
import from jaclang.testing.test_runner { _fresh_jac_state }

glob PER_RUN_SLOTS: set = {
         "compiler",
         "program",
         "pool",
         "exec_ctx",
         "loaded_modules",
         "selfhost"
     },
     CONFIG_SLOTS: set = {"strict_permissions"};

test "a per-run reset drops the cached compiler" {
    JacRuntime.get_compiler();
    JacRuntime.loaded_modules["_probe"] = types.ModuleType("_probe");
    assert JacRuntime.compiler is not None;

    _fresh_jac_state();

    assert JacRuntime.compiler is None , (
        "the cached JacCompiler survived the reset; it holds an internal "
        "JacProgram, so every module that compiler loaded stays reachable "
        "for the life of the process"
    );
    assert not JacRuntime.loaded_modules , "the module table survived the reset";
}

test "the reset shuts the old thread pool down instead of abandoning it" {
    old = JacRuntime.pool;
    old.submit(len, "warm").result();
    _fresh_jac_state();
    assert JacRuntime.pool is not old , "the pool was reused, not replaced";
    raised = False;
    try {
        old.submit(len, "after");
    } except RuntimeError {
        raised = True;
    }
    assert raised , (
        "the previous pool still accepts work, so it was abandoned rather "
        "than shut down and its worker threads outlive the run"
    );
}

test "an explicit project config does not survive the reset" {
    import from pathlib { Path }
    import from jaclang.project.config { JacConfig, get_config_for_path, set_config }
    set_config(JacConfig());
    assert get_config_for_path(Path("/tmp/_probe_module.jac")) is not None , (
        "an explicit config should answer for every path while it is set"
    );
    _fresh_jac_state();
    assert get_config_for_path(Path("/tmp/_probe_module.jac")) is None , (
        "a test file's set_config leaked through the reset; the next file's "
        "out-of-project compiles (e.g. dynamic modules in the test base) then "
        "inherit this project's lint rules and can fail on them"
    );
}

glob PIN_HANDOFF: list[any] = [];

test "the reset restores the run's config pin baseline" {
    baseline = get_explicit_config();
    probe = JacConfig();
    set_config(probe);
    assert get_explicit_config() is probe;

    _fresh_jac_state();

    assert get_explicit_config() is not probe , (
        "the config pin set during a test survived the reset; every later "
        "test in this worker now resolves config through it instead of "
        "through file-anchored discovery"
    );
    assert get_explicit_config() is baseline , (
        "the reset did not put back the pin state the run started with"
    );
}

test "a config pin set inside a test is gone by the next test (part 1: leak one)" {
    # Order-dependent pair: this test leaks a pin on purpose; the next one
    # asserts the runner's per-test reset already removed it. Runs in
    # registration order; part 2 passes vacuously if run alone.
    PIN_HANDOFF.append(get_explicit_config());
    leaked = JacConfig();
    set_config(leaked);
    PIN_HANDOFF.append(leaked);
    assert get_explicit_config() is leaked;
}

test "a config pin set inside a test is gone by the next test (part 2: observe)" {
    if PIN_HANDOFF {
        baseline = PIN_HANDOFF[0];
        leaked = PIN_HANDOFF[1];
        assert get_explicit_config() is not leaked , (
            "the pin part 1 leaked survived into this test; the runner did "
            "not restore the config baseline between tests"
        );
        assert get_explicit_config() is baseline , (
            "the runner reset landed on some other pin state than the one "
            "the run started with"
        );
    }
}

test "every process-global slot is classified, so the reset cannot drift" {
    live: set = set();
    for (name, value) in vars(JacRuntime).items() {
        if name.startswith("_")
            or callable(value)
            or isinstance(value, (classmethod, staticmethod, property)) {
            continue;
        }
        live.add(name);
    }
    unclassified = live - PER_RUN_SLOTS - CONFIG_SLOTS;
    assert not unclassified , (
        f"JacRuntime grew process-global state that no one classified: "
        f"{sorted(unclassified)}. Add it to PER_RUN_SLOTS and reset it in "
        "JacRuntime.reset_process_state, or to CONFIG_SLOTS if it is "
        "process configuration that must survive a reset."
    );
    assert PER_RUN_SLOTS <= live , (
        f"PER_RUN_SLOTS names slots JacRuntime no longer has: "
        f"{sorted(PER_RUN_SLOTS - live)}"
    );
}
