"""A warm module cache must not change a module's codespace (#8257).

Three laws, one bug. A compiler-source module's cache key folded in the
ambient default codespace, which is whatever compile scope happens to be in
flight, so an entry written under one scope was rejected under another and the
module was recompiled *while Python was importing it*. That recompile ran the
full pass pipeline, whose passes import `jaclang.compiler.symbol_utils`, so
compiling `symbol_utils.jac` re-entered a half-initialized `symbol_utils` and
raised. The client-codespace probe caught the ImportError and answered
"server", so every module quietly changed codespace on a warm cache.

The key is now a function of the module and the configuration, the symtab-IR
schedule pre-imports the compiler modules its passes reach at run time (the
discipline `get_ir_gen_sched` already kept) so no compile is ever the first to
import one, a compile that still manages to re-enter itself says so out loud
instead of degrading, and a probe failure that comes from the compiler's own
source refuses to answer at all.

A fourth law closes the cold-start hole (#8982 items 3 and 4): the modules a
schedule loader pre-imports are declared as data, and a compile nested inside
any of their imports runs on the bootstrap tier whichever import reached the
module first, so the tier a compiler module is built with never depends on
import order. When that tier cannot produce a module's bytecode, the retained
failure names the dependency that was mid-import.
"""

import os;
import sys;
import types;
import importlib.machinery as machinery;
import jaclang;
import jaclang.compiler.driver.program as program_mod;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.source_failures { CompilerSourceError }
import from jaclang.compiler.driver.schedules {
    ANALYSIS_SCHED_DEPS,
    CODEGEN_SCHED_DEPS,
    IR_SCHED_DEPS,
    get_analysis_sched,
    get_ir_gen_sched,
    get_py_code_gen,
    get_symtab_ir_sched,
    providers_of,
    schedule_tier_reason
}
import from jaclang.compiler.driver.source_failures { bootstrap_tier_failure_details }
import from jaclang.compiler.frontend.codeinfo {
    get_effective_default_codespace_override,
    set_effective_default_codespace
}
import from jaclang.compiler.driver.jir {
    get_module_cache_path,
    module_cache_key,
    module_env_fingerprint
}
import from jaclang.testing.cl_test_runner { _COLOR_CACHE, module_is_client }

glob SYMBOL_UTILS: str = os.path.join(
         os.path.dirname(str(jaclang.__file__)), "compiler", "symbol_utils.jac"
     ),
     EXPR_KEYS: str = os.path.join(
         os.path.dirname(str(jaclang.__file__)), "compiler", "expr_keys.jac"
     );


"""A module object whose spec claims `path` is mid-import, as an importer does."""
def initializing_stub(path: str) -> types.ModuleType {
    holder = types.ModuleType("jac_reentrant_probe");
    spec = machinery.ModuleSpec("jac_reentrant_probe", None, origin=path);
    setattr(spec, "_initializing", True);
    holder.__spec__ = spec;
    return holder;
}


obj FailingProgram {
    has error: Exception;

    def compile(*args: any, **kwargs: any) -> any {
        raise self.error;
    }
}


"""Stand in for `JacProgram` so the codespace probe fails with `error`."""
def failing_program_factory(error: Exception) -> any {
    def make(*args: any, **kwargs: any) -> FailingProgram {
        return FailingProgram(error=error);
    }
    return make;
}


test "a compiler-source module keys the same under every ambient codespace" {
    saved = get_effective_default_codespace_override();
    try {
        set_effective_default_codespace("server");
        server_env = module_env_fingerprint(SYMBOL_UTILS);
        server_key = module_cache_key(SYMBOL_UTILS);
        set_effective_default_codespace("native");
        native_env = module_env_fingerprint(SYMBOL_UTILS);
        native_key = module_cache_key(SYMBOL_UTILS);
        assert server_env == native_env , (
            "the ambient codespace changed a compiler-source env fingerprint: "
            f"server={server_env} native={native_env}"
        );
        assert server_key == native_key , (
            "the ambient codespace changed a compiler-source module key: "
            f"server={server_key} native={native_key}"
        );
    } finally {
        set_effective_default_codespace(saved);
    }
}


