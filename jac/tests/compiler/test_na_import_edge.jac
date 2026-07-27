"""The cl -> na edge: `na import from .mod { fn }` in client code.

One marked import does three things: binds each name to a generated
`__na_bind` stub (lazy wasm instantiation via @jac/wasm_host), records the
target in the client manifest so the build emits /static/<stem>.wasm, and
compiles to nothing on the Python side -- a plain import of a native module
is the sv -> na ctypes crossing and executes the module under CPython,
which is exactly what the na marker exists to avoid (jaclang.org DOGFOOD A2).
"""

import os;
import tempfile;
import from jaclang.jac0core.program { JacProgram }

glob KERNEL_SRC: str = (
         "def:pub fib(n: int) -> int {\n"
         "    if n < 2 {\n"
         "        return n;\n"
         "    }\n"
         "    return fib(n - 1) + fib(n - 2);\n"
         "}\n"
     ),
     HOST_SRC: str = (
         "na import from .kernel { fib, fib as fast_fib }\n"
         "\n"
         "cl {\n"
         "    async def:pub show -> int {\n"
         "        return await fib(10);\n"
         "    }\n"
         "}\n"
     );

def compile_host -> object {
    tmp = tempfile.mkdtemp(prefix="jac_na_edge_");
    kernel_path = os.path.join(tmp, "kernel.na.jac");
    host_path = os.path.join(tmp, "host.jac");
    with open(kernel_path, "w") as f {
        f.write(KERNEL_SRC);
    }
    with open(host_path, "w") as f {
        f.write(HOST_SRC);
    }
    prog = JacProgram();
    return prog.compile(host_path);
}

test "na import binds generated wasm stubs in the client js" {
    mod = compile_host();
    js = mod.gen.js;
    assert '__na_bind' in js , "expected the @jac/wasm_host stub factory import";
    assert '"kernel"' in js , "expected the module stem in the bind call";
    assert '"fib"' in js , "expected the export name in the bind call";
    assert "fast_fib" in js , "expected the alias as the local binding";
}

test "na import records the target module for wasm emission" {
    mod = compile_host();
    manifest = mod.gen.client_manifest;
    assert manifest is not None;
    targets = list(manifest.na_modules);
    assert len(targets) == 1;
    assert targets[0].endswith("kernel.na.jac");
    assert "kernel" not in dict(manifest.imports) , (
        "an na import must not join manifest.imports -- the client build"
        " would try to JS-compile the native module"
    );
}

test "na import compiles to nothing on the python side" {
    mod = compile_host();
    assert "kernel" not in mod.gen.py , (
        "the na import must be inert under CPython; only a plain import of a"
        " native module means the ctypes crossing"
    );
}

test "colliding na import basenames are a build error" {
    tmp = tempfile.mkdtemp(prefix="jac_na_edge_");
    for sub in ("a", "b") {
        os.makedirs(os.path.join(tmp, sub));
        with open(os.path.join(tmp, sub, "kernel.na.jac"), "w") as f {
            f.write(KERNEL_SRC);
        }
    }
    host_path = os.path.join(tmp, "host.jac");
    with open(host_path, "w") as f {
        f.write(
            "na import from .a.kernel { fib }\n"
            "na import from .b.kernel { fib as fib_b }\n"
            "\n"
            "cl {\n"
            "    async def:pub show -> int {\n"
            "        return await fib(4) + await fib_b(5);\n"
            "    }\n"
            "}\n"
        );
    }
    prog = JacProgram();
    prog.compile(host_path);
    msgs = [e.pretty_print() for e in prog.errors_had];
    assert any(["E5083" in m for m in msgs]) , (
        f"two na targets sharing a basename must not both claim"
        f" /static/kernel.wasm; got: {msgs}"
    );
}

test "plain import of a native module from client code takes the na edge" {
    tmp = tempfile.mkdtemp(prefix="jac_na_edge_");
    with open(os.path.join(tmp, "kernel.na.jac"), "w") as f {
        f.write(KERNEL_SRC);
    }
    host_path = os.path.join(tmp, "host.jac");
    with open(host_path, "w") as f {
        f.write(
            "import from .kernel { fib }\n"
            "\n"
            "cl {\n"
            "    async def:pub show -> int {\n"
            "        return await fib(10);\n"
            "    }\n"
            "}\n"
        );
    }
    prog = JacProgram();
    mod = prog.compile(host_path);
    assert not prog.errors_had , (
        f"the cl->na edge is inferred for native targets: "
        f"{[str(e) for e in prog.errors_had]}"
    );
    js = mod.gen.js;
    assert '__na_bind' in js , "plain native import must bind the wasm stub";
    assert '"kernel"' in js , "expected the module stem in the bind call";
    targets = list(mod.gen.client_manifest.na_modules);
    assert len(targets) == 1 and targets[0].endswith("kernel.na.jac") , (
        f"plain native import must drive wasm emission; got: {targets}"
    );
    assert "kernel" not in mod.gen.py , (
        "the inferred na edge must be inert under CPython, exactly like the"
        " marked form"
    );
}
