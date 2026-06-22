"""Import pass tests – migrated from test_import_pass.py.

Note: test_py_raise_map and test_py_raised_mods are skipped (TODO: Fix when we have type checker).
"""

import os;
import io;
import sys;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.bccache { discover_annex_files, discover_base_file }
import from jaclang.cli.commands { execution }

glob FIXTURES = os.path.join(
         str(Path(jaclang.__file__).parent.parent),
         "tests",
         "compiler",
         "passes",
         "main",
         "fixtures"
     );

test "pygen jac cli" {
    out = JacProgram();
    out.compile(os.path.join(FIXTURES, "base.jac"));
    assert not out.errors_had;
    mod = out.mod.hub[os.path.join(FIXTURES, "impl", "imps.jac")];
    assert "56" in str(mod.to_dict());
}

"""Basenames of the annex files whose statements were spliced into a module."""
def _merged_annex_files(mod: object) -> set[str] {
    return {
        os.path.basename(st.loc.mod_path)
        for st in mod.body
        if st.loc.mod_path and st.loc.mod_path.endswith(".impl.jac")
    };
}

test "import auto impl" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "autoimpl.jac"));
    assert not prog.errors_had;
    # All five .impl.jac annexes (same dir, foo.impl/ folder, shared impl/ folder)
    # are discovered and attributed to autoimpl.jac.
    annexes = discover_annex_files(os.path.join(FIXTURES, "autoimpl.jac"), ".impl.jac");
    assert len(annexes) == 5;
    for a in annexes {
        assert discover_base_file(a) == os.path.join(FIXTURES, "autoimpl.jac");
    }
    # Annexes are now spliced into the head's own tree (no separate impl module);
    # the four non-empty ones contribute statements tagged by loc.mod_path.
    merged = _merged_annex_files(list(prog.mod.hub.values())[0]);
    assert "getme.impl.jac" in merged;
    assert "autoimpl.impl.jac" in merged;
    assert "autoimpl.something.else.impl.jac" in merged;
    assert "autoimpl.shared.impl.jac" in merged;
}

test "import include auto impl" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "incautoimpl.jac"));
    assert not prog.errors_had;
    hub_mods = list(prog.mod.hub.values());
    assert hub_mods[0].name == "incautoimpl";
    assert hub_mods[1].name == "autoimpl";
    # autoimpl's annexes are merged into the included autoimpl module.
    merged = _merged_annex_files(hub_mods[1]);
    assert "getme.impl.jac" in merged;
    assert "autoimpl.impl.jac" in merged;
    assert "autoimpl.something.else.impl.jac" in merged;
    assert "autoimpl.shared.impl.jac" in merged;
}

test "annexable by discovery" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "incautoimpl.jac"));
    assert not prog.errors_had;
    # Annexes are merged, not stored as modules, so the hub holds only the two
    # real modules.
    hub_names = [m.name for m in prog.mod.hub.values()];
    assert "incautoimpl" in hub_names and "autoimpl" in hub_names;
    # Every annex autoimpl owns is attributed back to autoimpl.jac (this is what
    # Module.annexable_by resolves to via discover_base_file).
    annexes = discover_annex_files(os.path.join(FIXTURES, "autoimpl.jac"), ".impl.jac");
    assert len(annexes) == 5;
    for a in annexes {
        assert discover_base_file(a) == os.path.join(FIXTURES, "autoimpl.jac");
    }
}

test "annexable by shared folder" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "autoimpl.jac"));
    assert not prog.errors_had;
    shared = os.path.join(FIXTURES, "impl", "autoimpl.shared.impl.jac");
    # The shared-folder annex is discovered, attributed to autoimpl.jac...
    annexes = discover_annex_files(os.path.join(FIXTURES, "autoimpl.jac"), ".impl.jac");
    assert shared in annexes , "Expected shared folder impl to be discovered";
    assert discover_base_file(shared) == os.path.join(FIXTURES, "autoimpl.jac");
    # ...and its statements are spliced into the head.
    assert "autoimpl.shared.impl.jac" in _merged_annex_files(
        list(prog.mod.hub.values())[0]
    ) , "Expected shared folder impl to be merged into head";
}

test "double empty anx" {
    old_stdout = sys.stdout;
    buf = io.StringIO();
    sys.stdout = buf;
    try {
        execution.run(os.path.join(FIXTURES, "autoimpl.jac"));
        execution.run(os.path.join(FIXTURES, "autoimpl.jac"));
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = buf.getvalue();
    assert "foo" in stdout_value;
    assert "bar" in stdout_value;
    assert "baz" in stdout_value;
}

test "circular import" {
    state = JacProgram();
    state.compile(os.path.join(FIXTURES, "circular_import.jac"));
    assert not state.errors_had;
    assert len(state.errors_had) == 0;
}
