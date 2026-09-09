"""The compiler driver reports every module the moment it picks it up.

`jac run` sat silent through the whole initial client compile. The client
layer cannot narrate that stretch: by the time it asks for a file's JS, the
front end has already pulled the entire import graph through parse and type
check. Every module enters the compiler through `JacCompiler.compile`, entry
and dependency alike, so that is where progress is reported; a CLI status line
subscribes for exactly the compile it drives and nothing else.
"""

import os;
import tempfile;
import from jaclang.compiler.driver.pass_driver { compile_progress }
import from jaclang.compiler.driver.program { JacProgram }


"""A two-module project in a fresh temp dir; returns the entry's path."""
def _project -> str {
    base = os.path.realpath(tempfile.mkdtemp(prefix="jac_progress_"));
    with open(os.path.join(base, "jac.toml"), "w") as f {
        f.write("[project]\nname = \"progress\"\n");
    }
    with open(os.path.join(base, "util.jac"), "w") as f {
        f.write("def two -> int {\n    return 2;\n}\n");
    }
    main_path = os.path.join(base, "main.jac");
    with open(main_path, "w") as f {
        f.write("import from util { two }\n\nwith entry {\n    print(two());\n}\n");
    }
    return main_path;
}


test "the entry and every dependency it pulls in are reported, entry first" {
    main_path = _project();
    seen: list[str] = [];
    with compile_progress.listen(seen.append) {
        JacProgram().compile(main_path);
    }
    names = [os.path.basename(p) for p in seen];
    assert names and names[0] == "main.jac" , (
        f"the entry is reported first, saw {names}"
    );
    assert "util.jac" in names , (
        f"a dependency entering the compiler is reported too, saw {names}"
    );
}


test "a listener only hears the compile it was attached for" {
    main_path = _project();
    seen: list[str] = [];
    with compile_progress.listen(seen.append) {}
    JacProgram().compile(main_path);
    assert seen == [] , f"a detached listener heard {seen}";
}

test "nested compilation completes dependencies before their importer" {
    main_path = _project();
    active: list[str] = [];
    finished: list[str] = [];
    def on_finished(path: str) {
        assert active and active[-1] == path;
        active.pop();
        finished.append(path);
    }
    with compile_progress.listen(active.append, on_finished) {
        JacProgram().compile(main_path);
    }
    assert not active;
    assert finished[-1] == main_path;
    assert "util.jac" in [os.path.basename(p) for p in finished];
}

test "exceptions finish active work and detach both listeners" {
    import from unittest.mock { patch }
    import from jaclang.compiler.driver.compiler { JacCompiler }
    started: list[str] = [];
    finished: list[str] = [];
    main_path = _project();
    with patch.object(
        JacCompiler, "_compile_once", side_effect=RuntimeError("failed")
    ) {
        try {
            with compile_progress.listen(started.append, finished.append) {
                JacProgram().compile(main_path);
            }
            assert False , "expected the compiler failure";
        } except RuntimeError {}
    }
    assert started == [main_path];
    assert finished == started;
    JacProgram().compile(main_path);
    assert started == [main_path] and finished == [main_path];
}
