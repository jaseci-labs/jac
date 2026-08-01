"""The cl -> na edge: a client import that resolves to a native module.

A native-resolving import in client code does three things: binds each name
to a generated `__na_bind` stub (lazy wasm instantiation via @jac/wasm_host),
records a typed cl -> na InteropBinding in the interop manifest so the build
emits /static/<stem>.wasm, and compiles to nothing on the Python side -- a
plain import of a native module from server code is the sv -> na ctypes
crossing and executes the module under CPython, which is exactly what the
client edge exists to avoid (jaclang.org DOGFOOD A2). The client side of the
edge is placement-inferred; these tests pin the host module client via
[placement.pins] the way a migrated project would.
"""

import os;
import tempfile;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }

glob KERNEL_SRC: str = (
         "def:pub fib(n: int) -> int {\n"
         "    if n < 2 {\n"
         "        return n;\n"
         "    }\n"
         "    return fib(n - 1) + fib(n - 2);\n"
         "}\n"
         "\n"
         "# Ownership annotations are the in-source native anchor the\n"
         "# retired .na.jac marker used to provide (anchors decide the\n"
         "# inferred cl->na edge; pub alone reads as a server endpoint).\n"
         "def scratch(buf: own str) -> int {\n"
         "    return len(buf);\n"
         "}\n"
     ),
     HOST_SRC: str = (
         "import from .kernel { fib, fib as fast_fib }\n"
         "\n"
         "async def:pub show -> int {\n"
         "    return await fib(10);\n"
         "}\n"
     ),
     PIN_HOST_CLIENT: str = (
         "[placement.pins]\nhost = \"client\"\nkernel = \"native\"\n"
         "\"*.kernel\" = \"native\"\n"
     );

def compile_host -> uni.Module {
    tmp = tempfile.mkdtemp(prefix="jac_na_edge_");
    kernel_path = os.path.join(tmp, "kernel.jac");
    host_path = os.path.join(tmp, "host.jac");
    with open(kernel_path, "w") as f {
        f.write(KERNEL_SRC);
    }
    with open(host_path, "w") as f {
        f.write(HOST_SRC);
    }
    with open(os.path.join(tmp, "jac.toml"), "w") as f {
        f.write(PIN_HOST_CLIENT);
    }
    prog = JacProgram();
    return prog.compile(host_path);
}

test "native import binds generated wasm stubs in the client js" {
    mod = compile_host();
    js = mod.gen.js;
    assert '__na_bind' in js , "expected the @jac/wasm_host stub factory import";
    assert '"kernel"' in js , "expected the module stem in the bind call";
    assert '"fib"' in js , "expected the export name in the bind call";
    assert "fast_fib" in js , "expected the alias as the local binding";
}

test "native import records typed cl->na bindings in the interop manifest" {
    mod = compile_host();
    manifest = mod.gen.interop_manifest;
    assert manifest is not None;
    bindings = manifest.client_native_imports;
    targets = sorted({str(b.source_module) for b in bindings});
    assert len(targets) == 1;
    assert targets[0].endswith("kernel.jac");
    by_local = {
        local: b
        for (local, b) in manifest.bindings.items()
        if b in bindings
    };
    assert set(by_local.keys()) == {"fib", "fast_fib"} , (
        f"bindings must be keyed by local alias; got: {list(by_local.keys())}"
    );
    alias_binding = by_local["fast_fib"];
    assert alias_binding.name == "fib" , "binding must keep the export name";
    assert alias_binding.ret_type == "int";
    assert alias_binding.param_types == ["int"];
    assert alias_binding.param_names == ["n"];
    client_manifest = mod.gen.client_manifest;
    assert client_manifest is not None;
    assert "kernel" not in dict(client_manifest.imports) , (
        "a native import must not join manifest.imports -- the client build"
        " would try to JS-compile the native module"
    );
}

test "native import compiles to nothing on the python side" {
    mod = compile_host();
    assert "kernel" not in mod.gen.py , (
        "the client->native import must be inert under CPython; only a plain"
        " server import of a native module means the ctypes crossing"
    );
}

test "colliding native import basenames are a build error" {
    tmp = tempfile.mkdtemp(prefix="jac_na_edge_");
    for sub in ("a", "b") {
        os.makedirs(os.path.join(tmp, sub));
        with open(os.path.join(tmp, sub, "kernel.jac"), "w") as f {
            f.write(KERNEL_SRC);
        }
    }
    host_path = os.path.join(tmp, "host.jac");
    with open(host_path, "w") as f {
        f.write(
            "import from .a.kernel { fib }\n"
            "import from .b.kernel { fib as fib_b }\n"
            "\n"
            "async def:pub show -> int {\n"
            "    return await fib(4) + await fib_b(5);\n"
            "}\n"
        );
    }
    with open(os.path.join(tmp, "jac.toml"), "w") as f {
        f.write(PIN_HOST_CLIENT);
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
    with open(os.path.join(tmp, "kernel.jac"), "w") as f {
        f.write(KERNEL_SRC);
    }
    host_path = os.path.join(tmp, "host.jac");
    with open(host_path, "w") as f {
        f.write(
            "import from .kernel { fib }\n"
            "\n"
            "async def:pub show -> int {\n"
            "    return await fib(10);\n"
            "}\n"
        );
    }
    with open(os.path.join(tmp, "jac.toml"), "w") as f {
        f.write(PIN_HOST_CLIENT);
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
    targets = sorted(
        {str(b.source_module) for b in mod.gen.interop_manifest.client_native_imports}
    );
    assert len(targets) == 1 and targets[0].endswith("kernel.jac") , (
        f"plain native import must drive wasm emission; got: {targets}"
    );
    assert "kernel" not in mod.gen.py , (
        "the inferred na edge must be inert under CPython, exactly like the"
        " server-pinned form"
    );
}
