"""Tests for by-design dynamic object-model diagnostics on the native pathway (issue #7685).

Native archetypes have a static layout: fields are fixed struct slots declared
with `has`, methods are direct (or vtable) calls, and there is no per-instance
dict. Dynamic Python object-model idioms (monkey patching, computed attribute
names, `__dict__`, class-object mutation, `type()` fabrication) are rejected
*by design*, and must be rejected with the dedicated E5093 diagnostic -- never
a silent no-op (the pre-#7685 behavior for statement-position `setattr` and
`del p.x`), and never the generic E5092 lowering-failure code.

Literal-name reflection on a *declared* field is not dynamic: `getattr(p, "x")`
/ `setattr(p, "x", v)` / `hasattr(p, "x")` lower to the equivalent field
load/store/const (see the cross-backend fixture `reflection_parity.jac` for the
exec-based value proof; compile-level acceptance lives here).
"""

import os;
import tempfile;
import from jaclang.jac0core.program { JacProgram }

glob ARCH_PRELUDE: str = (
         "obj P {\n"
         "    has x: int = 0;\n"
         "}\n"
         "\n"
     );

"""Write a module source into a fresh temp dir; return its path."""
def write_module(name: str, source: str) -> str {
    tmpdir = tempfile.mkdtemp();
    src_path = os.path.join(tmpdir, name);
    with open(src_path, "w") as fh {
        fh.write(source);
    }
    return src_path;
}

"""Return all alerts carrying the given diagnostic code."""
def alerts_with_code(prog: JacProgram, code: str) -> list {
    return [
        alrt
        for alrt in prog.errors_had
        if alrt.code is not None and alrt.code.code == code
    ];
}

"""Message + help text of the given alerts, joined for content assertions."""
def alert_blob(alerts: list) -> str {
    return " ".join([f"{a} {a.help_text or ''}" for a in alerts]);
}

"""Format errors for assertion messages."""
def fmt_errors(prog: JacProgram) -> str {
    return str([str(e) for e in prog.errors_had]);
}

"""Compile source as a .na.jac module; assert exactly-by-design rejection.

The construct must produce E5093 (not E5092, not silence), and the module
must publish no native artifact -- an unpublishable module cannot silently
no-op at runtime, which is the exec-level guarantee for every error row.
"""
def assert_by_design_reject(source: str, label: str) -> list {
    src = write_module(f"objmodel_{label}.na.jac", source);
    prog = JacProgram();
    mod = prog.compile(file_path=src);
    hits = alerts_with_code(prog, "E5093");
    assert hits , (
        f"[{label}] expected E5093 (by-design rejection), got: {fmt_errors(prog)}"
    );
    assert not alerts_with_code(prog, "E5092") , (
        f"[{label}] intentional rejection must not surface as generic E5092: "
        f"{fmt_errors(prog)}"
    );
    assert mod.gen.llvm_ir is None , (
        f"[{label}] a rejected module must not publish llvm ir"
    );
    assert mod.gen.native_engine is None , (
        f"[{label}] a rejected module must not publish a jit engine"
    );
    return hits;
}

# ---------------------------------------------------------------------------
# Phase 0: the silent no-op holes (rows 5-7 of #7685)
# ---------------------------------------------------------------------------

test "setattr with undeclared literal name is rejected, not a silent no-op" {
    assert_by_design_reject(
        ARCH_PRELUDE + (
            "with entry {\n"
            "    p = P();\n"
            "    setattr(p, \"nope\", 5);\n"
            "    print(p.x);\n"
            "}\n"
        ),
        "setattr_undeclared"
    );
}

test "del of an archetype attribute is rejected, not a silent no-op" {
    hits = assert_by_design_reject(
        ARCH_PRELUDE + (
            "with entry {\n"
            "    p = P();\n"
            "    del p.x;\n"
            "    print(p.x);\n"
            "}\n"
        ),
        "del_attr"
    );
    help_blob = alert_blob(hits);
    assert "None" in help_blob , (
        f"del-attr help should point at optional fields (`x: int | None`) or a "
        f"sentinel as the native alternative, got: {help_blob}"
    );
}

test "statement-position and value-position rejection are consistent" {
    stmt_src = ARCH_PRELUDE + (
        "with entry {\n"
        "    p = P();\n"
        "    getattr(p, \"nope\");\n"
        "}\n"
    );
    val_src = ARCH_PRELUDE + (
        "with entry {\n"
        "    p = P();\n"
        "    v = getattr(p, \"nope\");\n"
        "    print(v);\n"
        "}\n"
    );
    assert_by_design_reject(stmt_src, "getattr_stmt");
    assert_by_design_reject(val_src, "getattr_val");
}

# ---------------------------------------------------------------------------
# Phase 1: dedicated E5093 for every dynamic object-model construct
# ---------------------------------------------------------------------------

test "reflection builtins with dynamic attribute names are rejected by design" {
    for (label, line) in [
        ("setattr_dyn", "setattr(p, n, 5);"),
        ("getattr_dyn", "v = getattr(p, n); print(v);"),
        ("hasattr_dyn", "b = hasattr(p, n); print(b);")
    ] {
        assert_by_design_reject(
            ARCH_PRELUDE + (
                "with entry {\n"
                "    p = P();\n"
                "    n = \"x\";\n"
                f"    {line}\n"
                "}\n"
            ),
            label
        );
    }
}

test "delattr is rejected by design even with a declared literal name" {
    assert_by_design_reject(
        ARCH_PRELUDE + (
            "with entry {\n"
            "    p = P();\n"
            "    delattr(p, \"x\");\n"
            "}\n"
        ),
        "delattr_lit"
    );
}

