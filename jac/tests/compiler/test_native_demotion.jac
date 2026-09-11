"""Native demotion classification (#8030 B1): a pass crash is an ICE,
not a placement decision. ICE demotions get a distinct coverage outcome
and a loud (non-dim) note; diagnostic demotions stay dim.

Demotion consequences for importers (#8374): once a module leaves the
native lane the pin no longer wins any placement verdict -- not the
import-target classification and not the module's own codespace -- and
importers' stale ES output and NATIVE manifest bindings are cleared so
the next emission lowers the import against the real codespace."""

import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import os;
import from tests.support { JAC_ROOT }
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.backends.common.artifacts {
    InteropBinding,
    InteropContext
}
import from jaclang.compiler.analysis.placement.native_fallback {
    _drop_demoted_native_bindings,
    na_coverage_begin,
    na_coverage_end,
    na_coverage_record,
    na_demotion_note
}
import from jaclang.compiler.analysis.boundaries.classify {
    import_declares_native_target,
    plain_native_import_target
}
import from jaclang.compiler.analysis.placement.pins {
    _clear_demoted_native,
    _demoted_native_code,
    _demotion_sidecar,
    _is_demoted_native,
    _mark_demoted_native,
    _na_demotion_memo,
    _na_demotion_probed,
    effective_module_pin
}
import from jaclang.compiler.api { invalidate_native_importers }
import from jaclang.client.client_bundle { _ensure_js_generated }

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
        _clear_demoted_native(models_path);
    }
}


test "a demotion verdict persists across processes and dies with the file" {
    import tempfile;
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.realpath(os.path.join(tmp, "demoted.jac"));
        with open(path, "w", encoding="utf-8") as f {
            f.write("with entry { x = 1; }\n");
        }
        try {
            assert not _is_demoted_native(path) , "no verdict before marking";
            _mark_demoted_native(path, "E5092");
            sidecar = _demotion_sidecar(path);
            assert sidecar is not None and os.path.exists(sidecar) , "marking must persist a sidecar";
            _na_demotion_memo.clear();
            _na_demotion_probed.clear();
            assert _is_demoted_native(path) , "a fresh process must read the verdict back";
            assert _demoted_native_code(path) == "E5092" , "the demotion code must persist with the verdict";
            with open(path, "w", encoding="utf-8") as f {
                f.write("with entry { x = 12; }\n");
            }
            later = os.stat(path).st_mtime_ns + 1000000000;
            os.utime(path, ns=(later, later));
            assert not _is_demoted_native(path) , "an edited file must be re-tried natively";
            assert not os.path.exists(sidecar) , "a stale verdict must be removed";
        } finally {
            _clear_demoted_native(path);
        }
    }
}

test "importer invalidation clears ES output and NATIVE bindings" {
    (prog, app, _imp, models_path) = compile_pin_fixture();
    artifact_for(app).js = "stale na glue";
    manifest = artifact_for(app).interop_manifest;
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
    invalidate_native_importers(prog, models_path);
    assert artifact_for(app).js == "" , "stale ES output must be cleared";
    assert artifact_for(app).es_ast is None;
    assert "double" not in manifest.bindings , "the NATIVE binding naming the demoted module must be dropped";
    assert "unrelated" in manifest.bindings , "bindings in other contexts must survive";
}


test "the demotion fallback re-lowers importers away from the na seam" {
    prog = JacProgram();
    app_path = os.path.realpath(os.path.join(E2E_FIXTURE_DIR, "app.jac"));
    models_path = os.path.realpath(os.path.join(E2E_FIXTURE_DIR, "models.jac"));
    try {
        app = prog.compile(app_path);
        assert "__na_bind" in (artifact_for(app).js or "") , "the pin should bind the import through the na seam before demotion";
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
        assert "__na_bind" not in (artifact_for(app).js or "") , "the re-lowered importer must not bind through the na seam";
        assert "E5082" in raised or "E5082" in error_codes(prog) , "a plain client import of a server def must be diagnosed";
    } finally {
        _clear_demoted_native(models_path);
    }
}

test "a docstring-only module is never decided native" {
    # Empty package markers passed the native verdict trivially and ran the
    # whole native pipeline for nothing; an interface hung on that inferred
    # verdict. A module with no executable element has nothing to lower.
    import tempfile;
    import from jaclang.compiler.session.options { CompileOptions }
    import from jaclang.compiler.analysis.placement.module_context_pass {
        native_default_verdict
    }
    tmp = tempfile.mkdtemp();
    path = os.path.join(tmp, "__init__.jac");
    with open(path, "w") as fh {
        fh.write('"""pkg."""\n');
    }
    prog = JacProgram();
    mod = prog.compile(
        path, options=CompileOptions(no_cgen=True, force_target_program=True)
    );
    (ok, why) = native_default_verdict(mod, prog);
    assert not ok , "an empty module passed the native verdict";
    assert "empty module" in why , why;
}
