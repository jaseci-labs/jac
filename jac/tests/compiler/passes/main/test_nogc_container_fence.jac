"""Regression tests for the headerless nogc container-element fence (E1406).

Under `--enforce-nogc --gc none`, owned containers of *str* elements are
supported: fresh values (f-strings, concats, str slices, call results) move
into the container, while named bindings, string literals, and container-
element reads are copied in at codegen, so the container always owns heap
storage it can free at drop. Borrowed params and obj-field reads would alias
storage the container must not free, so they stay fenced, as do non-str heap
elements (archetypes, nested containers), whose element-drop monomorphization
is still deferred. These tests pin both sides: every unsupported write is
fenced, and the supported shapes (scalar containers, str containers, and a
same-named method on a non-container user type) stay clean.

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
test "fresh archetypes move into list appends since #7857 Phase B" {
    assert enforced_codes("append_obj.jac") == [];
}

test "E1406: appending a borrowed str param into a list" {
    assert enforced_codes("append_borrow_fenced.jac") == ["E1406"];
}

test "E1406: appending an obj field read into a list" {
    assert enforced_codes("append_field_fenced.jac") == ["E1406"];
}

test "E1406: index-assigning an owned heap object as a dict value" {
    assert enforced_codes("dict_heap_val.jac") == ["E1406"];
}

test "E1406: adding an owned heap object to a set" {
    assert enforced_codes("set_add_obj.jac") == ["E1406"];
}

test "E1406: a dict literal with an owned heap value" {
    assert enforced_codes("dict_literal_heap.jac") == ["E1406"];
}

test "E1406: a set literal with an owned heap element" {
    assert enforced_codes("set_literal_heap.jac") == ["E1406"];
}

test "E1406: an owned heap object used as a dict key" {
    assert enforced_codes("dict_heap_key.jac") == ["E1406"];
}

# --- Supported shapes stay clean: no false positives. -------------------------
test "appending freshly-built strings into a list is clean" {
    assert enforced_codes("append_built_str.jac") == [];
}

test "append of f-string, concat, slice, and call-result strings is clean" {
    assert enforced_codes("append_fresh_str_ok.jac") == [];
}

test "appending a named owned string copies it in; the source stays live" {
    assert enforced_codes("append_named_copy_ok.jac") == [];
}

test "adding freshly-built strings to a set is clean" {
    assert enforced_codes("set_add_fresh_str_ok.jac") == [];
}

test "str keys and values entering a dict are clean" {
    assert enforced_codes("dict_str_val_ok.jac") == [];
}

test "a list literal of fresh, static, and named str elements is clean" {
    assert enforced_codes("list_literal_fresh_ok.jac") == [];
}

test "overwriting a list slot with a fresh str is clean" {
    assert enforced_codes("list_set_str_ok.jac") == [];
}

test "scalar list/dict/set with append/add/index is clean" {
    assert enforced_codes("scalar_containers_ok.jac") == [];
}

test "indexing a container with a scalar-returning call is clean" {
    assert enforced_codes("scalar_call_index_ok.jac") == [];
}

test "a list of string literals (static, not owned heap) is clean" {
    assert enforced_codes("str_literal_list_ok.jac") == [];
}

test "`.append` on a non-container user type does not trip the fence" {
    assert enforced_codes("user_append_ok.jac") == [];
}