test "the symtab-ir schedule pre-imports what its passes reach at run time" {
    saved_mod = sys.modules.pop("jaclang.compiler.symbol_utils");
    try {
        get_symtab_ir_sched();
        restored = sys.modules.get("jaclang.compiler.symbol_utils");
        assert restored is not None , (
            "building the symtab-IR schedule left symbol_utils unimported, so a "
            "pass reaching it at run time would be the first to import it"
        );
        assert hasattr(restored, "collect_assigned_symbols") , (
            "symbol_utils came back half-initialized"
        );
    } finally {
        sys.modules["jaclang.compiler.symbol_utils"] = saved_mod;
    }
}


test "a symtab-only compile survives being the first to need symbol_utils" {
    saved_mod = sys.modules.pop("jaclang.compiler.symbol_utils");
    cache_path = get_module_cache_path(SYMBOL_UTILS);
    cached = cache_path.read_bytes() if cache_path.exists() else None;
    cache_path.unlink(missing_ok=True);
    try {
        prog = JacProgram();
        mod = prog.compile(
            os.path.join(TESTS_DIR, "compiler", "fixtures", "distinct", "brands.jac"),
            options=CompileOptions(symtab_ir_only=True)
        );
        assert mod is not None;
    } finally {
        sys.modules["jaclang.compiler.symbol_utils"] = saved_mod;
        if cached is not None {
            cache_path.write_bytes(cached);
        }
    }
}


test "the ir-gen schedule pre-imports the narrowing keys its passes reach" {
    saved_mod = sys.modules.pop("jaclang.compiler.expr_keys");
    try {
        get_ir_gen_sched();
        restored = sys.modules.get("jaclang.compiler.expr_keys");
        assert restored is not None , (
            "building the ir-gen schedule left expr_keys unimported, so "
            "CFGBuildPass reaching it at run time would be the first to import it"
        );
        assert hasattr(restored, "collect_assigned_symbols") , (
            "expr_keys came back half-initialized"
        );
    } finally {
        sys.modules["jaclang.compiler.expr_keys"] = saved_mod;
    }
}


"""Mark the real module `name` as mid-import, as the importer does while its body runs."""
def _with_in_flight(name: str, path: str) -> types.ModuleType {
    saved = sys.modules[name];
    sys.modules[name] = initializing_stub(path);
    return saved;
}


test "a schedule dependency mid-import puts the compile on the bootstrap tier" {
    name = "jaclang.compiler.symbol_utils";
    assert name in IR_SCHED_DEPS , "symbol_utils left the ir-gen dependency list";
    saved = _with_in_flight(name, SYMBOL_UTILS);
    try {
        reason = schedule_tier_reason();
        assert name in reason , f"tier reason does not name the module in flight: {reason!r}";
        sched = get_ir_gen_sched();
        assert "CfgSucc" not in providers_of(sched) , (
            "the full ir-gen schedule was built while one of its dependencies was "
            "mid-import; a pass reaching that module at run time re-enters it"
        );
        tail = [p.__name__ for p in get_py_code_gen()];
        assert tail == ["JcirGenPass", "JcirBytecodeGenPass"] , tail;
    } finally {
        sys.modules[name] = saved;
    }
    assert schedule_tier_reason() == "" , "the tier reason outlived the import";
    assert "CfgSucc" in providers_of(get_ir_gen_sched());
}


test "a silent internal compile failure names the dependency mid-import" {
    victim = os.path.join(
        os.path.dirname(str(jaclang.__file__)), "project", "config.jac"
    );
    assert bootstrap_tier_failure_details(victim) == "" , (
        "no dependency is in flight, so there is nothing to explain"
    );
    name = "jaclang.compiler.symbol_utils";
    saved = _with_in_flight(name, SYMBOL_UTILS);
    try {
        details = bootstrap_tier_failure_details(victim);
    } finally {
        sys.modules[name] = saved;
    }
    assert name in details and "bootstrap tier" in details , details;
    assert "IR_SCHED_DEPS" in details , f"the fix is not named: {details}";
}