test "__dict__ and vars() are rejected by design" {
    assert_by_design_reject(
        ARCH_PRELUDE + (
            "with entry {\n"
            "    p = P();\n"
            "    d = p.__dict__;\n"
            "    print(d);\n"
            "}\n"
        ),
        "dunder_dict"
    );
    assert_by_design_reject(
        ARCH_PRELUDE + (
            "with entry {\n"
            "    p = P();\n"
            "    v = vars(p);\n"
            "    print(v);\n"
            "}\n"
        ),
        "vars_call"
    );
}

test "three-arg type() class fabrication is rejected by design" {
    assert_by_design_reject(
        ARCH_PRELUDE + (
            "with entry {\n"
            "    q = type(\"Q\", (), {});\n"
            "    print(q);\n"
            "}\n"
        ),
        "type_fabrication"
    );
}

test "globals() and locals() are rejected by design" {
    assert_by_design_reject(
        ARCH_PRELUDE + (
            "with entry {\n"
            "    g = globals();\n"
            "    print(g);\n"
            "}\n"
        ),
        "globals_call"
    );
    assert_by_design_reject(
        ARCH_PRELUDE + (
            "with entry {\n"
            "    l = locals();\n"
            "    print(l);\n"
            "}\n"
        ),
        "locals_call"
    );
}

test "__class__ assignment is rejected and anchored on the attribute, not the RHS" {
    hits = assert_by_design_reject(
        ARCH_PRELUDE + (
            "obj R {\n"
            "    has x: int = 0;\n"
            "}\n"
            "\n"
            "with entry {\n"
            "    p = P();\n"
            "    p.__class__ = R;\n"
            "}\n"
        ),
        "class_reassign"
    );
    blob = alert_blob(hits);
    assert "__class__" in blob , (
        f"the diagnostic must name the __class__ construct (anchored on the "
        f"assignment target, not the RHS name), got: {blob}"
    );
}

test "method monkey-patching on a class object is rejected by design" {
    hits = assert_by_design_reject(
        ARCH_PRELUDE + (
            "def g(p: P) -> int {\n"
            "    return p.x + 1;\n"
            "}\n"
            "\n"
            "with entry {\n"
            "    P.m = g;\n"
            "}\n"
        ),
        "monkey_patch"
    );
    blob = alert_blob(hits);
    assert "m" in blob , f"the diagnostic must name the patched attribute, got: {blob}";
}

test "undeclared field store through an any-typed receiver gets the sealed-layout help" {
    hits = assert_by_design_reject(
        ARCH_PRELUDE + (
            "with entry {\n"
            "    p: any = P();\n"
            "    p.y = 5;\n"
            "}\n"
        ),
        "any_receiver_store"
    );
    blob = alert_blob(hits);
    assert "has" in blob , (
        f"the help must point at declaring the field with `has`, got: {blob}"
    );
}

# ---------------------------------------------------------------------------
# Phase 3: the checker's earliest diagnostic teaches the design constraint
# ---------------------------------------------------------------------------

test "E1030 on a typed receiver in native code carries the sealed-layout help" {
    src = write_module(
        "objmodel_e1030.na.jac",
        ARCH_PRELUDE + (
            "with entry {\n"
            "    p = P();\n"
            "    p.y = 5;\n"
            "}\n"
        )
    );
    prog = JacProgram();
    prog.compile(file_path=src, type_check=True);
    hits = alerts_with_code(prog, "E1030");
    assert hits , f"expected checker E1030, got: {fmt_errors(prog)}";
    blob = alert_blob(hits);
    assert "has" in blob and "native" in blob.lower() , (
        f"native-context E1030 must teach the sealed-layout design (declare "
        f"with `has`), got: {blob}"
    );
}

# ---------------------------------------------------------------------------
# Diagnostic contract: E5093 is "never, on purpose" -- not "not yet"
# ---------------------------------------------------------------------------

test "E5093 wording is by-design and never says yet" {
    src = write_module(
        "objmodel_wording.na.jac",
        ARCH_PRELUDE + (
            "with entry {\n"
            "    p = P();\n"
            "    setattr(p, \"nope\", 5);\n"
            "}\n"
        )
    );
    prog = JacProgram();
    prog.compile(file_path=src);
    hits = alerts_with_code(prog, "E5093");
    assert hits , f"expected E5093, got: {fmt_errors(prog)}";
    for alrt in hits {
        rendered = alrt.pretty_print()
            if hasattr(alrt, "pretty_print")
            else str(alrt);
        assert "yet" not in rendered , (
            f"E5093 is a permanent design boundary; its text must never say "
            f"'yet': {rendered}"
        );
        assert "design" in rendered , (
            f"E5093 must state the rejection is by design: {rendered}"
        );
    }
}

# ---------------------------------------------------------------------------
# Phase 2: literal-name reflection on declared fields is NOT dynamic -- it
# compiles clean and publishes an artifact (value-level parity is pinned by
# fixtures/reflection_parity.jac in the cross-backend equivalence suite).
# ---------------------------------------------------------------------------

test "literal-name reflection on declared fields compiles clean" {
    src = write_module(
        "objmodel_parity.na.jac",
        ARCH_PRELUDE + (
            "with entry {\n"
            "    p = P();\n"
            "    setattr(p, \"x\", 41);\n"
            "    v = getattr(p, \"x\");\n"
            "    w = getattr(p, \"nope\", 7);\n"
            "    b = hasattr(p, \"x\");\n"
            "    print(v, w, b);\n"
            "}\n"
        )
    );
    prog = JacProgram();
    mod = prog.compile(file_path=src);
    assert not prog.errors_had , (
        f"declared-field literal reflection must lower cleanly: "
        f"{fmt_errors(prog)}"
    );
    assert mod.gen.llvm_ir is not None , (
        "declared-field literal reflection must publish a native artifact"
    );
}
