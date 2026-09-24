"""Native demotion classification (#8030 B1): a pass crash is an ICE,
not a placement decision. ICE demotions get a distinct coverage outcome
and a loud (non-dim) note; diagnostic demotions stay dim.

Demotion consequences for importers (#8374): once a module leaves the
native lane the pin no longer wins any placement verdict -- not the
import-target classification and not the module's own codespace -- and
importers' stale ES output and NATIVE manifest bindings are cleared so
the next emission lowers the import against the real codespace.

The verdict itself (#8943) is a note on the program's native unit registry
(`prog.native_units().record_verdict`) that rides into the module's
placement summary and from there into the JIR's `SEC_PLACEMENT`
(`native_verdict` / `native_verdict_code`). The program that recorded it
answers from memory; every other reader answers from the module cache once
the summary is persisted, and a content edit (a new MODKEY) clears it."""

import os;
import from tests.support { JAC_ROOT }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.codeinfo { InteropBinding, InteropContext }
import from jaclang.compiler.driver.na_coverage {
    _drop_demoted_native_bindings,
    na_coverage_begin,
    na_coverage_end,
    na_coverage_record,
    na_demotion_note
}
import from jaclang.compiler.driver.boundary_classify {
    import_declares_native_target,
    plain_native_import_target
}
import from jaclang.compiler.driver.jir {
    SEC_PLACEMENT,
    get_module_cache_path,
    is_module_cache_valid,
    write_module_cache
}
import from jaclang.compiler.driver.nativecache { read_native_verdict }
import from jaclang.compiler.placement.placement { PlacementSummary, summary_to_bytes }
import from jaclang.compiler.placement.placement_pins {
    effective_module_pin,
    effective_pin_for,
    module_native_demoted,
    native_demotion_code
}
import from jaclang.compiler.placement.placement_solver { invalidate_importers_es }
import from jaclang.client.client_bundle { _ensure_js_generated }

glob PIN_FIXTURE_DIR = os.path.join(
         JAC_ROOT, "tests", "compiler", "fixtures", "codespace", "native_demoted_pin"
     ),
     E2E_FIXTURE_DIR = os.path.join(
         JAC_ROOT, "tests", "compiler", "fixtures", "codespace", "native_demoted_e2e"
     );

def compile_pin_fixture -> tuple[(JacProgram, uni.Module, uni.Import, str)] {
    prog = JacProgram();
    app = prog.compile(os.path.join(PIN_FIXTURE_DIR, "app.jac"), no_cgen=True);
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    imp = app.get_all_sub_nodes(uni.Import)[0];
    models_path = os.path.realpath(os.path.join(PIN_FIXTURE_DIR, "models.jac"));
    return (prog, app, imp, models_path);
}

def error_codes(prog: JacProgram) -> list[str] {
    return [
        e.code.code
        for e in prog.errors_had
        if e.code is not None
    ];
}

"""Drop every trace of a verdict on a shared fixture: the program's in-memory
note and the module cache entry the summary would persist it into, so the
next test (or process) retries the module natively."""
def forget_verdict(prog: (JacProgram | None), path: str) {
    real = os.path.realpath(path);
    if prog is not None {
        prog.native_units().verdicts.pop(real, None);
        notes = prog.analysis.native_verdict_notes;
        if notes is not None {
            notes.pop(real, None);
        }
    }
    try {
        get_module_cache_path(real).unlink(missing_ok=True);
    } except OSError {}
}

"""Persist a placement summary carrying a demotion verdict into the module
cache of `path`, the way the compile driver does on its next persist."""
def persist_verdict(path: str, code: str, detail: str) -> bool {
    ps = PlacementSummary(
        mod_path=path, native_verdict=detail, native_verdict_code=code
    );
    return write_module_cache(
        path, None, extra_sections={SEC_PLACEMENT: summary_to_bytes(ps)}
    );
}


