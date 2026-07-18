"""Guards the hand-copied twins that keep the sealed bootstrap importable.

jaclang/jac0core/sealed.py must import before any .jac module can load, so it
re-declares the JIR container constants and re-implements the section reader
and co_filename patcher as pure Python (see its module docstring). These tests
pin each twin to its jir.jac / compiler.jac original so drift fails in CI
instead of at a sealed boot. The seal build enforces the constant half of this
at build time too (precompile_bytecode.jac seal_finalize).
"""

import marshal;
import zlib;

import from jaclang.jac0core { sealed }
import from jaclang.jac0core.compiler { patch_co_filenames_bytes }
import from jaclang.jac0core.jir {
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

test "sealed.py container constants match jir.jac" {
    assert sealed.JIR_FORMAT_VERSION == FORMAT_VERSION;
    assert sealed._HEADER_SIZE == HEADER_SIZE;
    assert sealed._SECTIONS_MAGIC == SECTIONS_MAGIC;
    assert sealed._SEC_BYTECODE == SEC_BYTECODE;
    assert sealed._SEC_DEBUG_SRC == SEC_DEBUG_SRC;
    assert sealed._SEC_TERMINATOR == SEC_TERMINATOR;
    assert sealed.PRECOMPILE_SENTINEL == PRECOMPILE_SENTINEL;
}

test "pure-python section reader agrees with jir.jac on a real JIR" {
    code = compile("X = 41 + 1", "<twin>", "exec");
    raw = marshal.dumps(code);
    src = zlib.compress(b"with entry { X = 42; }");
    data = write_precompiled_jir(
        raw, "twin-key", FLAG_PRECOMPILED, {SEC_DEBUG_SRC: src}
    );
    assert sealed._read_section(data, SEC_BYTECODE) == raw;
    assert sealed._read_section(data, SEC_DEBUG_SRC) == src;
    assert sealed._read_section(data, 0x7E) is None;
    assert read_debug_source(data) == "with entry { X = 42; }";
    assert sealed._read_section(data[:40], SEC_BYTECODE) is None;
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

test "co_filename patcher twins are exact inverses" {
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
    back = sealed._patch_code_filenames(
        sentinel_code, PRECOMPILE_SENTINEL, "/repo/pkg"
    );
    assert _same_code(back, code);
}

test "register_image hash-verifies its JIRs (fail-closed)" {
    import hashlib;
    import json;
    import shutil;
    import tempfile;
    import pytest;
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
        sealed._images.remove(img);

        (jdir / "mod.jir").write_bytes(data + b"tampered");
        with pytest.raises(RuntimeError) {
            sealed.register_image(pre);
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
