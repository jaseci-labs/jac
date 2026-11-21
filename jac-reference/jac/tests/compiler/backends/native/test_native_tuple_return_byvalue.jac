"""A function returning a tuple of C scalars returns it by value.

Every `return (a, b)` used to allocate a reference-counted tuple box that the
caller unpacked and freed at once, so a hot helper such as JacPython's
`dict_lookup(...) -> tuple[i64, ptr[PyObject]]` paid a malloc and a free per
call. A tuple whose elements are all C scalars (raw pointers lower to i64)
holds nothing to reference-count, so its function now returns the LLVM struct
in registers. The rule reads only the declared return type, so the importer of
a function, a method's vtable slot and a `Callable` naming the signature all
agree on it; a consumer that needs a tuple object boxes the value itself.

The fixture runs every consumer shape under each memory profile and must print
what the Python backend prints; the IR test pins the by-value signatures and
that a tuple holding a managed element still returns a box.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity, compile_native_ir, names_function }

glob FIXTURE = str(
         Path(__file__).resolve().parent / "fixtures" / "tuple_return_byvalue.jac"
     );

def _defined_body(text: str, name: str) -> tuple[str, list[str]] {
    lines = text.splitlines();
    for (i, line) in enumerate(lines) {
        if line.startswith("define") and names_function(line, name) {
            body: list[str] = [];
            for inner in lines[i + 1:] {
                if inner.startswith("}") {
                    break;
                }
                body.append(inner);
            }
            return (line, body);
        }
    }
    assert False , f"no definition of {name} in the emitted IR";
    return ("", []);
}

test "scalar tuples returned by value agree with the Python backend" {
    out = assert_native_identity(FIXTURE, profiles=["managed", "rc"]);
    lines = out.splitlines();
    assert "destructured 3 9" in lines , out;
    assert "indexed 1 5 (1, 5)" in lines , out;
    assert "ptr and f64 True 2.5" in lines , out;
    assert "imported 5 2.5" in lines , out;
    assert "override 10 20 (10, 20)" in lines , out;
    assert "callable 405" in lines , out;
    assert "lambda 1810" in lines , out;
    assert "nested 91" in lines , out;
}

test "a scalar tuple return is a register struct, a managed one stays boxed" {
    text = str(compile_native_ir(FIXTURE).gen.llvm_ir);
    (ordered_def, ordered_body) = _defined_body(text, "ordered");
    assert ordered_def.startswith("define {i64, i64} ") , ordered_def;
    assert not any("__rc_alloc" in line for line in ordered_body) , ordered_body;
    (scaled_def, _) = _defined_body(text, "scaled");
    assert scaled_def.startswith("define {i64, double} ") , scaled_def;
    (checked_def, _) = _defined_body(text, "checked");
    assert checked_def.startswith("define {i1, i64} ") , checked_def;
    (bounds_def, _) = _defined_body(text, "Wide.bounds");
    assert bounds_def.startswith("define {i64, i64} ") , bounds_def;
    (labeled_def, _) = _defined_body(text, "labeled");
    assert labeled_def.split("@")[0].rstrip().endswith("*") , labeled_def;
    imported = [
        line
        for line in text.splitlines()
        if line.startswith("declare") and names_function(line, "split_ratio")
    ];
    assert imported and imported[0].startswith("declare {i64, double} ") , imported;
}
