"""Native demotion classification (#8030 B1): a pass crash is an ICE,
not a placement decision. ICE demotions get a distinct coverage outcome
and a loud (non-dim) note; diagnostic demotions stay dim.

Demotion consequences for importers (#8374): once a module leaves the
native lane the pin no longer wins any placement verdict -- not the
import-target classification and not the module's own codespace -- and
importers' stale ES output and NATIVE manifest bindings are cleared so
the next emission lowers the import against the real codespace."""

import os;
import from tests.support { JAC_ROOT }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.codeinfo { InteropBinding, InteropContext }
import from jaclang.jac0core.compiler {
    _drop_demoted_native_bindings,
    import_declares_native_target,
    na_coverage_begin,
    na_coverage_end,
    na_coverage_record,
    na_demotion_note,
    plain_native_import_target
}
import from jaclang.jac0core.placement_pins {
    _mark_demoted_native,
    _na_demotion_memo,
    effective_module_pin
}
import from jaclang.jac0core.placement_solver { invalidate_importers_es }
import from jaclang.runtimelib.client_bundle { _ensure_js_generated }

glob PIN_FIXTURE_DIR = os.path.join(
         JAC_ROOT, "tests", "compiler", "fixtures", "codespace", "native_demoted_pin"
     ),
     E2E_FIXTURE_DIR = os.path.join(
         JAC_ROOT, "tests", "compiler", "fixtures", "codespace", "native_demoted_e2e"
     );

def compile_pin_fixture -> tuple[(object, uni.Module, uni.Import, str)] {
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
        assert effective_module_pin(models_path) == 'native' , "the pin should hold before demotion";
        assert plain_native_import_target(imp, prog) is not None , "pin should make the import a native target before demotion";
        assert import_declares_native_target(imp) , "pin should declare a native target before demotion";
        _mark_demoted_native(models_path);
        assert effective_module_pin(models_path) == '' , "a demoted module is server ground; the pin must not win";
        assert plain_native_import_target(imp, prog) is None;
        assert not import_declares_native_target(imp);
    } finally {
        _na_demotion_memo.pop(models_path, None);
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
    try {
        app = prog.compile(app_path);
        assert "__na_bind" in (app.gen.js or "") , "the pin should bind the import through the na seam before demotion";
        prog.compile(models_path);
        hub_models = prog.mod.hub.get(models_path);
        assert hub_models is not None and hub_models.decided_codespace != 'native' , "the retry after demotion must actually leave the native lane";
        assert "E5092" not in error_codes(prog) , "the native-only error must not survive the fallback";
        raised = "";
        try {
            _ensure_js_generated(app, prog);
        } except Exception as exc {
            raised = f"{exc}";
        }
        assert "__na_bind" not in (app.gen.js or "") , "the re-lowered importer must not bind through the na seam";
        assert "E5082" in raised or "E5082" in error_codes(prog) , "a plain client import of a server def must be diagnosed";
    } finally {
        _na_demotion_memo.pop(models_path, None);
    }
}
