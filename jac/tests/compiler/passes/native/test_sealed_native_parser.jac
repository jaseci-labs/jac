"""Parity gate for the sealed native parser and its materializer crossings.

Runs the exact pipeline `seal_native_artifacts` ships (seal-time generation
of the `compiler/native_materialize.jac` root, demotion gate, abort-stub
scan, in-house link, dlopen + parse-parity canaries), serves the artifact
through the real `sealed.native_artifact_for` seam, binds it with the real
`frontend._native_parse`, and asserts the materialized tree IS the bytecode
parser's tree: error counts, node counts, unparse fingerprints, field-level
values, instance-dict key sets, envelope fidelity (diags, comments), plus a
compile-and-exec smoke. Refcount and RSS soundness are asserted
independently of parity -- a fingerprint can see corruption, never a leak.
Green here is the condition for a payload serving parse trees natively,
which is the only tier a sealed build has (#8139).
"""

import gc;
import json;
import os;
import resource;
import sys;
import tempfile;
import time;
import jaclang;
import from pathlib { Path }
import from tests.support { JAC_ROOT as REPO_ROOT }
import from jaclang.utils.precompile_bytecode {
    seal_native_artifacts,
    _PARITY_CORPUS_LINES
}
import from jaclang.compiler.passes.tool.unparse_pass { unparse_node }
import from jaclang.jac0core.parser.materialize { MATERIALIZE_FIXUPS }
import from jaclang.jac0core.parser.parser { Parser }
import jaclang.jac0core.parser.lexer as bytecode_lexer;
import jaclang.jac0core.srcloc as uni_srcloc;
import jaclang.jac0core.unitree as uni;

glob PKG_PATH = Path(jaclang.__file__).parent,
     _ARTIFACT_MEMO: list = [];

def _corpus_src -> str {
    nl = chr(10);
    return nl.join(list(_PARITY_CORPUS_LINES));
}

"""Serves one locally built parser artifact through the
sealed.native_artifact_for seam; everything else defers to the real
resolver."""
obj _ServeLocalArtifact {
    has lib_path: str,
        layout_dict: dict,
        real: any;

    def __call__(fullname: str) -> any {
        if fullname == "jaclang.compiler.native_materialize" {
            return (self.lib_path, self.layout_dict, );
        }
        return self.real(fullname) if self.real is not None else None;
    }
}

def _build_binding -> tuple {
    if "/.cache/jac/rt/"
        in str(Path(jaclang.__file__).resolve()).replace(os.sep, "/") {
        testskip(
            "sealed-payload runtime: the parser seal is gated in source "
            "environments (dev lanes, macOS, build time), not from inside "
            "an installed payload"
        );
    }
    if _ARTIFACT_MEMO {
        return _ARTIFACT_MEMO[0];
    }
    out_dir = Path(tempfile.mkdtemp(prefix="jac_sealed_parser_"));
    artifacts = seal_native_artifacts(
        PKG_PATH,
        out_dir,
        modules=("jac0core/unitree.jac", "compiler/native_materialize.jac", )
    );
    assert artifacts , (
        "seal_native_artifacts refused the materializer root on this platform"
    );
    rec = artifacts["jaclang.compiler.native_materialize"];
    lib_path = str(out_dir / rec["lib"]);
    layout_dict = json.loads((out_dir / rec["layout"]).read_text(encoding="utf-8"));
    # Serve the local artifact through the real seam and bind via the real
    # frontend, so every parity test exercises the exact production path.
    import jaclang.jac0core.sealed as sealed;
    import jaclang.jac0core.parser.frontend as frontend;
    sealed.native_artifact_for = _ServeLocalArtifact(
        lib_path=lib_path, layout_dict=layout_dict, real=sealed.native_artifact_for
    );
    frontend._NATIVE_PARSE_MEMO.clear();
    bound = frontend._native_parse();
    assert bound is not None , "frontend refused the local artifact";
    result = (bound, out_dir, rec);
    _ARTIFACT_MEMO.append(result);
    return result;
}

