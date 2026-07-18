"""Shared scaffolding for the c2jac (CastBuildPass) transpiler tests.

Locate a fixture and recompile emitted Jac to prove it is valid *compiler
input* (not merely the right substrings). The transpile itself now goes through
`cfront.lift` (see `test_cast_slice` / `test_cast_breadth`); this module only
owns the fixture path and the round-trip recompile guard.
"""

import os;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES: str = os.path.join(
         JAC_ROOT, "tests", "compiler", "c2jac", "fixtures"
     );

def read_fixture(name: str) -> str {
    # Raw text of fixture `name` under fixtures/.
    with open(os.path.join(FIXTURES, name)) as f {
        return f.read();
    }
}

def recompile_errors(jac_str: str, name: str) -> list {
    # Round-trip guard: emitted Jac must be valid compiler input, not merely
    # contain the right substrings. Write it to a temp .jac and recompile; a
    # non-empty error list means the lift produced Jac the compiler rejects.
    out_dir = tempfile.mkdtemp();
    stem = name.rsplit(".", 1)[0].rsplit("/", 1)[-1];
    path = os.path.join(out_dir, stem + ".jac");
    with open(path, "w") as f {
        f.write(jac_str);
    }
    prog = JacProgram();
    prog.compile(file_path=path);
    return prog.errors_had;
}

def parse_errors(jac_str: str) -> list {
    # Like recompile_errors but compiles straight from the string (no temp file)
    # — for tests that transpile inline C and only need to assert validity.
    prog = JacProgram();
    prog.compile(use_str=jac_str, file_path="emitted.jac");
    return prog.errors_had;
}
