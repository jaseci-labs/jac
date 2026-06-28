"""Shared scaffolding for the c2jac transpiler tests.

Every c2jac test file needs the same handful of helpers: locate a fixture,
transpile it, and recompile the emitted Jac to prove it is valid *compiler
input* (not merely the right substrings). These were copy-pasted per file; this
is the single source. Files import them under their own local names via `as`.
"""

import os;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.c2jac.driver { transpile_c_str }
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

def transpile_fixture_tags(name: str) -> tuple {
    # (jac_str, tags) for fixture `name`.
    return transpile_c_str(read_fixture(name), name);
}

def transpile_fixture(name: str) -> str {
    # Emitted Jac for fixture `name` (tags dropped).
    (jac_str, tags) = transpile_fixture_tags(name);
    return jac_str;
}

def recompile_errors(jac_str: str, name: str) -> list {
    # Round-trip guard: emitted Jac must be valid compiler input, not merely
    # contain the right substrings. Write it to a temp .jac and recompile; a
    # non-empty error list means c2jac produced Jac the compiler rejects.
    out_dir = tempfile.mkdtemp();
    stem = name.rsplit(".", 1)[0];
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
