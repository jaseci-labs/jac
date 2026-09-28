"""An imported global resolves to the module the importer names.

Two modules both define a global TABLE; the importer takes TABLE from the
second, and FIRST from the first through a module that only re-exports it.
Native lowering must bind TABLE to the module named in its import under every
module walk order, declare no global for the other module's TABLE, and still
find a re-exported global at the module that defines it.
"""

import os;
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE: str = str(
         Path(__file__).resolve().parent / "fixtures" / "glob_binding" / "main.jac"
     );

def module_globals(walk_order: str | None, name: str) -> list[str] {
    prog = JacProgram();
    opts = CompileOptions(
        force_codespace='native',
        skip_native_engine=True,
        native_module_walk_order=walk_order
    );
    mod = prog.compile(file_path=FIXTURE, options=opts);
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
    assert mod.gen.llvm_ir is not None , "No IR emitted";
    return [
        line
        for line in str(mod.gen.llvm_ir).splitlines()
        if line.startswith("@") and f".{name}\"" in line.split("=")[0]
    ];
}

test "an imported global binds to the module its import names" {
    for order in [None, "reverse", "shuffle:7"] {
        found = module_globals(order, "TABLE");
        assert len(found) == 1 , f"{order}: {found}";
        assert "second_table" in found[0] , f"{order}: {found}";
        first = module_globals(order, "FIRST");
        assert len(first) == 1 and "first_table" in first[0] , f"{order}: {first}";
    }
}
