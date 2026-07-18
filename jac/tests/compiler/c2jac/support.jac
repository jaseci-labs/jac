"""Shared scaffolding for the c2jac (CastBuildPass) transpiler tests.

Locate a fixture and recompile emitted Jac to prove it is valid *compiler
input* (not merely the right substrings). The transpile itself now goes through
`cfront.lift` (see `test_cast_slice` / `test_cast_breadth`); this module only
owns the fixture path, the breadth inventory, and the round-trip recompile guard.
"""

import os;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES: str = os.path.join(
         JAC_ROOT, "tests", "compiler", "c2jac", "fixtures"
     );

# (fixture, sorted expected diagnostic codes). Every directive-free fixture the
# breadth suite covers; `[]` == a fully faithful lift with no best-effort holes.
# Shared by the static breadth test and the dynamic lift-oracle coverage ratchet.
glob BREADTH: list[tuple[str, list[str]]] = [
         ("arrays.c", []),
         ("cfor.c", []),
         ("control_flow.c", []),
         ("do_while.c", []),
         ("do_while_continue.c", ["W4203"]),
         ("edge_cases.c", ["W4202", "W4290", "W4290"]),
         ("edge_cases_2.c", ["W4207", "W4290"]),
         ("edge_cases_3.c", ["W4290", "W4290"]),
         ("enum_collision.c", []),
         ("enum_flags.c", []),
         ("enum_simple.c", []),
         ("enum_tu_collision.c", ["W4290"]),
         ("expr_stmts.c", []),
         ("for_array_body.c", []),
         ("for_block_spacing.c", []),
         ("for_body_rich.c", []),
         ("for_call_body.c", []),
         ("for_cast.c", ["W4201"]),
         ("for_char_cond.c", []),
         ("for_comma.c", ["W4204"]),
         ("for_comma_init.c", []),
         ("for_comma_init_rich.c", []),
         ("for_comma_step.c", []),
         ("for_continue.c", []),
         ("for_deref.c", ["W4290"]),
         ("for_empty_stmt.c", []),
         ("for_funcall_step.c", []),
         ("for_funcall_step_continue.c", []),
         ("for_incdec_body.c", []),
         ("for_infinite_continue.c", []),
         ("for_initlist.c", []),
         ("for_multidecl_init.c", []),
         ("for_nested_cond_clobber.c", []),
         ("for_nested_dowhile.c", ["W4203"]),
         ("for_nested_switch.c", ["W4202"]),
         ("for_ptr_idiom.c", ["W4290"]),
         ("for_ternary.c", []),
         ("for_unmappable_cond.c", []),
         ("for_unsupported.c", []),
         ("hello.c", []),
         ("nonascii_str.c", []),
         ("obj_array.c", []),
         ("pointers.c", []),
         ("ptr_idioms.c", []),
         ("struct_array.c", []),
         ("struct_shape.c", []),
         ("switch_basic.c", []),
         ("switch_fallthrough.c", ["W4202"]),
         ("ternary.c", []),
         ("cpython/mysnprintf.c", ["W4207"]),
         ("cpython/pystrcmp.c", []),
         ("cpython/rotatingtree.c", [])
     ];

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