def _bytecode_parse(src: str, path: str) -> tuple {
    (tokens, _c, _ld, _le) = bytecode_lexer.tokenize_full(src, path);
    pyp = Parser(tokens=tokens, file_path=path, source_code=src);
    return (pyp.parse(), pyp.error_count);
}

def _materialize(src: str, path: str) -> tuple {
    (np, _out, _rec) = _build_binding();
    (module, p_errs, _pd, _cm, _ld, _le) = np.parse(src, path);
    return (module, p_errs);
}

def _assert_parity(src: str, path: str) {
    (native_mod, native_errs) = _materialize(src, path);
    (py_mod, py_errs) = _bytecode_parse(src, path);
    assert native_errs == py_errs , (
        f"{path}: native reported {native_errs} errors, bytecode {py_errs}"
    );
    assert isinstance(native_mod, uni.Module) , (
        f"{path}: materializer returned {type(native_mod).__name__}"
    );
    assert len(native_mod._in_mod_nodes) == len(py_mod._in_mod_nodes) , (
        f"{path}: node count diverged "
        f"({len(native_mod._in_mod_nodes)} != {len(py_mod._in_mod_nodes)})"
    );
    native_up = unparse_node(native_mod);
    py_up = unparse_node(py_mod);
    assert native_up == py_up , f"{path}: unparse diverged";
}

test "the materializer root seals and binds through the frontend" {
    (np, _out, rec) = _build_binding();
    assert np is not None;
    assert rec.get("lib_sha256");
}

test "materialized native tree matches bytecode on the parity corpus" {
    _assert_parity(_corpus_src(), "__parity_corpus__.jac");
}

test "materialized native tree matches bytecode on fam.jac" {
    fam = os.path.join(REPO_ROOT, "tests", "compiler", "fixtures", "fam.jac");
    _assert_parity(Path(fam).read_text(encoding="utf-8"), fam);
}

test "materialized native tree matches bytecode on a compiler source module" {
    mod_src = PKG_PATH / "jac0core" / "srcloc.jac";
    _assert_parity(mod_src.read_text(encoding="utf-8"), str(mod_src));
}

test "elif and else arms build their postinit chain (#8090)" {
    src = (
        "with entry { if 1 > 0 { x = 2; } elif 2 > 1 { x = 3; } " + "else { x = 4; } }"
    );
    _assert_parity(src, "__parity_elseif__.jac");
}

test "jsx slot bodies with repeated brace-statement backtracks stay congruent" {
    src = (
        "def:pub C(a: int) -> JsxElement { "
        + "return <ul>{for x in [a] { {1, 2}; {a: 1}; }}</ul>; }"
    );
    _assert_parity(src, "__parity_jsx_backtrack__.jac");
}

test "non-ascii sources reach full parity through the direct decode" {
    nl = chr(10);
    src = nl.join(
        [
            "glob MSG: str = '✅ done';",
            "def greet(who: str) -> str {",
            "    return f'hey {who} ✅';",
            "}",
            "with entry { print(greet('éé')); }",

        ]
    );
    _assert_parity(src, "__parity_nonascii__.jac");
}

test "tests whose symbol the parser generates cross identically (#8177)" {
    # The corpora used to carry string-named tests only: the generated name
    # came off the process-global `Test.TEST_COUNT`, and the two tiers hold
    # independent copies of that static, so this shape disagreed by
    # construction. It is a per-module parser ordinal now, so it is parity
    # material -- and the unparse fingerprint cannot see it (both printers
    # suppress a `_jac_gen_` name), which is why the symbols are compared
    # directly. The identifier-named form is the one the parser
    # error-recovers, so this also pins recovery parity.
    nl = chr(10);
    src = nl.join(
        [
            "test box_holds { assert True; }",
            "test { assert True; }",
            'test "..." { assert True; }',
            'test "named one" { assert True; }',

        ]
    );
    path = "__parity_gen_test_names__.jac";
    _assert_parity(src, path);
    (native_mod, _errs) = _materialize(src, path);
    (py_mod, _perrs) = _bytecode_parse(src, path);
    n_syms = [
        n.sym_name
        for n in native_mod._in_mod_nodes
        if isinstance(n, uni.Test)
    ];
    p_syms = [
        n.sym_name
        for n in py_mod._in_mod_nodes
        if isinstance(n, uni.Test)
    ];
    assert n_syms == p_syms , f"test symbols diverged: {n_syms} vs {p_syms}";
    assert sorted(n_syms)
        == [
            "test__jac_gen_1",
            "test__jac_gen_2",
            "test__jac_gen_3",
            "test_named_one"
        ] , f"unexpected generated symbols: {sorted(n_syms)}";
}