test "ICE note is loud and self-identifies as a compiler bug" {
    (msg, style) = na_demotion_note("m.jac", "AttributeError: width", True);
    assert style != "dim";
    assert "internal" in msg;
    assert "m.jac" in msg;
}


test "diagnostic demotion note stays dim" {
    (msg, style) = na_demotion_note("m.jac", "error[E5092]: nope", False);
    assert style == "dim";
    assert "preferred native" in msg;
}


test "coverage records ice as a distinct sticky outcome" {
    na_coverage_begin();
    key = "/tmp/jac_test_ice_probe.jac";
    na_coverage_record(key, "ice", "AttributeError", "boom");
    na_coverage_record(key, "native");
    snap = na_coverage_end();
    rec = snap[os.path.realpath(key)];
    assert rec["outcome"] == "ice";
    assert rec["code"] == "AttributeError";
}


test "a demoted module loses the pin everywhere it is consulted" {
    (prog, _app, imp, models_path) = compile_pin_fixture();
    try {
        assert not module_native_demoted(models_path, prog) , "no verdict before demotion";
        assert effective_module_pin(models_path, prog) == 'native' , "the pin should hold before demotion";
        assert plain_native_import_target(imp, prog) is not None , "pin should make the import a native target before demotion";
        assert import_declares_native_target(imp) , "pin should declare a native target before demotion";
        prog.native_units().record_verdict(models_path, "E5092", "error[E5092]: nope");
        assert module_native_demoted(models_path, prog) , "the registry must answer the verdict from memory";
        assert native_demotion_code(models_path, prog) == "E5092";
        assert prog.native_units().is_demoted(models_path);
        assert prog.native_units().demoted_code(models_path) == "E5092";
        assert effective_pin_for(models_path, '', prog) == '' , "a demoted module is server ground; the pin must not win";
        assert effective_module_pin(models_path, prog) == '';
        assert plain_native_import_target(imp, prog) is None;
        assert read_native_verdict(models_path) is None , "nothing persisted yet";
        assert effective_module_pin(models_path) == 'native';
        assert import_declares_native_target(imp);
    } finally {
        forget_verdict(prog, models_path);
    }
}


test "a demotion verdict persists across programs through the JIR and dies with an edit" {
    import tempfile;
    import time;
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.realpath(os.path.join(tmp, "demoted.jac"));
        with open(path, "w", encoding="utf-8") as f {
            f.write("with entry { x = 1; }\n");
        }
        past = time.time() - 2;
        os.utime(path, (past, past));
        prog = JacProgram();
        assert read_native_verdict(path) is None , "no verdict before recording";
        assert not module_native_demoted(path, prog);
        prog.native_units().record_verdict(path, "E5092", "error[E5092]: nope");
        assert module_native_demoted(path, prog) , "the recording program answers from memory";
        assert native_demotion_code(path, prog) == "E5092";
        fresh = JacProgram();
        assert read_native_verdict(path) is None , (
            "a verdict must not be readable before the placement summary is persisted"
        );
        assert not module_native_demoted(path, fresh);
        assert not module_native_demoted(path);
        assert persist_verdict(path, "E5092", "error[E5092]: nope") , "module cache write failed";
        cache_path = get_module_cache_path(path);
        assert is_module_cache_valid(path, cache_path) , "the entry must be valid for the current content";
        verdict = read_native_verdict(path);
        assert verdict is not None and verdict.demoted , "a fresh process must read the verdict back";
        assert verdict.code == "E5092" , "the demotion code must persist with the verdict";
        assert verdict.detail == "error[E5092]: nope";
        assert module_native_demoted(path) , "the pin resolver reads the JIR without a program";
        assert native_demotion_code(path) == "E5092";
        assert module_native_demoted(path, fresh) , "a fresh program reads the JIR too";
        assert fresh.native_units().demoted_code(path) == "E5092";
        with open(path, "w", encoding="utf-8") as f {
            f.write("with entry { x = 12; }\n");
        }
        later = os.stat(path).st_mtime_ns + 1000000000;
        os.utime(path, ns=(later, later));
        assert not is_module_cache_valid(path, cache_path) , "an edited file must invalidate its entry";
        assert read_native_verdict(path) is None , "an edited file must be re-tried natively";
        assert not module_native_demoted(path);
        assert not module_native_demoted(path, fresh);
        assert not module_native_demoted(path, prog) , (
            "the recording program's memory is keyed on the file's identity and must not outlive the edit"
        );
    }
}

