"""Decoupling guard + smoke tests for the in-tree LLVM binding (issue #6925).

The native (`na`) JIT/codegen path no longer depends on the Python `llvmlite`
PyPI package. Its two pure-Python layers -- the IR builder (`ir`) and the
ctypes binding over the `LLVMPY_*` C ABI -- were translated to Jac with
`py2jac` and now live under `jaclang/compiler/passes/native/llvm/` as
first-party code (derived from llvmlite, BSD-2), loading the LLVMPY_* shim
directly via ctypes.

These tests (a) statically guard that no `import ... llvmlite ...` statement
creeps back into the jaclang runtime, (b) functionally smoke-test that the
in-tree `ir` builder and `binding` produce correct output, and (c) pin that
every IR type class answers `==` with a real `bool` for every other type class.
"""

import re;
import inspect;
import jaclang;
import from pathlib { Path }
import jaclang.compiler.passes.native.llvm.binding as llvm;
import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.llvm.ir { types as ir_types }

# `Type` subclasses that are never instantiated directly -- they exist only to
# share behaviour with their concrete subclasses, so they need no representative
# in the `__eq__` cross product below.
glob _ABSTRACT_IR_TYPES: set = {
         "Type",
         "Aggregate",
         "BaseStructType",
         "_BaseFloatType"
     };


"""One representative instance of every concrete `ir` type class, by class name."""
def _ir_type_specimens -> dict[str, object] {
    i32 = ir.IntType(32);
    return {
        "ArrayType": ir.ArrayType(i32, 2),
        "DoubleType": ir.DoubleType(),
        "FloatType": ir.FloatType(),
        "FunctionType": ir.FunctionType(ir.VoidType(), [i32]),
        "HalfType": ir.HalfType(),
        "IdentifiedStructType": ir.global_context.get_identified_type(
            "eq_totality.Named"
        ),
        "IntType": i32,
        "LabelType": ir.LabelType(),
        "LiteralStructType": ir.LiteralStructType([i32, i32]),
        "MetaDataType": ir.MetaDataType(),
        "PointerType": ir.PointerType(),
        "VectorType": ir.VectorType(i32, 2),
        "VoidType": ir.VoidType(),
        "_TypedPointerType": ir.PointerType(i32)
    };
}


"""Every distinct concrete `Type` subclass defined in the vendored ir.types module."""
def _concrete_ir_type_classes -> set[str] {
    found: set[str] = set();
    for obj in vars(ir_types).values() {
        if not inspect.isclass(obj) or not issubclass(obj, ir_types.Type) {
            continue;
        }
        if obj.__module__ != ir_types.__name__ {
            continue;
        }
        if obj.__name__ not in _ABSTRACT_IR_TYPES {
            found.add(obj.__name__);
        }
    }
    return found;
}

# An import statement that pulls the `llvmlite` package (any Jac import form):
#   import llvmlite.binding as x; / import from llvmlite { ir } / import type from
# `\bllvmlite\b` does not match the substring inside `libllvmlite`.
glob _IMPORT_LLVMLITE: str = r"^\s*import\b.*\bllvmlite\b";


"""Scan a source tree for import statements referencing the llvmlite package."""
def _scan_llvmlite_imports(tree: Path) -> list[str] {
    hits: list[str] = [];
    pat = re.compile(_IMPORT_LLVMLITE);
    for src in sorted(list(tree.rglob("*.jac")) + list(tree.rglob("*.py"))) {
        if not src.is_file() {
            continue;
        }
        n = 0;
        for line in src.read_text().splitlines() {
            n += 1;
            if pat.search(line) {
                hits.append(f"{src}:{n}: {line.strip()}");
            }
        }
    }
    return hits;
}


test "jaclang runtime does not import the python llvmlite package" {
    hits = _scan_llvmlite_imports(Path(jaclang.__file__).parent);
    assert not hits , "llvmlite is decoupled (#6925) -- import "
        + "jaclang.compiler.passes.native.llvm{.binding} instead. Offenders:\n"
        + "\n".join(hits);
}


test "vendored ir builder emits expected IR" {
    m = ir.Module(name="m");
    i32 = ir.IntType(32);
    fnty = ir.FunctionType(i32, [i32, i32]);
    fn = ir.Function(m, fnty, name="add");
    blk = fn.append_basic_block("entry");
    b = ir.IRBuilder(blk);
    (x, y) = fn.args;
    b.ret(b.add(x, y));
    text = str(m);
    assert 'define i32 @"add"' in text;
    assert "add i32" in text;
}


test "vendored binding parses, verifies and prints a module" {
    txt = "define i32 @add(i32 %a, i32 %b) {\n"
        + "entry:\n  %r = add i32 %a, %b\n  ret i32 %r\n}\n";
    mod = llvm.parse_assembly(txt);
    mod.verify();
    out = str(mod);
    assert "define i32 @add" in out;
    assert "add i32" in out;
}


test "every concrete ir type class has an __eq__ specimen" {
    specimens = _ir_type_specimens();
    missing = _concrete_ir_type_classes() - set(specimens.keys());
    assert not missing , "new ir type class(es) "
        + f"{sorted(missing)} need a specimen in _ir_type_specimens() so the "
        + "__eq__ totality cross product keeps covering the whole module";
    for (name, spec) in specimens.items() {
        assert type(spec).__name__ == name , f"specimen for {name} is a "
            + f"{type(spec).__name__}";
    }
}


test "ir type __eq__ is total across every class pair" {
    specimens = _ir_type_specimens();
    for (lname, left) in sorted(specimens.items()) {
        for (rname, right) in sorted(specimens.items()) {
            eq = left == right;
            assert (eq is True) or (eq is False) , f"{lname} == {rname} "
                + f"returned {eq!r}; __eq__ must be total and answer with a "
                + "real bool, never fall off the end of the function";
            ne = left != right;
            assert (ne is True) or (ne is False) , f"{lname} != {rname} "
                + f"returned {ne!r}";
            assert ne == (not eq);
        }
        assert (left == left) is True , f"{lname} is not equal to itself";
    }
}


test "struct type is unequal, not undefined, against a pointer type" {
    i64 = ir.IntType(64);
    pair = ir.LiteralStructType([i64, i64]);
    pair_ptr = pair.as_pointer();
    assert (pair == pair_ptr) is False;
    assert bool(pair == pair_ptr) is False;
    assert (pair_ptr == pair) is False;
    assert (pair == i64) is False;
    named = ir.global_context.get_identified_type("eq_totality.Pair");
    assert (named == pair_ptr) is False;
    assert (pair == named) is False;
    assert (ir.ArrayType(i64, 2) == pair_ptr) is False;
    assert (ir.VectorType(i64, 2) == pair_ptr) is False;
    # Same class on both sides still delegates to the element compare, so a
    # partial element __eq__ leaks through the enclosing `and`.
    assert (ir.ArrayType(pair, 2) == ir.ArrayType(pair_ptr, 2)) is False;
    assert (ir.ArrayType(pair_ptr, 2) == ir.ArrayType(pair, 2)) is False;
}


test "combining two type comparisons boolean-wise agrees on untagged operands" {
    i64 = ir.IntType(64);
    i8 = ir.IntType(8);
    tagged = ir.LiteralStructType([i8, i64]).as_pointer();
    field = ir.LiteralStructType([i64, i64]).as_pointer();
    literal = ir.LiteralStructType([i64, i64]);
    # Neither operand is the tagged value type, so a routing decision built from
    # the two comparisons must see them as agreeing (#7981).
    assert ((field == tagged) != (literal == tagged)) is False;
    assert ((field == tagged) == (literal == tagged)) is True;
}
