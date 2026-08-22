"""A module that fails to parse is compiled once, not once per import path.

A failed parse used to be dropped before it reached `program.mod.hub`, so every
path that reached it in one build -- import walk, type checker, placement
solver -- missed the cache, re-parsed, and appended another copy of its alerts
to `errors_had`. The importer is a client module because that is the shape that
pulls in those extra paths.

Duplication *across* builds (6 errors, then 12, then 18 as a dev server
reloads) is covered in tests/runtimelib/test_hmr.jac.
"""

import tempfile;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.program { JacProgram }

glob BROKEN_SRC = 'def broken_repro( -> {{{ SYNTAX ERROR\n',
     FIXED_SRC = 'def:pub broken_repro -> int {\n    return 7;\n}\n',
     CARD_SRC = (
         'import from .broken { broken_repro }\n\n'
         'def:pub card -> JsxElement {\n'
         '    return <div>{broken_repro()}</div>;\n}\n'
     );

# A fresh dir per measurement keeps measurements independent of any on-disk
# JIR cache state.
def _write_project(base: str) -> Path {
    proj = Path(base);
    proj.mkdir(parents=True, exist_ok=True);
    (proj / "jac.toml").write_text(
        '[project]\nname = "reparse"\nversion = "0.1.0"\n' 'entry-point = "card.jac"\n'
    );
    (proj / "broken.jac").write_text(BROKEN_SRC);
    (proj / "card.jac").write_text(CARD_SRC);
    return proj;
}

def _errors_for(target: str) -> int {
    with tempfile.TemporaryDirectory() as tmp {
        proj = _write_project(tmp);
        prog = JacProgram();
        try {
            prog.compile(str(proj / target));
        } except Exception {
            ;
        }
        return len(prog.errors_had);
    }
}

test "importing a broken module does not multiply its errors" {
    direct = _errors_for("broken.jac");
    assert direct > 1 , "fixture must recover into several alerts to be meaningful";
    via_importer = _errors_for("card.jac");
    assert via_importer == direct , f"client importer reported {via_importer} errors for a {direct}-error failure";
}

test "a recompile still reports its errors to a positional slice reader" {
    with tempfile.TemporaryDirectory() as tmp {
        proj = _write_project(tmp);
        broken = str((proj / "broken.jac").resolve());
        prog = JacProgram();
        try {
            prog.compile(broken);
        } except Exception {
            ;
        }
        # Callers like the client bundle mark the length, compile, then read
        # errors_had[mark:]. Evicting inside a compile empties that slice.
        mark = len(prog.errors_had);
        try {
            prog.compile(broken);
        } except Exception {
            ;
        }
        assert len(prog.errors_had[mark:]) > 0 , "a failed recompile must still surface errors to a mark-and-slice caller";
    }
}

test "a corrected module recompiles on a long-lived program" {
    with tempfile.TemporaryDirectory() as tmp {
        proj = _write_project(tmp);
        broken = proj / "broken.jac";
        prog = JacProgram();
        try {
            prog.compile(str(proj / "card.jac"));
        } except Exception {
            ;
        }
        assert len(prog.errors_had) > 0;
        # No mtime spacing needed: invalidate_module drops the _hub_cache_times
        # stamp, and the on-disk JIR key hashes content rather than mtime.
        broken.write_text(FIXED_SRC);
        prog.errors_had = [];
        prog.invalidate_module(str(broken.resolve()));
        prog.invalidate_module(str((proj / "card.jac").resolve()));
        prog.compile(str(proj / "card.jac"));
        assert len(prog.errors_had) == 0 , f"fixing the file must clear the recorded failure: {prog.errors_had}";
    }
}

test "a clean re-parse clears the failure flag" {
    # A stale flag adds no errors -- it only silences the client-bundle
    # worklist -- so no assertion on `errors_had` can stand in for this one.
    with tempfile.TemporaryDirectory() as tmp {
        proj = _write_project(tmp);
        broken = proj / "broken.jac";
        prog = JacProgram();
        try {
            prog.compile(str(broken));
        } except Exception {
            ;
        }
        assert prog.has_failed_parse(str(broken)) , "a failed parse must be recorded";
        broken.write_text(FIXED_SRC);
        prog.compile(str(broken));
        assert not prog.has_failed_parse(str(broken)) , "a clean re-parse must clear the recorded failure";
    }
}

test "dropping a module's alerts spares dotted-name neighbors" {
    # foo.bar.jac is an independent module, not an annex of foo.jac, so
    # reloading foo.jac must not erase its diagnostics.
    with tempfile.TemporaryDirectory() as tmp {
        proj = Path(tmp);
        (proj / "jac.toml").write_text(
            '[project]\nname = "reparse"\nversion = "0.1.0"\n'
            'entry-point = "foo.jac"\n'
        );
        (proj / "foo.jac").write_text(BROKEN_SRC);
        (proj / "foo.bar.jac").write_text(BROKEN_SRC);
        prog = JacProgram();
        for name in ("foo.jac", "foo.bar.jac") {
            try {
                prog.compile(str(proj / name));
            } except Exception {
                ;
            }
        }
        import os;
        neighbor = os.path.realpath(str(proj / "foo.bar.jac"));
        assert any(
            os.path.realpath(a.loc.mod_path) == neighbor for a in prog.errors_had
        ) , "fixture must produce neighbor alerts";
        prog.drop_module_alerts(str(proj / "foo.jac"));
        assert prog.errors_had , "neighbor module alerts must survive the drop";
        assert all(
            os.path.realpath(a.loc.mod_path) == neighbor for a in prog.errors_had
        ) , f"only foo.jac's own alerts may be dropped: {prog.errors_had}";
    }
}

test "a failed parse is never written to the on-disk module cache" {
    # A cache hit replays no alerts, so serving a failed module's bytecode
    # from disk would report the import as clean. The write seam gates on
    # parse_failed, so the cache entry must simply never exist.
    import from jaclang.jac0core.jir { get_module_cache_path }
    with tempfile.TemporaryDirectory() as tmp {
        proj = _write_project(tmp);
        broken = str((proj / "broken.jac").resolve());
        prog = JacProgram();
        try {
            prog.compile(broken);
        } except Exception {
            ;
        }
        mod = prog.mod.hub.get(JacProgram.hub_key(broken));
        assert mod is not None and mod.parse_failed , "fixture must produce a recorded failed parse";
        assert not get_module_cache_path(broken).exists() , "a parse_failed module must never reach the module cache";
    }
}