test "importer invalidation clears ES output and NATIVE bindings" {
    (prog, app, _imp, models_path) = compile_pin_fixture();
    app.gen.js = "stale na glue";
    manifest = app.gen.interop_manifest;
    manifest.bindings["double"] = InteropBinding(
        name="double",
        source_context=InteropContext.NATIVE,
        callers={InteropContext.CLIENT},
        source_module=models_path
    );
    manifest.bindings["unrelated"] = InteropBinding(
        name="unrelated",
        source_context=InteropContext.SERVER,
        callers={InteropContext.CLIENT},
        source_module=models_path
    );
    cleared = invalidate_importers_es(prog, models_path);
    assert app in cleared , "the importer must be found by the hub walk";
    assert app.gen.js == "" , "stale ES output must be cleared";
    assert app.gen.es_ast is None;
    for m in cleared {
        _drop_demoted_native_bindings(m, models_path);
    }
    assert "double" not in manifest.bindings , "the NATIVE binding naming the demoted module must be dropped";
    assert "unrelated" in manifest.bindings , "bindings in other contexts must survive";
}


test "the demotion fallback re-lowers importers away from the na seam" {
    prog = JacProgram();
    app_path = os.path.realpath(os.path.join(E2E_FIXTURE_DIR, "app.jac"));
    models_path = os.path.realpath(os.path.join(E2E_FIXTURE_DIR, "models.jac"));
    forget_verdict(None, models_path);
    try {
        app = prog.compile(app_path);
        assert "__na_bind" in (app.gen.js or "") , "the pin should bind the import through the na seam before demotion";
        prog.compile(models_path);
        hub_models = prog.mod.hub.get(models_path);
        assert hub_models is not None and hub_models.decided_codespace != 'native' , "the retry after demotion must actually leave the native lane";
        assert "E5092" not in error_codes(prog) , "the native-only error must not survive the fallback";
        assert module_native_demoted(models_path, prog) , "the driver must record the verdict on the registry";
        assert native_demotion_code(models_path, prog) == "E5092";
        raised = "";
        try {
            _ensure_js_generated(app, prog);
        } except Exception as exc {
            raised = f"{exc}";
        }
        assert "__na_bind" not in (app.gen.js or "") , "the re-lowered importer must not bind through the na seam";
        assert "E5082" in raised or "E5082" in error_codes(prog) , "a plain client import of a server def must be diagnosed";
    } finally {
        forget_verdict(prog, models_path);
    }
}

test "a docstring-only module is never decided native" {
    # Empty package markers passed the native verdict trivially and ran the
    # whole native pipeline for nothing; an interface hung on that inferred
    # verdict. A module with no executable element has nothing to lower.
    import tempfile;
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.placement.placement_solver { native_default_verdict }
    tmp = tempfile.mkdtemp();
    path = os.path.join(tmp, "__init__.jac");
    with open(path, "w") as fh {
        fh.write('"""pkg."""\n');
    }
    prog = JacProgram();
    mod = prog.compile(
        path, options=CompileOptions(no_cgen=True, force_target_program=True)
    );
    (ok, why) = native_default_verdict(mod);
    assert not ok , "an empty module passed the native verdict";
    assert "empty module" in why , why;
}