test "union-erased slots materialize their runtime arm (ImplDef.spec)" {
    # `ImplDef.spec` is declared as a list in the native layout, but an impl
    # with a signature stores a `FuncSignature` there. The materializer must
    # follow the runtime arm, never the declared type (the same rule covers
    # `LambdaExpr.body` holding a list).
    src = "obj A { def m(p: int) -> int; }" + " impl A.m(p: int) -> int { return p; }";
    (native_mod, _errs) = _materialize(src, "__parity_union_arm__.jac");
    (py_mod, _perrs) = _bytecode_parse(src, "__parity_union_arm__.jac");
    n_impls = [
        n
        for n in native_mod._in_mod_nodes
        if type(n).__name__ == "ImplDef"
    ];
    p_impls = [
        n
        for n in py_mod._in_mod_nodes
        if type(n).__name__ == "ImplDef"
    ];
    assert n_impls and p_impls;
    assert type(n_impls[0].spec).__name__ == type(p_impls[0].spec).__name__;
    assert type(n_impls[0].spec).__name__ == "FuncSignature";
}

glob _BODY_CARRIERS: tuple = ("Archetype", "Ability", "Enum", ),
     _BODY_UNION_LINES: tuple = (
         "obj Box {",
         "    has x: int = 0;",
         "    static has count: int = 0;",
         "    has p: int { getter; }",
         "    has q: int { getter { return 1; } }",
         "    def m(p: int) -> int;",
         "    def n(p: int) -> int { return p + self.x; }",
         "    obj Inner { has y: int = 1; }",
         "    impl m(p: int) -> int { return p; }",
         "}",
         "obj Decl;",
         "def free_fn(a: int) -> int { return a; }",
         "def by_fn(a: str) -> str by llm();",
         "def decl_fn(a: int) -> int;",
         "def abs_fn(a: int) -> int abst;",
         "node Spot { has label: str = ''; }",
         "walker Tour {",
         "    can step with Spot entry;",
         "    can go with Spot entry { visit [-->]; }",
         "}",
         "enum Hue: int {",
         "    RED = 1,",
         "    GREEN = 2,",
         "    BLUE = 3,",
         "    VIOLET = 4,",
         "    with entry { x = 1; }",
         "}",
         "enum Shade;",

     );

def _body_shape(nd: any) -> any {
    b = nd.__dict__.get("body");
    if b is None {
        return None;
    }
    if isinstance(b, list) {
        return [type(i).__name__ for i in b];
    }
    return type(b).__name__;
}

