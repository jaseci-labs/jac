"""Tests for the OwnershipCheckPass (Phase 1 — E1301 use-after-move).

Compiles fixtures with type checking (which runs the type-check schedule the
OwnershipCheckPass slots into) and asserts on the emitted E13xx diagnostics.
"""

import os;
import jaclang.jac0core.unitree as uni;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "ownership"
     );

"""Compile a fixture with type checking. Returns the JacProgram."""
def compile_fixture(fixture_name: str) -> JacProgram {
    path = os.path.join(FIXTURES, fixture_name);
    program = JacProgram();
    program.compile(path, type_check=True);
    return program;
}

"""Count diagnostics with a specific code across errors and warnings."""
def count_code(program: JacProgram, code: str) -> int {
    count = 0;
    for alert in (list(program.errors_had) + list(program.warnings_had)) {
        if alert.code is not None and alert.code.code == code {
            count += 1;
        }
    }
    return count;
}

test "E1301: use of an own binding after it is moved" {
    prog = compile_fixture("use_after_move.jac");
    assert count_code(prog, "E1301") == 1 , f"expected one E1301, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "no E1301 when the moved-from binding is not read again" {
    prog = compile_fixture("move_only_ok.jac");
    assert count_code(prog, "E1301") == 0 , f"unexpected E1301, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "reassigning a moved-from own binding revives it" {
    prog = compile_fixture("reassign_revives.jac");
    assert count_code(prog, "E1301") == 0 , f"unexpected E1301, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "un-annotated bindings are never move-checked" {
    prog = compile_fixture("unannotated_untouched.jac");
    assert count_code(prog, "E1301") == 0 , f"unexpected E1301, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "E1301: a conditional move reaching a later use is flagged" {
    prog = compile_fixture("branch_use_after_move.jac");
    assert count_code(prog, "E1301") == 1 , f"expected one E1301, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "no E1301 when mutually-exclusive branches each move the binding" {
    prog = compile_fixture("branch_exclusive_ok.jac");
    assert count_code(prog, "E1301") == 0 , f"unexpected E1301, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "no E1301 when a conditionally-moved binding is not used afterwards" {
    prog = compile_fixture("branch_no_use_ok.jac");
    assert count_code(prog, "E1301") == 0 , f"unexpected E1301, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

# --- Borrow states (E1302–E1305): borrow conflicts and leak detection --------
test "E1302: two live mutable borrows of the same owner conflict" {
    prog = compile_fixture("two_mut_aliases.jac");
    assert count_code(prog, "E1302") == 1 , f"expected one E1302, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "E1303: mutating an owner while a shared borrow is live is rejected" {
    prog = compile_fixture("mutate_while_shared.jac");
    assert count_code(prog, "E1303") == 1 , f"expected one E1303, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "E1304: a borrow that outlives its owner is rejected" {
    prog = compile_fixture("destroy_while_borrowed.jac");
    assert count_code(prog, "E1304") == 1 , f"expected one E1304, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "E1305: an own resource that is never consumed leaks" {
    prog = compile_fixture("owned_leak.jac");
    assert count_code(prog, "E1305") == 1 , f"expected one E1305, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "no E1305 when the own resource is handed off before scope end" {
    prog = compile_fixture("owned_consumed_ok.jac");
    assert count_code(prog, "E1305") == 0 , f"unexpected E1305, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

# --- Escaping borrows (E1306): a borrow may not outlive its creating scope ----
test "E1306: returning a borrow escapes its scope" {
    prog = compile_fixture("escaping_borrow_return.jac");
    assert count_code(prog, "E1306") == 1 , f"expected one E1306, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "E1306: storing a borrow into a field escapes its scope" {
    prog = compile_fixture("escaping_borrow_field.jac");
    assert count_code(prog, "E1306") == 1 , f"expected one E1306, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "no E1306 when the owned value itself is moved out by return" {
    prog = compile_fixture("return_move_ok.jac");
    assert count_code(prog, "E1306") == 0 , f"unexpected E1306, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "no E1305 when the owned value is moved out by return" {
    prog = compile_fixture("return_move_ok.jac");
    assert count_code(prog, "E1305") == 0 , f"unexpected E1305, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

# --- Borrow-typed parameters: returning a borrow rooted at a borrow parameter
# is the one allowed escape (P1.1 passthrough) --------------------------------
test "no E1306 when a borrow parameter is returned (single passthrough)" {
    prog = compile_fixture("param_borrow_passthrough_ok.jac");
    assert count_code(prog, "E1306") == 0 , f"unexpected E1306, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "no E1305 when an own parameter is consumed by return" {
    prog = compile_fixture("own_param_consumed_ok.jac");
    assert count_code(prog, "E1305") == 0 , f"unexpected E1305, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "E1305: an own parameter that is never consumed leaks" {
    prog = compile_fixture("own_param_leak.jac");
    assert count_code(prog, "E1305") == 1 , f"expected one E1305, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

# --- Fuller escape routes (P1.1): flow boundary, subscript slot, outer scope --
test "E1306: a borrow handed to a `flow` boundary escapes" {
    prog = compile_fixture("escaping_borrow_flow.jac");
    assert count_code(prog, "E1306") == 1 , f"expected one E1306, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "E1306: storing a borrow into a subscript slot escapes" {
    prog = compile_fixture("escaping_borrow_subscript.jac");
    assert count_code(prog, "E1306") == 1 , f"expected one E1306, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "E1306: a borrow assigned into an outer scope outlives its owner" {
    prog = compile_fixture("escaping_borrow_outlives_owner.jac");
    assert count_code(prog, "E1306") == 1 , f"expected one E1306, errors={[
        str(e) for e in prog.errors_had
    ]}";
    assert count_code(prog, "E1304") == 0 , f"unexpected E1304, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

# --- Membrane (P1.2): sealing an own value into managed storage moves it in;
# the source is consumed, so it does not leak (E1305) nor escape (E1306). ------
test "no E1305/E1306 when an owned value is sealed into a managed field" {
    prog = compile_fixture("membrane_seal_in_ok.jac");
    assert count_code(prog, "E1305") == 0 , f"unexpected E1305, errors={[
        str(e) for e in prog.errors_had
    ]}";
    assert count_code(prog, "E1306") == 0 , f"unexpected E1306, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

test "E1301: reading an owned value after it is sealed into managed storage" {
    prog = compile_fixture("membrane_use_after_seal.jac");
    assert count_code(prog, "E1301") == 1 , f"expected one E1301, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

# --- Loop-depth rule (P0.3): moving a pre-loop own binding inside a loop is
# rejected; it would be consumed on the first iteration, invalid thereafter. ---
test "E1301: moving a pre-loop own binding inside a loop body is rejected" {
    prog = compile_fixture("move_in_loop.jac");
    assert count_code(prog, "E1301") >= 1 , f"expected E1301 for loop-depth move, errors={[
        str(e) for e in prog.errors_had
    ]}";
}

# --- Phase 2 seed: a consumed, never-borrowed own binding is proven-unique, so
# the pass stamps `sym.is_proven_unique` for the backend to elide RC churn. ----
test "a consumed, unborrowed own binding is marked proven-unique" {
    path = os.path.join(FIXTURES, "proven_unique_ok.jac");
    program = JacProgram();
    program.compile(path, type_check=True);
    mod = program.find_module(path);
    assert mod is not None , "compiled module not found in hub";
    proven = 0;
    for nm in mod.get_all_sub_nodes(uni.Name) {
        if nm.sym is not None and nm.sym.is_proven_unique {
            proven += 1;
        }
    }
    assert proven >= 1 , "expected the consumed, unborrowed own binding to be proven-unique";
}
