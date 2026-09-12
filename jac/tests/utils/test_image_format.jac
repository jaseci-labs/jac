# The boot-safe image codec is shared by compiler-side JIR operations and
# sealed image loading. Exercise real containers and relocated code objects.

import marshal;
import zlib;

import from jaclang.compiler.driver { image as sealed }
import from jaclang.compiler.driver.jir { patch_co_filenames_bytes }
import from jaclang.compiler.driver.jir {
    FORMAT_VERSION,
    HEADER_SIZE,
    SECTIONS_MAGIC,
    SEC_BYTECODE,
    SEC_DEBUG_SRC,
    SEC_TERMINATOR,
    PRECOMPILE_SENTINEL,
    FLAG_PRECOMPILED,
    read_debug_source,
    write_precompiled_jir
}

test "compiler exports the shared image wire contract" {
    assert sealed.JIR_FORMAT_VERSION == FORMAT_VERSION;
    assert sealed.HEADER_SIZE == HEADER_SIZE;
    assert sealed.SECTIONS_MAGIC == SECTIONS_MAGIC;
    assert sealed.SEC_BYTECODE == SEC_BYTECODE;
    assert sealed.SEC_DEBUG_SRC == SEC_DEBUG_SRC;
    assert sealed.SEC_TERMINATOR == SEC_TERMINATOR;
    assert sealed.PRECOMPILE_SENTINEL == PRECOMPILE_SENTINEL;
}

test "shared section reader opens a real compiler JIR" {
    code = compile("X = 41 + 1", "<twin>", "exec");
    raw = marshal.dumps(code);
    src = zlib.compress(b"with entry { X = 42; }");
    data = write_precompiled_jir(
        raw, "twin-key", FLAG_PRECOMPILED, {SEC_DEBUG_SRC: src}
    );
    assert sealed.read_section_bytes(data, SEC_BYTECODE) == raw;
    assert sealed.read_section_bytes(data, SEC_DEBUG_SRC) == src;
    assert sealed.read_section_bytes(data, 0x7E) is None;
    assert read_debug_source(data) == "with entry { X = 42; }";
    assert sealed.read_section_bytes(data[:40], SEC_BYTECODE) is None;
}

"""Recursive code-object equality on the fields the patchers touch or must
preserve (marshal bytes are not comparable: two content-equal trees can encode
string sharing differently)."""
def _same_code(x: any, y: any) -> bool {
    import types;
    if x.co_filename != y.co_filename
        or x.co_code != y.co_code
        or x.co_name != y.co_name {
        return False;
    }
    xs = [
        c
        for c in x.co_consts
        if isinstance(c, types.CodeType)
    ];
    ys = [
        c
        for c in y.co_consts
        if isinstance(c, types.CodeType)
    ];
    return len(xs) == len(ys) and all(_same_code(a, b) for (a, b) in zip(xs, ys));
}

test "code filenames rebase recursively and round trip" {
    import types;
    py_src = "def f():\n    def g():\n        return 1\n    return g\n";
    code = compile(py_src, "/repo/pkg/mod.jac", "exec");
    outbound = patch_co_filenames_bytes(
        marshal.dumps(code), "/repo/pkg", PRECOMPILE_SENTINEL
    );
    sentinel_code = marshal.loads(outbound);
    assert isinstance(sentinel_code, types.CodeType);
    assert sentinel_code.co_filename == f"{PRECOMPILE_SENTINEL}/mod.jac";
    nested = [
        c
        for c in sentinel_code.co_consts
        if isinstance(c, types.CodeType)
    ];
    assert nested
        and all(c.co_filename == f"{PRECOMPILE_SENTINEL}/mod.jac" for c in nested);
    back = sealed.patch_code_filenames(sentinel_code, PRECOMPILE_SENTINEL, "/repo/pkg");
    assert _same_code(back, code);
}