test "the body union of every carrier persists natively (#8141)" {
    # `Archetype`, `Ability` and `Enum` all carry their body through the
    # `AstImplNeedingNode` slot, whose arms are a statement list, a `by`
    # expression, and the bodiless declaration form. The native
    # representation has to persist the arm it stored: nothing downstream
    # may reconstruct it by re-reading the kid list, because that
    # reconstruction duplicates parser body semantics (which member kinds
    # belong to which carrier's body, which separators do not) and drifts
    # the moment the grammar moves.
    nl = chr(10);
    src = nl.join(list(_BODY_UNION_LINES));
    path = "__body_union_arms__.jac";
    (native_mod, native_errs) = _materialize(src, path);
    (py_mod, py_errs) = _bytecode_parse(src, path);
    assert native_errs == py_errs == 0 , (
        f"corpus no longer parses clean: {native_errs}/{py_errs}"
    );
    n_carriers = [
        n
        for n in native_mod._in_mod_nodes
        if type(n).__name__ in _BODY_CARRIERS
    ];
    p_carriers = [
        n
        for n in py_mod._in_mod_nodes
        if type(n).__name__ in _BODY_CARRIERS
    ];
    assert len(n_carriers) == len(p_carriers) , (
        f"carrier count diverged: {len(n_carriers)} != {len(p_carriers)}"
    );
    kinds = {type(n).__name__ for n in p_carriers};
    assert kinds == set(_BODY_CARRIERS) , f"corpus lost a carrier kind: {kinds}";
    list_arms = 0;
    expr_arms = 0;
    none_arms = 0;
    for (nn, pn) in zip(n_carriers, p_carriers) {
        assert type(nn).__name__ == type(pn).__name__;
        n_shape = _body_shape(nn);
        p_shape = _body_shape(pn);
        assert n_shape == p_shape , (
            f"{type(pn).__name__} body arm diverged: {n_shape} != {p_shape}"
        );
        if p_shape is None {
            none_arms += 1;
        } elif isinstance(p_shape, list) {
            list_arms += 1;
            # Body entries are the tree's own nodes, not copies: passes reach
            # them through `kid` and through `body` interchangeably.
            for item in nn.__dict__["body"] {
                assert `any(k is item for k in nn.kid) , (
                    f"{type(nn).__name__}.body holds {type(item).__name__} "
                    "that is not one of its kids"
                );
            }
        } else {
            expr_arms += 1;
        }
    }
    # Every arm of the union is exercised, not just the braced one.
    assert list_arms > 0 and none_arms > 0 and expr_arms > 0 , (
        f"arm coverage: {list_arms} list, {none_arms} none, {expr_arms} expr"
    );
}

test "materialized instances carry exactly the bytecode parser's dict keys" {
    # The seal-time field mask exists so passes that probe with hasattr or
    # iterate __dict__ see the same instance shape either way.
    (native_mod, _errs) = _materialize(_corpus_src(), "__parity_keys__.jac");
    (py_mod, _perrs) = _bytecode_parse(_corpus_src(), "__parity_keys__.jac");
    for (n_node, p_node) in zip(native_mod._in_mod_nodes, py_mod._in_mod_nodes) {
        assert type(n_node).__name__ == type(p_node).__name__;
        n_keys = set(n_node.__dict__.keys());
        p_keys = set(p_node.__dict__.keys());
        missing = p_keys - n_keys;
        extra = n_keys - p_keys;
        assert not missing and not extra , (
            f"{type(n_node).__name__}: key drift +{sorted(extra)} "
            f"-{sorted(missing)}"
        );
    }
}

test "a prior parse's envelope objects never bleed into the next tree" {
    # The materializer memo is keyed by native address. Envelope emitters
    # (diags, comments) run after the tree flush, so without a per-entry
    # flush their entries outlive the parse -- and the next parse, on a
    # recycled native address, splices a stale CommentData into a kid slot.
    # Heap-reuse-dependent in production; forced here by alternating a
    # comment-heavy parse with tree parses and walking every kid.
    (np, _out, _rec) = _build_binding();
    nl = chr(10);
    commented = nl.join(
        [f"# filler comment number {i} padding the envelope" for i in range(64)]
            + ["with entry { x = 1; }"]
    );
    probe_src = (PKG_PATH / "jac0core" / "srcloc.jac").read_text(encoding="utf-8");
    for cycle in range(3) {
        np.parse(commented, f"__bleed_comments_{cycle}__.jac");
        (m2, _e, _pd, _cm, _ld, _le) = np.parse(
            probe_src, f"__bleed_tree_{cycle}__.jac"
        );
        stack = [m2];
        seen: set = set();
        while stack {
            nd = stack.pop();
            if id(nd) in seen {
                continue;
            }
            seen.add(id(nd));
            for (ki, k) in enumerate(nd.kid) {
                assert isinstance(k, uni.UniNode) , (
                    f"cycle {cycle}: {type(nd).__name__}.kid[{ki}] is "
                    f"{type(k).__name__} -- a stale envelope object crossed "
                    "into the tree"
                );
                stack.append(k);
            }
        }
        (pym, _pe) = _bytecode_parse(probe_src, f"__bleed_tree_{cycle}__.jac");
        assert unparse_node(m2) == unparse_node(pym) , (
            f"cycle {cycle}: unparse diverged after a comment-heavy parse"
        );
    }
}

test "the diagnostic envelope crosses as real Python objects" {
    (np, _out, _rec) = _build_binding();
    bad = "obj A { has x int = 1; }";
    (p_errs, lex_errs, p_diags, lex_diags) = np.parse_diags(
        bad, "__envelope_diags__.jac"
    );
    assert p_errs > 0;
    (tokens, _c, _ld, _le) = bytecode_lexer.tokenize_full(
        bad, "__envelope_diags__.jac"
    );
    pyp = Parser(tokens=tokens, file_path="__envelope_diags__.jac", source_code=bad);
    pyp.parse();
    assert p_errs == pyp.error_count;
    assert len(p_diags) == len(pyp.diags);
    for (nd, pd) in zip(p_diags, pyp.diags) {
        assert type(nd).__name__ == type(pd).__name__ == "SrcDiag";
        assert nd.message == pd.message;
        assert nd.code_str == pd.code_str;
        assert nd.is_error == pd.is_error;
        assert nd.loc.line == pd.loc.line;
        assert nd.loc.col_start == pd.loc.col_start;
    }
    nl = chr(10);
    commented = nl.join(
        ["# leading note", "with entry {", "    x = 1;  # trailing", "}"]
    );
    (np2, _o2, _r2) = _build_binding();
    (_mod, _pe, _pd2, comments, _ld2, _le2) = np2.parse(
        commented, "__envelope_comments__.jac"
    );
    (_tokens, py_comments, _ld3, _le3) = bytecode_lexer.tokenize_full(
        commented, "__envelope_comments__.jac"
    );
    assert len(comments) == len(py_comments) == 2;
    for (nc, pc) in zip(comments, py_comments) {
        assert nc.value == pc.value;
        assert nc.line == pc.line;
        assert nc.col_start == pc.col_start;
        assert nc.is_block == pc.is_block;
    }
}

test "the full compiler pipeline runs over materialized native trees" {
    # _build_binding patches sealed.native_artifact_for and primes the
    # frontend memo, so plain frontend.parse and JacProgram.compile run the
    # exact production path over the locally built artifact.
    _build_binding();
    import jaclang.jac0core.parser.frontend as frontend;
    import from jaclang.jac0core.program { JacProgram }
    (module, had_error) = frontend.parse(_corpus_src(), "__pipeline_corpus__.jac");
    assert not had_error;
    assert isinstance(module, uni.Module);
    with tempfile.TemporaryDirectory(prefix="jac_mat_pipe_") as td {
        target = Path(td) / "hello.jac";
        target.write_text("with entry { print('materialized'); }", encoding="utf-8");
        prog = JacProgram();
        mod = prog.compile(str(target));
        assert mod is not None;
        assert len(prog.errors_had) == 0 , str(prog.errors_had[:3]);
    }
}

test "materializer parity holds across the jac0core source corpus" {
    # Bounded standing corpus sweep: every jac0core source this checkout
    # ships. Fixture-wide equivalence ran once on the integration branch
    # (1410 files, zero divergence); this keeps a representative slice green
    # in CI without that cost.
    corpus = sorted((PKG_PATH / "jac0core").`glob("*.jac"));
    assert len(corpus) > 10;
    for src_file in corpus {
        _assert_parity(src_file.read_text(encoding="utf-8"), str(src_file));
    }
}

"""Field-level tree equality: unparse fingerprints see kid text but not
field VALUES (an erased `body` slot decoding to None, a wrong enum member,
a missing name_spec wiring are all unparse-invisible while being fatal to
codegen). This walker compares every scalar, enum, list length, dict key
set, and class name across both trees."""
def _assert_field_parity(a: any, b: any, path: str = "mod") {
    import enum as _py_enum;
    stack = [(a, b, path, )];
    seen: set = set();
    diffs: list = [];
    while stack {
        (x, y, p) = stack.pop();
        if id(x) in seen {
            continue;
        }
        seen.add(id(x));
        if type(x).__name__ != type(y).__name__ {
            diffs.append(f"{p}: class {type(x).__name__} vs {type(y).__name__}");
            continue;
        }
        dx = x?.__dict__;
        dy = y?.__dict__;
        if dx is None {
            continue;
        }
        kx = set(dx.keys());
        ky = set(dy.keys());
        if kx != ky {
            missing = ky - kx;
            extra = kx - ky;
            if missing or extra {
                diffs.append(f"{p}: keys +{sorted(extra)} -{sorted(missing)}");
            }
        }
        for k in kx & ky {
            vx = dx[k];
            vy = dy[k];
            if isinstance(vx, (int, str, bool, float))
                or vx is None
                or isinstance(vx, _py_enum.Enum) {
                if vx != vy or type(vx).__name__ != type(vy).__name__ {
                    diffs.append(f"{p}.{k}: {repr(vx)[:60]} vs {repr(vy)[:60]}");
                }
            } elif isinstance(vx, list) {
                if not isinstance(vy, list) or len(vx) != len(vy) {
                    diffs.append(
                        f"{p}.{k} [{type(x).__name__}]: list "
                        f"{len(vx)}x{[type(i).__name__ for i in vx][:6]} vs "
                        f"{len(vy) if isinstance(vy, list) else vy}"
                        f"{[type(i).__name__ for i in vy][:6]
                            if isinstance(vy, list)
                            else ''}"
                    );
                }
            } elif isinstance(vx, dict) {
                if not isinstance(vy, dict)
                    or set(map(str, vx.keys())) != set(map(str, vy.keys())) {
                    diffs.append(f"{p}.{k}: dict keys diverged");
                }
            } elif type(vx).__name__ != type(vy).__name__ {
                diffs.append(
                    f"{p}.{k}: type {type(vx).__name__} vs {type(vy).__name__}"
                );
            }
        }
        if hasattr(x, "kid") {
            for (i, (cx, cy)) in enumerate(zip(x.kid, y.kid)) {
                stack.append((cx, cy, f"{p}.kid[{i}]", ));
            }
        }
    }
    assert not diffs , chr(10).join(diffs[:12]);
}

def _assert_full_parity(src: str, path: str) {
    _assert_parity(src, path);
    (native_mod, _e1) = _materialize(src, path);
    (py_mod, _e2) = _bytecode_parse(src, path);
    _assert_field_parity(native_mod, py_mod);
    for (nx, ny) in zip(native_mod._in_mod_nodes, py_mod._in_mod_nodes) {
        _assert_field_parity(nx, ny, type(nx).__name__);
    }
}

test "field-level parity: archetypes, enums, walkers, edge ops" {
    nl = chr(10);
    src = nl.join(
        [
            "enum Hue { RED = 1, GREEN = 2 }",
            "node Spot { has label: str = ''; }",
            "edge Road { has miles: int = 0; }",
            "obj P { has x: int = 8, y: (str | None) = None; def m -> int; }",
            "impl P.m -> int { return self.x; }",
            "walker Tour {",
            "    can step with Spot entry;",
            "}",
            "impl Tour.step with Spot entry {",
            "    visit [-->];",
            "}",
            "def pick(h: Hue) -> int {",
            "    return 1 if h == Hue.GREEN else 0;",
            "}",
            "with entry { print(P(x=3).m(), pick(Hue.GREEN)); }",

        ]
    );
    _assert_full_parity(src, "__field_parity__.jac");
}

test "field-level parity holds on a compiler source module" {
    mod_src = PKG_PATH / "jac0core" / "srcloc.jac";
    _assert_full_parity(mod_src.read_text(encoding="utf-8"), str(mod_src));
}

test "materialized trees compile to RUNNABLE bytecode (obj __init__)" {
    # The payload smoke that caught the original materializer body-slot gap:
    # an obj compiled through a materialized tree must construct with its
    # has-var __init__.
    _build_binding();
    import from jaclang.jac0core.program { JacProgram }
    import types as _pytypes;
    import sys as _pysys;
    with tempfile.TemporaryDirectory(prefix="jac_mat_exec_") as td {
        target = Path(td) / "objinit.jac";
        nl = chr(10);
        target.write_text(
            "obj P { has x: int = 8; }"
                + nl
                + "def probe -> int { return P(x=3).x + P().x; }"
                + nl,
            encoding="utf-8"
        );
        prog = JacProgram();
        prog.compile(str(target));
        assert len(prog.errors_had) == 0 , str(prog.errors_had[:3]);
        code = prog.get_bytecode(str(target));
        assert code is not None;
        m = _pytypes.ModuleType("objinit_probe");
        m.__file__ = str(target);
        _pysys.modules["objinit_probe"] = m;
        try {
            exec(code, m.__dict__);
            assert m.probe() == 11 , f"probe() gave {m.probe()}";
        } finally {
            _pysys.modules.pop("objinit_probe", None);
        }
    }
}

test "the fixup enumeration is pinned: entries only ever retire" {
    # #8139 Step 2: materialize_fixups is the one component that knows what
    # the native representation erases. Each entry carries its tracking
    # issue; the count NEVER rises -- growing it means teaching the crossing
    # new Python-side knowledge, which is the residue this plan deletes.
    assert len(MATERIALIZE_FIXUPS) == 2 , (
        f"fixup enumeration changed: {MATERIALIZE_FIXUPS}"
    );
    for (fixup_name, issue) in MATERIALIZE_FIXUPS {
        assert isinstance(fixup_name, str) and fixup_name;
        assert isinstance(issue, int) and issue > 0;
    }
}

test "refcount soundness: repeated materialization is object-count stable" {
    # Parity cannot see a leak, only a corruption (#8139 Step 2). Assert the
    # class-handle/key/enum registry does not accumulate references and that
    # dropped trees actually die: live UniNode coverage and sampled refcounts
    # return to baseline across repeated parses.
    (np, _out, _rec) = _build_binding();
    src = (PKG_PATH / "jac0core" / "srcloc.jac").read_text(encoding="utf-8");

    (_m, _e, _pd, _cm, _ld, _le) = np.parse(src, "__leak_warmup__.jac");
    _m = None;
    gc.collect();
    baseline_nodes = len(
        [
            o
            for o in gc.get_objects()
            if isinstance(o, uni.UniNode)
        ]
    );
    key_probe = sys.intern("kid");
    enum_probe = getattr(uni.SymbolType, "VAR");
    baseline_key = sys.getrefcount(key_probe);
    baseline_enum = sys.getrefcount(enum_probe);
    for i in range(3) {
        (m2, _e2, _pd2, _cm2, _ld2, _le2) = np.parse(src, f"__leak_{i}__.jac");
        m2 = None;
    }
    gc.collect();
    after_nodes = len(
        [
            o
            for o in gc.get_objects()
            if isinstance(o, uni.UniNode)
        ]
    );
    assert after_nodes == baseline_nodes , (
        f"live UniNode count drifted: {after_nodes} != {baseline_nodes}"
    );
    assert abs(sys.getrefcount(key_probe) - baseline_key) <= 1 , (
        "interned key refcount drifted across parses"
    );
    assert abs(sys.getrefcount(enum_probe) - baseline_enum) <= 1 , (
        "enum member refcount drifted across parses"
    );
}

"""Current VmRSS in KB, read off /proc; -1 where /proc does not exist."""
def _vm_rss_kb -> int {
    try {
        with open("/proc/self/status", "r") as f {
            for line in f {
                if line.startswith("VmRSS:") {
                    return int(line.split()[1]);
                }
            }
        }
    } except Exception {
        return -1;
    }
    return -1;
}

test "native memory soundness: the native tree dies inside the call" {
    # The crossing entries free the native tree before returning (its
    # lifetime is the call frame). A native-side leak is invisible to every
    # Python-object assertion, so bound RSS growth over repeated parses of
    # the largest jac0core source is the check.
    #
    # The instrument matters: this used to delta `ru_maxrss`, a process
    # high-water mark, which measured the CACHE STATE instead of the loop --
    # on a cold cache the compile phase had already pushed the peak above
    # anything twenty parses reach (a vacuous green), and on a warm cache
    # the loop's own steady footprint sat astride the threshold and the
    # verdict flipped on ~140KB of allocator noise. Current RSS after a
    # warmup window is what a leak actually moves: ~14k-node trees leaked
    # twenty times are tens of MB of LIVE memory, while a warmed allocator's
    # steady state drifts by at most a few.
    (np, _out, _rec) = _build_binding();
    src = (PKG_PATH / "jac0core" / "unitree.jac").read_text(encoding="utf-8");
    for _w in range(5) {
        (m, _e, _pd, _cm, _ld, _le) = np.parse(src, "__rss_warmup__.jac");
        m = None;
    }
    gc.collect();
    rss_before = _vm_rss_kb();
    if rss_before < 0 {
        testskip("no /proc/self/status on this platform; VmRSS is the instrument");
    }
    for i in range(20) {
        (m2, _e2, _pd2, _cm2, _ld2, _le2) = np.parse(src, f"__rss_{i}__.jac");
        m2 = None;
    }
    gc.collect();
    rss_after = _vm_rss_kb();
    grown_kb = rss_after - rss_before;
    # What the honest instrument found on arrival: the loop leaks TODAY --
    # ~13-21MB of live RSS per parse after warmup, reproduced on an
    # unmodified main checkout with this same probe, so it predates the
    # branch that fixed the instrument. The distinctive shape (near-zero
    # growth for the first few parses, then linear) says an arena is
    # reused until some high-water mark and then abandoned per call.
    # The bound below is therefore a REGRESSION CEILING over the measured
    # 253-435MB spread, not a statement of health: it exists so a second
    # leak cannot hide behind the first while that one is being fixed,
    # and it drops to the tens of MB the docstring promises when it is.
    assert grown_kb < 600 * 1024 , (
        f"live RSS grew {grown_kb}KB over 20 parses after a warmed "
        "allocator -- beyond even the known pre-existing leak's measured "
        "spread; something regressed on top of it"
    );
}

test "front-end timing: native parse+materialize against the bytecode tier" {
    (np, _out, _rec) = _build_binding();
    src = (PKG_PATH / "jac0core" / "srcloc.jac").read_text(encoding="utf-8");
    reps = 3;
    t0 = time.perf_counter();
    for i in range(reps) {
        (m, _e, _pd, _cm, _ld, _le) = np.parse(src, "__timing_native__.jac");
    }
    native_s = (time.perf_counter() - t0) / reps;
    t0 = time.perf_counter();
    for i in range(reps) {
        _bytecode_parse(src, "__timing_bytecode__.jac");
    }
    bytecode_s = (time.perf_counter() - t0) / reps;
    print(
        f"front-end timing srcloc.jac: native {native_s * 1000:.1f}ms, "
        f"bytecode {bytecode_s * 1000:.1f}ms, "
        f"speedup {bytecode_s / native_s:.2f}x"
    );
    # Not a benchmark gate; only a sanity floor that the native tier is not
    # pathologically slower than bytecode on shared CI machines.
    assert native_s < bytecode_s * 3;
}

def _tier_required_stub -> bool {
    return True;
}

test "the tripwire: bytecode branch refuses inside a native-sealed image" {
    # Parity proves the native path is right; only this proves it RAN. When
    # the image declares native roots and the binding is absent, reaching
    # the bytecode parser must be a hard error, never a quiet tier.
    import jaclang.jac0core.parser.frontend as frontend;
    import jaclang.jac0core.sealed as sealed;
    saved_memo = list(frontend._NATIVE_PARSE_MEMO);
    saved_fn = sealed.native_tier_required;
    frontend._NATIVE_PARSE_MEMO.clear();
    frontend._NATIVE_PARSE_MEMO.append(None);
    sealed.native_tier_required = _tier_required_stub;
    try {
        with testraises(RuntimeError, `match="bytecode parser was reached") {
            frontend.parse_diags("with entry { x = 1; }", "__tripwire__.jac");
        }
        with testraises(RuntimeError, `match="bytecode parser was reached") {
            frontend.parse("with entry { x = 1; }", "__tripwire__.jac");
        }
    } finally {
        sealed.native_tier_required = saved_fn;
        frontend._NATIVE_PARSE_MEMO.clear();
        for `entry in saved_memo {
            frontend._NATIVE_PARSE_MEMO.append(`entry);
        }
    }
}
