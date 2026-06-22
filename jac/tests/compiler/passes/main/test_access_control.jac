"""Tests for project- and module-relative access-modifier enforcement.

Two axes are enforced (see AccessCheckPass):

* Module / project visibility (top-level glob / obj / def / enum / walker):
    - pub     -> visible from any module, including consuming projects
    - protect -> visible from any module within the same project (jac.toml root)
    - priv    -> visible only within the declaring module

* Member encapsulation (has / def declared inside an archetype):
    - pub     -> accessible anywhere
    - protect -> accessible in the declaring class and its subclasses
    - priv    -> accessible only inside the declaring class

Violations are warnings by default and hard errors when
``[check] enforce_access = true`` is set in jac.toml.
"""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.project.config { get_config }

glob JAC_ROOT = str(Path(jaclang.__file__).resolve().parent.parent),
     MEMBER_FIXTURE = os.path.join(
         JAC_ROOT,
         "tests",
         "compiler",
         "passes",
         "main",
         "fixtures",
         "access",
         "member_access.jac"
     );

# ──────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────
"""Count alerts carrying a given diagnostic code (errors or warnings)."""
def count_code(program: JacProgram, code: str, in_warnings: bool = False) -> int {
    alerts = program.warnings_had if in_warnings else program.errors_had;
    return len(
        [
            a
            for a in alerts
            if a.code is not None and a.code.code == code
        ]
    );
}

"""Create a throwaway project directory with a jac.toml and the given files.

`files` maps a relative path (posix-style) to file contents.
Returns the project root directory.
"""
def make_project(files: dict, enforce_access: bool = False) -> str {
    proj = tempfile.mkdtemp();
    toml = "[project]\nname = \"t\"\n";
    if enforce_access {
        toml += "\n[check]\nenforce_access = true\n";
    }
    (open(os.path.join(proj, "jac.toml"), "w")).write(toml);
    for (rel, content) in files.items() {
        full = os.path.join(proj, *rel.split("/"));
        os.makedirs(os.path.dirname(full), exist_ok=True);
        (open(full, "w")).write(content);
    }
    return proj;
}

"""Bind the active project config to `root`, compile `entry`, return the program.

Rebinding via force_discover keeps tests order-independent: each compile uses
exactly the jac.toml of the project under test.
"""
def compile_entry(
    proj: str, entry_file: str, extra_path: (str | None) = None
) -> JacProgram {
    old_jacpath = os.environ.get("JACPATH");
    if extra_path is not None {
        os.environ["JACPATH"] = extra_path;
    }
    get_config(start_path=Path(proj), force_discover=True);
    try {
        program = JacProgram();
        program.compile(os.path.join(proj, entry_file), type_check=True);
        return program;
    } finally {
        # Reset the global config so later tests re-discover their own.
        get_config(start_path=Path(JAC_ROOT), force_discover=True);
        if old_jacpath is None {
            os.environ.pop("JACPATH", None);
        } else {
            os.environ["JACPATH"] = old_jacpath;
        }
    }
}

def read_member_fixture -> str {
    return (open(MEMBER_FIXTURE)).read();
}

# ──────────────────────────────────────────────────────────────────
# Member encapsulation (OOP axis)
# ──────────────────────────────────────────────────────────────────
test "member private/protected violations are warnings by default" {
    proj = make_project({"main.jac": read_member_fixture()});
    try {
        prog = compile_entry(proj, "main.jac");
        # priv_f in Derived, priv_m in Derived, priv_f in entry -> 3
        assert count_code(prog, "W2034", in_warnings=True) == 3 , f"W2034={count_code(
            prog, 'W2034', in_warnings=True
        )}";
        # prot_f accessed at module level (outside hierarchy) -> 1
        assert count_code(prog, "W2035", in_warnings=True) == 1 , f"W2035={count_code(
            prog, 'W2035', in_warnings=True
        )}";
        # default is warnings, never errors
        assert count_code(prog, "E2034") == 0;
        assert count_code(prog, "E2035") == 0;
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}

