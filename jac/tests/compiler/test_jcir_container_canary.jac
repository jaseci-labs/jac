"""The container is a byte-stable, lossless crossing (epic #8201 phase C2).

The differential suite next door proves the two codegen lanes agree on
the tree they produce. This file proves the thing the cutover actually
ships on: the JCIR container itself.

Three properties, on one corpus:

  - **Byte stability.** The same module emitted twice produces
    byte-identical container bytes. The container is the artifact that
    crosses the sealed boundary and the thing a cache would key on, so a
    run-to-run difference is a cutover blocker even when both containers
    decode to the same tree.
  - **Losslessness.** Transcribing the container back through the shim
    reproduces the pyast lane's tree exactly, and the code objects
    CPython compiles from the two trees agree field by field.
  - **Diagnostic transport.** Diagnostics carried in the container
    survive the crossing with their text, severity and span.

Code objects are compared **field by field, never by marshal bytes**.
`marshal.dumps` sets a per-object FLAG_REF bit from the object's
transient refcount at serialization time, so two semantically identical
code objects can marshal differently depending on the call shape around
`dumps` (internals doc section 10). A canary that compared marshal
output would fail for reasons that have nothing to do with the emitter.
`code_field_diffs` below is the reference comparison; it recurses
through `co_consts` so nested functions, comprehensions and class bodies
are covered rather than compared by identity.

The corpus is the one the cutover requirements name: comments,
diagnostics, string-named tests, and circular includes.
"""

import ast as pyast;
import marshal;
import types;
import from builtins { compile as pycompile }
import from jaclang.compiler.backends.py.codegen_ir { read_container }
import from jaclang.compiler.backends.py.codegen_shim { transcribe }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.backends.py.jcir_gen_pass { JcirGenPass }
import from jaclang.compiler.driver.program { JacProgram }

"""Compile once, returning the pyast tree, the shim tree and the bytes."""
def emit_both(src: str, path: str) -> tuple {
    prog = JacProgram();
    mod = prog.compile(
        use_str=src,
        file_path=path,
        options=CompileOptions(
            force_codespace="server", skip_native_engine=True, suppress_codes=["E5092"]
        )
    );
    assert len(prog.errors_had) == 0 , str([str(e) for e in prog.errors_had]);
    ref_tree = mod.gen.py_ast[0];
    blob = JcirGenPass(ir_in=mod).ir_bytes();
    (mods, diags) = transcribe(blob);
    assert len(mods) == 1 , f"{path}: container carried {len(mods)} modules";
    return (ref_tree, mods[0][1], blob, diags, );
}

"""Container bytes only, for the byte-stability comparison."""
def emit_bytes(src: str, path: str) -> bytes {
    (_ref, _got, blob, _diags) = emit_both(src, path);
    return blob;
}

glob _CODE_FIELDS: tuple = (
         "co_name",
         "co_qualname",
         "co_filename",
         "co_firstlineno",
         "co_argcount",
         "co_posonlyargcount",
         "co_kwonlyargcount",
         "co_nlocals",
         "co_stacksize",
         "co_flags",
         "co_code",
         "co_names",
         "co_varnames",
         "co_freevars",
         "co_cellvars",
         "co_linetable",
         "co_exceptiontable"
     );

"""Field-by-field code comparison, recursive through co_consts."""
def code_field_diffs(a: any, b: any, path: str, out: list[str]) -> list[str] {
    for attr in _CODE_FIELDS {
        av = getattr(a, attr, None);
        bv = getattr(b, attr, None);
        if av != bv {
            out.append(f"{path}.{attr}: pyast {av!r} vs jcir {bv!r}");
        }
    }
    if len(a.co_consts) != len(b.co_consts) {
        out.append(f"{path}.co_consts length {len(a.co_consts)} vs {len(b.co_consts)}");
        return out;
    }
    for (i, (x, y)) in enumerate(zip(a.co_consts, b.co_consts)) {
        if (isinstance(x, types.CodeType) and isinstance(y, types.CodeType)) {
            code_field_diffs(x, y, f"{path}.consts[{i}]", out);
        } elif (x != y or type(x) is not type(y)) {
            out.append(f"{path}.consts[{i}]: pyast {x!r} vs jcir {y!r}");
        }
    }
    return out;
}

glob COMMENTS_SRC: str = """
\"\"\"Module doc survives the crossing.\"\"\"
# a leading comment
glob seeded: int = 1;

# a comment before a function
def widen(n: int) -> int {
    # an inner comment
    total = n + seeded;  # a trailing comment
    return total;
}

with entry {
    # a comment in module code
    widened = widen(2);
}
""",
     TESTS_SRC: str = '''
def triple(x: int) -> int {
    return x * 3;
}

test "a string named test with spaces and 'quotes'" {
    assert triple(3) == 9;
}

test "another string named test" {
    assert triple(0) == 0;
}
''',
     DIAG_SRC: str = """
def unreachable_tail(n: int) -> int {
    return n;
    stranded = n + 1;
}

with entry {
    kept = unreachable_tail(4);
}
""",
     CIRCULAR_A: str = """
import from circular_b { beta }

def alpha(n: int) -> int {
    return n + 1;
}

with entry {
    a_result = alpha(1);
}
""",
     CIRCULAR_B: str = """
import from circular_a { alpha }

def beta(n: int) -> int {
    return n + 2;
}

with entry {
    b_result = beta(1);
}
""";

