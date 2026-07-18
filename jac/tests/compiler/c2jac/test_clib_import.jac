"""Import-time C header binding (jaseci #7145, Leg 2 / Phase 3B).

`import from clib("lib", header="hdr.h") { syms }` reads the header at load
time and synthesizes `Import.clib_decls` in place, so the binding flows through
the native FFI substrate with no intermediate `.na.jac` file. These tests prove
the selection is honoured, the synthesized import compiles, a bound function
makes a real extern call through the JIT, and the compact `clib(...)` form
round-trips through `unparse`.
"""

import os;
import ctypes;
import tempfile;
import from jaclang.jac0core.program { JacProgram }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.jir { _clib_header_deps, compute_module_key }

def _libm -> str | None {
    for cand in [
        "/usr/lib/libm.so.6",
        "/lib/x86_64-linux-gnu/libm.so.6",
        "/usr/lib/x86_64-linux-gnu/libm.so.6"
    ] {
        if os.path.exists(cand) {
            return cand;
        }
    }
    return None;
}

def _build(header_src: str, app_src: str) -> tuple {
    # Write a header + a .na.jac importer into one temp dir and compile the app.
    d = tempfile.mkdtemp();
    with open(os.path.join(d, "hdr.h"), "w") as f {
        f.write(header_src);
    }
    app_path = os.path.join(d, "app.na.jac");
    with open(app_path, "w") as f {
        f.write(app_src);
    }
    prog = JacProgram();
    ir = prog.compile(file_path=app_path);
    return (prog, ir);
}

test "a clib header import synthesizes clib_decls and consumes the selection" {
    hdr = "double sqrt(double x);\nint junk(int a);\n";
    app = 'import from clib("m", header="hdr.h") { sqrt }\n';
    (prog, ir) = _build(hdr, app);
    assert not prog.errors_had , f"errors: {[str(e) for e in prog.errors_had]}";
    imps = [
        k
        for k in ir.get_all_sub_nodes(typ=uni.Import)
        if k.clib_header is not None
    ];
    assert len(imps) == 1 , "expected one header clib import";
    imp = imps[0];
    # the selection filters the header: only `sqrt` is bound, `junk` is dropped.
    decl_names = [
        d.name_ref.sym_name
        for d in imp.clib_decls
        if isinstance(d, uni.Ability)
    ];
    assert decl_names == ["sqrt"] , decl_names;
    assert len(imp.items) == 0 , "selection items should be consumed into decls";
}

test "a clib header import binds a struct and its using function" {
    hdr = "typedef struct { int x; int y; } Pt;\nint pt_sum(Pt p);\n";
    app = 'import from clib("g", header="hdr.h") { Pt, pt_sum }\n';
    (prog, ir) = _build(hdr, app);
    assert not prog.errors_had , f"errors: {[str(e) for e in prog.errors_had]}";
    imp = [
        k
        for k in ir.get_all_sub_nodes(typ=uni.Import)
        if k.clib_header is not None
    ][0];
    kinds = [type(d).__name__ for d in imp.clib_decls];
    assert "Archetype" in kinds and "Ability" in kinds , kinds;
}

test "a clib header binding drives a real extern call through the JIT" {
    libm = _libm();
    if libm is None {
        return;
    }
    hdr = "double sqrt(double x);\n";
    app = f'import from clib("{libm}", header="hdr.h") {{ sqrt }}\n' + "\ndef:pub call_sqrt(x: f64) -> f64 {\n    return sqrt(x);\n}\n\nwith entry {}\n";
    (prog, ir) = _build(hdr, app);
    assert not prog.errors_had , f"errors: {[str(e) for e in prog.errors_had]}";
    eng = ir.gen.native_engine;
    if eng is None {
        return;
    }
    addr = eng.get_function_address("call_sqrt");
    assert addr != 0 , "call_sqrt not linked into the JIT engine";
    fn = ctypes.CFUNCTYPE(ctypes.c_double, ctypes.c_double)(addr);
    assert fn(16.0) == 4.0 , f"expected sqrt(16.0)==4.0 through the header binding, got {fn(
        16.0
    )}";
}

test "a bound header is a cache dependency, so editing it flips the module key" {
    d = tempfile.mkdtemp();
    hdr_path = os.path.join(d, "hdr.h");
    with open(hdr_path, "w") as f {
        f.write("double sqrt(double x);\n");
    }
    sub_path = os.path.join(d, "sub.h");
    with open(sub_path, "w") as f {
        f.write("int a;\n");
    }
    app_path = os.path.join(d, "app.na.jac");
    with open(app_path, "w") as f {
        f.write('import from clib("m", header="hdr.h") { sqrt }\n');
    }
    deps = [os.path.basename(p) for p in _clib_header_deps(app_path)];
    assert "hdr.h" in deps , deps;
    k0 = compute_module_key(app_path);

    # editing the bound header changes the key (cache would be re-synthesized).
    with open(hdr_path, "w") as f {
        f.write("double sqrt(double x);\nint frexp(double x);\n");
    }
    k1 = compute_module_key(app_path);
    assert k0 != k1 , "editing the bound header must invalidate the .jir";

    # a quoted-local #include is tracked transitively.
    with open(hdr_path, "w") as f {
        f.write('#include "sub.h"\ndouble sqrt(double x);\n');
    }
    assert "sub.h" in [os.path.basename(p) for p in _clib_header_deps(app_path)] , "transitive #include must be tracked";
    k2 = compute_module_key(app_path);
    with open(sub_path, "w") as f {
        f.write("int b;\n");
    }
    assert compute_module_key(app_path) != k2 , "editing an included header must invalidate";

    # a missing header degrades gracefully (no crash) and still flips the key.
    os.remove(hdr_path);
    os.remove(sub_path);
    assert compute_module_key(app_path) != k2 , "removing a header must invalidate";
}

test "the compact clib(...) form round-trips through unparse" {
    hdr = "double sqrt(double x);\n";
    app = 'import from clib("m", header="hdr.h") { sqrt }\n';
    (prog, ir) = _build(hdr, app);
    assert not prog.errors_had , f"errors: {[str(e) for e in prog.errors_had]}";
    out = ir.unparse();
    # the sugar is preserved (not expanded to the full binding decls) and is
    # rendered tight (no loose spaces around the parens/`=`), like a call.
    assert 'clib("m", header="hdr.h")' in out , out;
    assert "sqrt" in out , out;
    # and the round-tripped text still compiles.
    d = tempfile.mkdtemp();
    with open(os.path.join(d, "hdr.h"), "w") as f {
        f.write(hdr);
    }
    p2 = os.path.join(d, "rt.na.jac");
    with open(p2, "w") as f {
        f.write(out);
    }
    prog2 = JacProgram();
    prog2.compile(file_path=p2);
    assert not prog2.errors_had , f"round-tripped source does not compile: {[
        str(e) for e in prog2.errors_had
    ]}";
}
