"""Regression tests for the headerless nogc container-element fence (E1406).

Under `--enforce-nogc --gc none`, owned containers of heap elements are not yet
supported (element-drop monomorphization is deferred). Before this fence the
OwnershipCheckPass only rejected list *literals* of heap elements, so heap
elements that entered a container any other way (`append`/`add`/`insert`, an
index-assigned dict/set value, a dict/set literal, or a freshly-built (owned)
string) slipped through to headerless codegen and either leaked (the container
drop helper frees only the backing array, never the entries) or left a dangling
pointer. These tests pin that every such write is now fenced, while the fully
supported shapes (scalar containers, string *literals*, and a same-named method
on a non-container user type) stay clean.

Each fixture is compiled through the real type-check schedule with enforcement
enabled via CompileOptions, matching `jac nacompile --enforce-nogc --gc none`.
"""

import os;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from tests.support { JAC_ROOT }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "nogc_containers"
     );

"""Compile a fixture as a headerless nogc-enforced module; return its unique,
sorted diagnostic codes."""
def enforced_codes(fixture: str) -> list[str] {
    path = os.path.join(FIXTURES, fixture);
    prog = JacProgram();
    opts = CompileOptions(
        aot_mode=True, type_check=True, na_gc_mode="none", nogc_enforce_all=True
    );
    prog.compile(file_path=path, options=opts);
    codes: set[str] = set();
    for alert in list(prog.errors_had) {
        if alert.code is not None {
            codes.add(alert.code.code);
        }
    }
    return sorted(codes);
}

# --- Heap element reaching a container by any write must be fenced (E1406). ----
test "E1406: appending an owned heap object into a list" {
    assert enforced_codes("append_obj.na.jac") == ["E1406"];
}

test "E1406: appending a freshly-built (owned heap) string into a list" {
    assert enforced_codes("append_built_str.na.jac") == ["E1406"];
}

test "E1406: index-assigning an owned heap object as a dict value" {
    assert enforced_codes("dict_heap_val.na.jac") == ["E1406"];
}

test "E1406: adding an owned heap object to a set" {
    assert enforced_codes("set_add_obj.na.jac") == ["E1406"];
}

test "E1406: a dict literal with an owned heap value" {
    assert enforced_codes("dict_literal_heap.na.jac") == ["E1406"];
}

test "E1406: a set literal with an owned heap element" {
    assert enforced_codes("set_literal_heap.na.jac") == ["E1406"];
}

test "E1406: an owned heap object used as a dict key" {
    assert enforced_codes("dict_heap_key.na.jac") == ["E1406"];
}

# --- Supported shapes stay clean: no false positives. -------------------------
test "scalar list/dict/set with append/add/index is clean" {
    assert enforced_codes("scalar_containers_ok.na.jac") == [];
}

test "indexing a container with a scalar-returning call is clean" {
    assert enforced_codes("scalar_call_index_ok.na.jac") == [];
}

test "a list of string literals (static, not owned heap) is clean" {
    assert enforced_codes("str_literal_list_ok.na.jac") == [];
}

test "`.append` on a non-container user type does not trip the fence" {
    assert enforced_codes("user_append_ok.na.jac") == [];
}