test "every scheduled pass and loader import is a declared schedule dependency" {
    import from jaclang.bootstrap_manifest { is_seed_source }
    `root = os.path.dirname(str(jaclang.__file__));

    def seed(mod_name: str) -> bool {
        rel = mod_name.removeprefix("jaclang.").replace(".", os.sep) + ".jac";
        return is_seed_source(rel);
    }
    schedules = {
        "ir-gen": (get_ir_gen_sched(), IR_SCHED_DEPS),
        "analysis": (get_analysis_sched(), ANALYSIS_SCHED_DEPS),
        "codegen": (get_py_code_gen(native=False), CODEGEN_SCHED_DEPS)
    };
    for (origin, (passes, deps)) in schedules.items() {
        for dep in deps {
            mod = sys.modules.get(dep);
            assert mod is not None , f"{origin}: loader did not import {dep}";
            assert not getattr(mod.__spec__, "_initializing", False) , (
                f"{origin}: {dep} came back half-initialized"
            );
        }
        for p in passes {
            owner = p.__module__;
            covered = seed(owner)
                or any(owner == dep or owner.startswith(dep + ".") for dep in deps);
            assert covered , (
                f"{origin}: pass {p.__name__} lives in {owner}, which is neither a "
                "seed module nor in the schedule's dependency list; a compile "
                "reached from its import would run the schedule that needs it"
            );
        }
    }
}


test "a compile that re-enters the module being imported says so" {
    ek = sys.modules["jaclang.compiler.expr_keys"];
    saved_fn = ek.collect_assigned_symbols;
    sys.modules["jac_reentrant_probe"] = initializing_stub(EXPR_KEYS);
    delattr(ek, "collect_assigned_symbols");
    try {
        prog = JacProgram();
        compiler = prog._get_compiler();
        raised = False;
        try {
            compiler.compile(
                file_path=EXPR_KEYS,
                target_program=compiler.selfhost.program,
                options=CompileOptions(no_cgen=True)
            );
        } except CompilerSourceError as loud {
            raised = True;
            assert "re-entered" in str(loud) , str(loud);
            assert "jaclang.compiler.expr_keys" in str(loud) , str(loud);
        }
        assert raised , "a re-entrant compile degraded quietly instead of refusing";
    } finally {
        setattr(ek, "collect_assigned_symbols", saved_fn);
        del sys.modules["jac_reentrant_probe"];
    }
}


test "a probe failure from the compiler's own source refuses to answer" {
    fake = os.path.join(TESTS_DIR, "compiler", "fixtures", "_probe_loud.jac");
    _COLOR_CACHE.pop(os.path.abspath(fake), None);
    err = ImportError(
        "cannot import name 'collect_assigned_symbols' from partially "
        "initialized module 'jaclang.compiler.symbol_utils'",
        name="jaclang.compiler.symbol_utils",
        path=SYMBOL_UTILS
    );
    saved_program = program_mod.JacProgram;
    program_mod.JacProgram = failing_program_factory(err);
    try {
        raised = False;
        try {
            module_is_client(fake);
        } except CompilerSourceError as loud {
            raised = True;
            assert "refusing to degrade" in str(loud) , str(loud);
        }
        assert raised , "a compiler-source probe failure answered instead of raising";
    } finally {
        program_mod.JacProgram = saved_program;
        _COLOR_CACHE.pop(os.path.abspath(fake), None);
    }
}


test "a probe failure in the probed source still answers server" {
    fake = os.path.join(TESTS_DIR, "compiler", "fixtures", "_probe_quiet.jac");
    _COLOR_CACHE.pop(os.path.abspath(fake), None);
    saved_program = program_mod.JacProgram;
    program_mod.JacProgram = failing_program_factory(ValueError("bad fixture"));
    try {
        assert module_is_client(fake) == False;
    } finally {
        program_mod.JacProgram = saved_program;
        _COLOR_CACHE.pop(os.path.abspath(fake), None);
    }
}
