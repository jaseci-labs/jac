"""Decoupling guard + smoke tests for the in-tree LLVM binding (issue #6925).

The native (`na`) JIT/codegen path no longer depends on the Python `llvmlite`
PyPI package. Its two pure-Python layers -- the IR builder (`ir`) and the
ctypes binding over the `LLVMPY_*` C ABI -- were translated to Jac with
`py2jac` and now live under `jaclang/compiler/passes/native/llvm/` as
first-party code (derived from llvmlite, BSD-2), loading the LLVMPY_* shim
directly via ctypes.

These tests (a) statically guard that no `import ... llvmlite ...` statement
creeps back into the jaclang runtime, and (b) functionally smoke-test that the
in-tree `ir` builder and `binding` produce correct output.
"""

import re;
import jaclang;
import from pathlib { Path }
import jaclang.compiler.passes.native.llvm.binding as llvm;
import from jaclang.compiler.passes.native.llvm { ir }

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
    assert not hits , "llvmlite is decoupled (#6925) -- import " + "jaclang.compiler.passes.native.llvm{.binding} instead. Offenders:\n" + "\n".join(
        hits
    );
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
    txt = "define i32 @add(i32 %a, i32 %b) {\n" + "entry:\n  %r = add i32 %a, %b\n  ret i32 %r\n}\n";
    mod = llvm.parse_assembly(txt);
    mod.verify();
    out = str(mod);
    assert "define i32 @add" in out;
    assert "add i32" in out;
}