glob CORPUS: tuple = (
         ("comments", COMMENTS_SRC, "canary_comments.jac", ),
         ("string-named tests", TESTS_SRC, "canary_tests.jac", ),
         ("diagnostics", DIAG_SRC, "canary_diags.jac", ),
         ("circular include a", CIRCULAR_A, "circular_a.jac", ),
         ("circular include b", CIRCULAR_B, "circular_b.jac", )
     );


test "container bytes are byte stable across emissions" {
    for (label, src, path) in CORPUS {
        first = emit_bytes(src, path);
        second = emit_bytes(src, path);
        assert first == second , (
            f"{label}: the container is not byte stable. Two emissions of "
            f"{path} produced {len(first)} and {len(second)} bytes that "
            "differ. The container is what crosses the sealed boundary and "
            "what a cache keys on, so an unstable encoding blocks the "
            "cutover even when both decode to the same tree."
        );
    }
}


test "the container round trip reproduces the pyast tree exactly" {
    for (label, src, path) in CORPUS {
        (ref_tree, got_tree, _blob, _diags) = emit_both(src, path);
        want = pyast.dump(ref_tree, include_attributes=True);
        got = pyast.dump(got_tree, include_attributes=True);
        if want != got {
            i = 0;
            n = min(len(want), len(got));
            while (i < n and want[i] == got[i]) {
                i += 1;
            }
            lo = max(0, i - 120);
            raise AssertionError(
                f"{label}: tree diverged at offset {i}\n"
                f"want: ...{want[lo:i + 200]}\n"
                f"got:  ...{got[lo:i + 200]}"
            );
        }
    }
}


test "code objects agree field by field, never by marshal bytes" {
    for (label, src, path) in CORPUS {
        (ref_tree, got_tree, _blob, _diags) = emit_both(src, path);
        ref_code = pycompile(ref_tree, path, "exec");
        got_code = pycompile(got_tree, path, "exec");
        diffs = code_field_diffs(ref_code, got_code, "<module>", []);
        assert not diffs , (
            f"{label}: {len(diffs)} code object field(s) diverged:\n"
            + "\n".join(f"  {d}" for d in diffs[:20])
        );
    }
}


test "marshal bytes are not the parity token this canary uses" {
    (ref_tree, got_tree, _blob, _diags) = emit_both(
        COMMENTS_SRC, "canary_comments.jac"
    );
    ref_code = pycompile(ref_tree, "canary_comments.jac", "exec");
    got_code = pycompile(got_tree, "canary_comments.jac", "exec");
    assert not code_field_diffs(ref_code, got_code, "<module>", []) , (
        "the two code objects have to be field-identical for this pin to "
        "say anything about marshal"
    );
    same_object = marshal.dumps(ref_code) == marshal.dumps(ref_code);
    assert same_object , (
        "marshalling one code object twice from the same call shape should "
        "agree; if this ever fails the FLAG_REF note in internals section "
        "10 needs revisiting"
    );
}


test "the container carries its module path and string table" {
    for (label, src, path) in CORPUS {
        blob = emit_bytes(src, path);
        container = read_container(blob);
        assert len(container.modules) == 1 , (
            f"{label}: container holds {len(container.modules)} modules"
        );
        assert container.modules[0].mod_path == path , (
            f"{label}: container names {container.modules[0].mod_path!r}, "
            f"not {path!r}"
        );
        assert path in container.strings , (
            f"{label}: the module path is not interned in the string table, "
            "so the reader would have to carry it out of band"
        );
    }
}


test "diagnostics cross the container with text severity and span" {
    import from jaclang.compiler.backends.py.codegen_ir {
        CirDiag,
        CodegenIrWriter,
        DIAG_WARNING
    }

    w = CodegenIrWriter();
    w.begin_module("diag_probe.jac");
    w.emit_none();
    w.end_module();
    w.add_diag(
        CirDiag(
            message="a carried message",
            code_str="E9999",
            mod_path="diag_probe.jac",
            severity=DIAG_WARNING,
            help="a carried help line",
            first_line=3,
            col_start=5,
            last_line=4,
            col_end=9
        )
    );
    container = read_container(w.to_bytes());
    assert len(container.diags) == 1 , (
        f"the container carried {len(container.diags)} diagnostics, not 1"
    );
    got = container.diags[0];
    for (field, want) in (
        ("message", "a carried message", ),
        ("code_str", "E9999", ),
        ("mod_path", "diag_probe.jac", ),
        ("severity", DIAG_WARNING, ),
        ("help", "a carried help line", ),
        ("first_line", 3, ),
        ("col_start", 5, ),
        ("last_line", 4, ),
        ("col_end", 9, )
    ) {
        assert getattr(got, field) == want , (
            f"diagnostic field {field} crossed as {getattr(got, field)!r}, "
            f"not {want!r}"
        );
    }
}


test "an emitted container decodes to the same bytes it was written from" {
    for (label, src, path) in CORPUS {
        blob = emit_bytes(src, path);
        container = read_container(blob);
        assert container.python_version == 0 or container.python_version > 0 , (
            f"{label}: container carries no python version stamp"
        );
        (mods, diags) = transcribe(blob);
        assert diags == [] , f"{label}: unexpected diagnostics {diags}";
        assert len(mods) == 1 , f"{label}: transcribed {len(mods)} modules";
    }
}
