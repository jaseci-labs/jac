"""Import pass tests – migrated from test_import_pass.py.

Note: test_py_raise_map and test_py_raised_mods are skipped (TODO: Fix when we have type checker).
"""

import os;
import io;
import sys;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
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

test "import auto impl" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "autoimpl.jac"));
    num_modules = len(list(prog.mod.hub.values())[0].impl_mod);
    mod_names = [i.name for i in list(prog.mod.hub.values())[0].impl_mod];
    assert num_modules == 5;
    assert "getme.impl" in mod_names;
    assert "autoimpl.impl" in mod_names;
    assert "autoimpl.something.else.impl" in mod_names;
    assert "autoimpl.shared.impl" in mod_names;
}

test "import include auto impl" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "incautoimpl.jac"));
    num_modules = len(list(prog.mod.hub.values())[1].impl_mod) + 1;
    mod_names = [i.name for i in list(prog.mod.hub.values())[1].impl_mod];
    assert num_modules == 6;
    assert list(prog.mod.hub.values())[0].name == "incautoimpl";
    assert list(prog.mod.hub.values())[1].name == "autoimpl";
    assert "getme.impl" in mod_names;
    assert "autoimpl.impl" in mod_names;
    assert "autoimpl.something.else.impl" in mod_names;
    assert "autoimpl.shared.impl" in mod_names;
}

test "annexable by discovery" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "incautoimpl.jac"));
    count = 0;
    all_mods = prog.mod.hub.values();
    assert len(all_mods) == 7;
    for main_mod in all_mods {
        for i in main_mod.impl_mod {
            if i.name not in ["autoimpl", "incautoimpl"] {
                count += 1;
                assert i.annexable_by == os.path.join(FIXTURES, "autoimpl.jac");
            }
        }
    }
    assert count == 5;
}

test "annexable by shared folder" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "autoimpl.jac"));
    main_mod = list(prog.mod.hub.values())[0];
    shared_impl = None;
    for m in main_mod.impl_mod {
        if m.name == "autoimpl.shared.impl" {
            shared_impl = m;
            break;
        }
    }
    assert shared_impl is not None , "Expected shared folder impl to be loaded";
    assert shared_impl.annexable_by == os.path.join(FIXTURES, "autoimpl.jac");
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