test "register_image hash-verifies its JIRs (fail-closed)" {
    import hashlib;
    import json;
    import shutil;
    import tempfile;
    import from pathlib { Path }

    tmp = Path(tempfile.mkdtemp(prefix="sealed-twin-"));
    try {
        pre = tmp / "_precompiled";
        jdir = pre / sealed.python_tag();
        jdir.mkdir(parents=True);
        data = write_precompiled_jir(
            marshal.dumps(compile("Y = 1", "<t>", "exec")), "k", FLAG_PRECOMPILED
        );
        (jdir / "mod.jir").write_bytes(data);
        (pre / sealed.MANIFEST_NAME).write_text(
            json.dumps(
                {
                    "format": sealed.MANIFEST_FORMAT,
                    "package": "sealed_twin_test_pkg",
                    "python_tag": sealed.python_tag(),
                    "jir_format_version": sealed.JIR_FORMAT_VERSION,
                    "modules": {
                        "mod.jac": {
                            "module": "sealed_twin_test_pkg.mod",
                            "jir": "mod.jir",
                            "package": False,
                            "sha256": hashlib.sha256(data).hexdigest()
                        }
                    }
                }
            )
        );
        img = sealed.register_image(pre);
        assert img is not None;
        code = img.code("sealed_twin_test_pkg.mod");
        assert code is not None;
        namespace: dict = {};
        exec(code, namespace);
        assert namespace["Y"] == 1;
        sealed._images.remove(img);

        (jdir / "mod.jir").write_bytes(data + b"tampered");
        with testraises(RuntimeError) {
            sealed.register_image(pre);
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "compiler images execute without invoking the compiler or seed transpiler" {
    import hashlib;
    import importlib.util;
    import tempfile;
    import types;
    import from pathlib { Path }
    import from unittest.mock { patch }
    import from jaclang.meta_importer { JacMetaImporter }
    import from jaclang.runtime.runtime { JacRuntime }

    with tempfile.TemporaryDirectory() as work {
        pre = Path(work) / "_precompiled";
        jdir = pre / sealed.python_tag();
        jdir.mkdir(parents=True);
        fullname = "jaclang._compiled_image_probe";
        data = write_precompiled_jir(
            marshal.dumps(compile("answer = 42", "__PKG_ROOT__/probe.jac", "exec")),
            "image-probe",
            FLAG_PRECOMPILED
        );
        (jdir / "probe.jir").write_bytes(data);
        img = sealed.SealedImage(
            pre,
            {
                "package": "jaclang",
                "python_tag": sealed.python_tag(),
                "modules": {
                    "probe.jac": {
                        "module": fullname,
                        "jir": "probe.jir",
                        "package": False,
                        "sha256": hashlib.sha256(data).hexdigest()
                    }
                }
            }
        );
        img.verify();
        sealed._images.insert(0, img);
        try {
            loader = JacMetaImporter();
            module = types.ModuleType(fullname);
            module.__spec__ = importlib.util.spec_from_loader(
                fullname, loader, origin=img.virtual_origin("probe.jac")
            );
            with patch.object(
                JacRuntime,
                "get_compiler",
                side_effect=AssertionError("compiler invoked")
            ), patch.object(
                loader, "_exec_seed_source", side_effect=AssertionError("seed invoked")
            ) {
                loader.exec_module(module);
                assert module.answer == 42;
                assert loader.get_code(fullname) is not None;
            }
        } finally {
            sealed._images.remove(img);
        }
    }
}


test "image relocation preserves annex traceback filenames" {
    import from pathlib { Path }
    import from jaclang.runtime.function_metadata { impl_patch_filename }
    image = sealed.SealedImage(
        Path("/installed/jaclang/_precompiled"),
        {"package": "jaclang", "source_root": "/build/site/jaclang"}
    );
    sealed._images.insert(0, image);
    try {
        def probe -> int {
            return 42;
        }
        patched = impl_patch_filename(
            "/build/site/jaclang/runtime/impl/probe.impl.jac"
        )(
            probe
        );
        assert patched.__code__.co_filename
            == "/installed/jaclang/runtime/impl/probe.impl.jac";
        assert patched() == 42;
        assert sealed.rebase_source_filename("/build/site/jaclang-other/file.jac")
            == "/build/site/jaclang-other/file.jac";
    } finally {
        sealed._images.remove(image);
    }
}
