"""An imported global resolves to the module the importer names.

Two modules both define a global TABLE; the importer takes TABLE from the
second, and FIRST from the first through a module that only re-exports it.
Native lowering must bind TABLE to the module named in its import under every
module walk order, declare no global for the other module's TABLE, and still
find a re-exported global at the module that defines it. Every imported global
is declared with the storage type its own module defines it with.
"""

import os;
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.backends.native.llvm.ir.values { GlobalVariable }

glob FIXTURE: str = str(
         Path(__file__).resolve().parent / "fixtures" / "glob_binding" / "main.jac"
     );

def module_ir(path: str, walk_order: str | None = None) -> any {
    prog = JacProgram();
    opts = CompileOptions(
        force_codespace='native',
        skip_native_engine=True,
        native_module_walk_order=walk_order
    );
    mod = prog.compile(file_path=path, options=opts);
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
    assert mod.gen.llvm_ir is not None , "No IR emitted";
    return mod.gen.llvm_ir;
}

def module_globals(llvm_ir: any, name: str) -> list[str] {
    return [
        line
        for line in str(llvm_ir).splitlines()
        if line.startswith("@") and f".{name}\"" in line.split("=")[0]
    ];
}

def glob_storage(llvm_ir: any) -> dict[str, str] {
    return {
        symbol: str(gv.value_type)
        for (symbol, gv) in llvm_ir.globals.items()
        if isinstance(gv, GlobalVariable)
    };
}

test "an imported global binds to the module its import names" {
    defined = glob_storage(module_ir(str(Path(FIXTURE).parent / "second_table.jac")));
    for order in [None, "reverse", "shuffle:7"] {
        llvm_ir = module_ir(FIXTURE, order);
        found = module_globals(llvm_ir, "TABLE");
        assert len(found) == 1 , f"{order}: {found}";
        assert "second_table" in found[0] , f"{order}: {found}";
        first = module_globals(llvm_ir, "FIRST");
        assert len(first) == 1 and "first_table" in first[0] , f"{order}: {first}";
        declared = glob_storage(llvm_ir);
        for name in ["ESC", "NONE_GLOB", "NONE_DECL", "Box.EMPTY"] {
            symbols = [
                s
                for s in defined
                if s.endswith(f".{name}")
            ];
            assert len(symbols) == 1 , f"{name}: {defined}";
            assert declared.get(symbols[0]) == defined[symbols[0]] , (
                f"{order} {name}: main declares {declared.get(symbols[0])}, "
                f"second_table stores {defined[symbols[0]]}"
            );
        }
    }
}

test "a Final scalar glob another module defines folds into its readers" {
    import tempfile;
    with tempfile.TemporaryDirectory() as directory {
        (Path(directory) / "sizes.jac").write_text(
            "glob HEADER_SIZE: Final[i64] = 16,\n     MASK: Final[u64] = 18446744073709551612;\n"
        );
        main = Path(directory) / "reader.jac";
        main.write_text(
            """import from sizes { HEADER_SIZE, MASK }
def payload(address: i64) -> i64 {
    return address - HEADER_SIZE;
}
def masked(bits: u64) -> u64 {
    return bits & MASK;
}
with entry {
    print(payload(48), masked(u64(7)));
}
"""
        );
        prog = JacProgram();
        mod = prog.compile(
            file_path=str(main),
            options=CompileOptions(force_codespace='native', skip_native_engine=True)
        );
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        text = str(mod.gen.llvm_ir);
    }
    loads = [
        line
        for line in text.splitlines()
        if "load" in line and ("HEADER_SIZE" in line or "MASK" in line)
    ];
    assert not loads , loads;
}

test "a Final glob of a module with a platform variant folds the variant's value" {
    import tempfile;
    import from jaclang.compiler.frontend.codeinfo {
        native_target_arch,
        native_target_os
    }
    with tempfile.TemporaryDirectory() as directory {
        (Path(directory) / "offsets.jac").write_text(
            "glob STATE_OFFSET: Final[i64] = 0;\n"
        );
        suffix = f"{native_target_os()}.{native_target_arch()}";
        (Path(directory) / f"offsets.{suffix}.jac").write_text(
            "glob STATE_OFFSET: Final[i64] = 11864;\n"
        );
        main = Path(directory) / "reader.jac";
        main.write_text(
            """import from offsets { STATE_OFFSET }
def state_of(base: i64) -> i64 {
    return base + STATE_OFFSET;
}
with entry {
    print(state_of(8));
}
"""
        );
        prog = JacProgram();
        mod = prog.compile(
            file_path=str(main),
            options=CompileOptions(force_codespace='native', skip_native_engine=True)
        );
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        text = str(mod.gen.llvm_ir);
    }
    start = text.index("define i64 @");
    start = text.index("state_of", start);
    body = text[text.rindex("define", 0, start):];
    body = body[:body.index("\n}")];
    assert "11864" in body , body;
}

test "a global imported under an alias reads the exporting module's value" {
    import tempfile;
    import from tests.support { assert_native_identity }
    with tempfile.TemporaryDirectory() as directory {
        (Path(directory) / "flags.jac").write_text(
            "glob FLAG: i64 = 524288,\n     OTHER: i64 = 7;\n"
        );
        (Path(directory) / "core.jac").write_text(
            """import from flags { FLAG as FLAG_VALUE, OTHER as OTHER_VALUE }
glob FLAG: i32 = i32(FLAG_VALUE),
     RENAMED: i32 = i32(OTHER_VALUE);
def flag_now -> i64 {
    return FLAG_VALUE;
}
"""
        );
        main = Path(directory) / "reader.jac";
        main.write_text(
            """import from core { FLAG, RENAMED, flag_now }
with entry {
    print(FLAG, RENAMED, flag_now());
}
"""
        );
        out = assert_native_identity(str(main));
    }
    assert out.split() == ["524288", "7", "524288"] , out;
}
