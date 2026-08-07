"""A module that fails to parse is compiled once, not once per import path.

A module that compiles cleanly lands in `program.mod.hub` and every later
reach resolves to that cached entry. A module that *fails* to parse used to be
dropped before it reached the hub, so each independent path that reached it in
the same build -- the import walk, the type checker, the placement solver --
missed the cache, re-parsed it from scratch, and appended another full copy of
its alerts to the shared `errors_had`. One missing brace then surfaced as a
wall of identical messages in the build overlay and in editor diagnostics.

The count is what a user sees, so that is what these tests pin: reaching a
broken module through an importer must report exactly what compiling that
module directly reports.

The importer here is a client module, because that is the shape that pulls in
the extra resolution paths -- a plain server-side import reaches the broken
module once and never duplicated.
"""

import tempfile;
import time;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.program { JacProgram }

glob BROKEN_SRC = 'def broken_repro( -> {{{ SYNTAX ERROR\n',
     FIXED_SRC = 'def:pub broken_repro -> int {\n    return 7;\n}\n',
     CARD_SRC = (
         'import from .broken { broken_repro }\n\n'
         'def:pub card -> JsxElement {\n'
         '    return <div>{broken_repro()}</div>;\n}\n'
     ),
     CLEAN_SRC = 'def:pub fine -> int {\n    return 1;\n}\n',
     CLEAN_CARD_SRC = (
         'import from .clean { fine }\n\n'
         'def:pub good -> JsxElement {\n'
         '    return <div>{fine()}</div>;\n}\n'
     );

# Lay the project down in a dir of its own. Every measurement gets a fresh one
# so the on-disk JIR cache is cold -- a warm cache serves the failed module
# from disk and hides the duplication behind a correct-looking count.
def _write_project(base: str) -> Path {
    proj = Path(base);
    proj.mkdir(parents=True, exist_ok=True);
    (proj / "jac.toml").write_text(
        '[project]\nname = "reparse"\nversion = "0.1.0"\n' 'entry-point = "card.jac"\n'
    );
    (proj / "broken.jac").write_text(BROKEN_SRC);
    (proj / "card.jac").write_text(CARD_SRC);
    (proj / "clean.jac").write_text(CLEAN_SRC);
    (proj / "clean_card.jac").write_text(CLEAN_CARD_SRC);
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

test "evicting a module before reload clears its stale alerts" {
    with tempfile.TemporaryDirectory() as tmp {
        proj = _write_project(tmp);
        broken = str((proj / "broken.jac").resolve());
        prog = JacProgram();
        counts = [];
        # What the HMR reloader does per edit. Without the eviction the alerts
        # pile up on the long-lived program and each reload reports one more
        # copy of the same syntax error.
        for _ in range(3) {
            prog.invalidate_module(broken);
            prog.drop_module_alerts(broken);
            try {
                prog.compile(broken);
            } except Exception {
                ;
            }
            counts.append(len(prog.errors_had));
        }
        assert counts[0] > 1;
        assert counts == [counts[0], counts[0], counts[0]] , f"alerts accumulated across reloads: {counts}";
    }
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
        # Several callers -- the client bundle among them -- mark the list
        # length, compile, and read back errors_had[mark:]. Eviction must not
        # happen inside a compile, or the list shrinks under that slice and the
        # caller reports an empty error message for a module that just failed.
        mark = len(prog.errors_had);
        try {
            prog.compile(broken);
        } except Exception {
            ;
        }
        assert len(prog.errors_had[mark:]) > 0 , "a failed recompile must still surface errors to a mark-and-slice caller";
    }
}

test "a module that fails to parse is recorded in the hub" {
    with tempfile.TemporaryDirectory() as tmp {
        proj = _write_project(tmp);
        prog = JacProgram();
        try {
            prog.compile(str(proj / "card.jac"));
        } except Exception {
            ;
        }
        broken = str((proj / "broken.jac").resolve());
        assert broken in prog.mod.hub , "a failed module must still be recorded, so the next path resolves it";
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
        # An editor or the dev server keeps one program alive across edits, so
        # a remembered failure must not outlive the syntax error that caused it.
        time.sleep(1.1);
        broken.write_text(FIXED_SRC);
        prog.errors_had = [];
        prog.invalidate_module(str(broken.resolve()));
        prog.invalidate_module(str((proj / "card.jac").resolve()));
        prog.compile(str(proj / "card.jac"));
        assert len(prog.errors_had) == 0 , f"fixing the file must clear the recorded failure: {prog.errors_had}";
    }
}

test "caching a failure does not disturb a clean client import" {
    with tempfile.TemporaryDirectory() as tmp {
        proj = _write_project(tmp);
        prog = JacProgram();
        prog.compile(str(proj / "clean_card.jac"));
        assert len(prog.errors_had) == 0 , f"a healthy client import must still compile clean: {prog.errors_had}";
        assert str((proj / "clean.jac").resolve()) in prog.mod.hub;
    }
}