"""Lower `mod` again the way a native build session does, against whatever
the module caches say now; the boundary facts and interop bindings stay the
ones the first compile made."""
def relower_native(prog: JacProgram, mod: uni.Module) {
    import from jaclang.compiler.frontend.codeinfo {
        set_effective_default_codespace,
        get_effective_default_codespace_override
    }
    import from jaclang.compiler.passes.rc_facts_pass { RcFactsPass }
    import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
    completed = prog.analysis.completed_passes.get(id(mod));
    if completed is not None {
        completed.discard("NaIRGenPass");
        completed.discard("NativeCompilePass");
    }
    mod.gen.llvm_ir = None;
    mod.gen.native_iface = None;
    prev = get_effective_default_codespace_override();
    set_effective_default_codespace("native");
    try {
        prog.run_schedule(mod, [RcFactsPass, NaIRGenPass]);
    } finally {
        set_effective_default_codespace(prev);
    }
}

def ir_lines_naming(mod: uni.Module, name: str) -> list[str] {
    return [
        line
        for line in str(mod.gen.llvm_ir or "").split("\n")
        if (line.startswith("declare") or line.startswith("define")) and name in line
    ];
}

test "a native binding whose unit left the native lane never lowers to an unlinked extern" {
    # A caller's boundary facts bind `monster_drop` to the native unit of
    # items.jac. A demotion verdict for weapons.jac, which items imports,
    # then becomes visible before the caller lowers (a parallel worker wrote
    # it, or another compile projection recorded it), so the import walk no
    # longer links items. The call used to become a bare `@monster_drop`
    # extern that no unit defines; the JIT bound it to address zero and the
    # native call segfaulted, and the cached bitcode crashed every run after.
    import tempfile;
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.frontend.codeinfo {
        resolve_native_module,
        set_effective_default_codespace,
        get_effective_default_codespace_override
    }
    with tempfile.TemporaryDirectory() as tmp {
        base = os.path.realpath(tmp);
        sources = {
            "weapons.jac": "def weapon_rules(x: int) -> int {\n    return x;\n}\n",
            "items.jac": "import from .weapons { weapon_rules }\n\n"
            "def monster_drop(x: int) -> int {\n    return weapon_rules(x) + 1;\n}\n",
            "app.jac": "import from .items { monster_drop }\n\n"
            "def use_drop(x: int) -> int {\n    return monster_drop(x);\n}\n"
        };
        for (name, text) in sources.items() {
            with open(os.path.join(base, name), "w", encoding="utf-8") as f {
                f.write(text);
            }
        }
        weapons_path = os.path.join(base, "weapons.jac");
        prog = JacProgram();
        prev = get_effective_default_codespace_override();
        try {
            app = prog.compile(
                os.path.join(base, "app.jac"),
                options=CompileOptions(default_codespace="native")
            );
        } finally {
            set_effective_default_codespace(prev);
        }
        assert app.decided_codespace == 'native' , "the caller must lower native";
        binding = app.gen.interop_manifest.bindings.get("monster_drop");
        assert binding is not None
            and binding.source_context == InteropContext.NATIVE , "the caller binds monster_drop to the native unit of items.jac";
        linked = ir_lines_naming(app, "monster_drop");
        assert linked and all(".monster_drop" in line for line in linked) , linked;
        try {
            assert persist_verdict(weapons_path, "E1001", "error[E1001]: stale") , "module cache write failed";
            assert resolve_native_module(".items", base) == (None, None) , "items.jac is no longer a native unit once weapons.jac is demoted";
            relower_native(prog, app);
            unlinked = [
                line
                for line in ir_lines_naming(app, "monster_drop")
                if '@"monster_drop"' in line or "@monster_drop(" in line
            ];
            assert not unlinked , f"a bare extern no unit defines: {unlinked}";
            iface: any = app.gen.native_iface;
            assert iface is not None and "use_drop" in iface.demoted , (
                "the caller must fall back to Python instead of calling through a null symbol"
            );
        } finally {
            forget_verdict(prog, weapons_path);
        }
    }
}