test "member violations promote to errors with enforce_access" {
    proj = make_project({"main.jac": read_member_fixture()}, enforce_access=True);
    try {
        prog = compile_entry(proj, "main.jac");
        assert count_code(prog, "E2034") == 3 , f"E2034={count_code(prog, 'E2034')}";
        assert count_code(prog, "E2035") == 1 , f"E2035={count_code(prog, 'E2035')}";
        assert count_code(prog, "W2034", in_warnings=True) == 0;
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}

test "valid member access produces no access diagnostics" {
    proj = make_project(
        {
            "main.jac": "obj Box {\n"
            "    has :priv v: int = 0;\n"
            "    has :protect w: int = 0;\n"
            "    def get() -> int { return self.v + self.w; }\n"
            "}\n"
            "with entry { b = Box(); x = b.get(); }\n"
        },
        enforce_access=True
    );
    try {
        prog = compile_entry(proj, "main.jac");
        assert count_code(prog, "E2034") == 0;
        assert count_code(prog, "E2035") == 0;
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}

# ──────────────────────────────────────────────────────────────────
# Module visibility (priv = module-only)
# ──────────────────────────────────────────────────────────────────
test "module-private symbol referenced from another module is flagged" {
    files = {
        "lib.jac": "obj :pub PubObj {}\n"
        "obj :priv PrivObj {}\n"
        "glob :priv secret = 1;\n",
        "main.jac": "import lib;\n"
        "with entry {\n"
        "    a = lib.PubObj();\n"
        "    b = lib.PrivObj();\n"
        "    c = lib.secret;\n"
        "}\n"
    };
    proj = make_project(files);
    try {
        prog = compile_entry(proj, "main.jac");
        # PrivObj + secret -> 2 cross-module private references
        assert count_code(prog, "W2037", in_warnings=True) == 2 , f"W2037={count_code(
            prog, 'W2037', in_warnings=True
        )}";
        # pub crossing module boundary is always fine
        assert count_code(prog, "W2037", in_warnings=True) < 3;
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}

test "module-private use within the same module is allowed" {
    proj = make_project(
        {
            "main.jac": "obj :priv Helper {}\n"
            "glob :priv secret = 1;\n"
            "with entry { h = Helper(); x = secret; }\n"
        }
    );
    try {
        prog = compile_entry(proj, "main.jac");
        assert count_code(prog, "W2037", in_warnings=True) == 0;
        assert count_code(prog, "E2037") == 0;
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}

# ──────────────────────────────────────────────────────────────────
# Project visibility (protect = project-only, pub = exported)
# ──────────────────────────────────────────────────────────────────
test "protected symbol crossing a project boundary is flagged" {
    lib_proj = make_project(
        {"lib.jac": "obj :pub PubObj {}\nobj :protect ProtObj {}\n"}
    );
    app_proj = make_project(
        {
            "main.jac": "import lib;\n"
            "with entry { a = lib.PubObj(); b = lib.ProtObj(); }\n"
        }
    );
    try {
        prog = compile_entry(app_proj, "main.jac", extra_path=lib_proj);
        # ProtObj is project-internal; reaching it from another project warns.
        assert count_code(prog, "W2038", in_warnings=True) == 1 , f"W2038={count_code(
            prog, 'W2038', in_warnings=True
        )}";
        # pub export crossing the boundary is fine.
        assert count_code(prog, "W2037", in_warnings=True) == 0;
    } finally {
        shutil.rmtree(lib_proj, ignore_errors=True);
        shutil.rmtree(app_proj, ignore_errors=True);
    }
}

test "protected symbol within the same project is allowed" {
    files = {
        "lib.jac": "obj :protect ProtObj {}\n",
        "main.jac": "import lib;\nwith entry { b = lib.ProtObj(); }\n"
    };
    proj = make_project(files);
    try {
        prog = compile_entry(proj, "main.jac");
        assert count_code(prog, "W2038", in_warnings=True) == 0;
        assert count_code(prog, "E2038") == 0;
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}

# ──────────────────────────────────────────────────────────────────
# pub library endpoints need not be used inside their own project
# ──────────────────────────────────────────────────────────────────
test "unused pub export is not reported" {
    proj = make_project(
        {"lib.jac": "obj :pub Exported {}\ndef :pub api() -> int { return 1; }\n"}
    );
    try {
        prog = compile_entry(proj, "lib.jac");
        # No access diagnostics for an unreferenced exported endpoint.
        assert count_code(prog, "W2037", in_warnings=True) == 0;
        assert count_code(prog, "W2038", in_warnings=True) == 0;
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}
