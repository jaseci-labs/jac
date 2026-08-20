"""Prefix-vs-staged parity over the corpus, red-first (wave A' item A6).

The flip makes the fused native prefix the DEFAULT compile route. Nothing
about that is safe unless the two routes produce the same compiler output, so
this suite compiles the same source both ways and compares what a divergence
would actually cost:

  * the module tree, unparse-exact -- `unparse_module` renders the tree back
    to source through the normalizer and formatter, so any structural or token
    difference shows up as a text diff;
  * the tree field-by-field -- an unparse fingerprint sees kid TEXT but not
    field VALUES. An erased slot decoding to None, a wrong enum member, a
    symbol-table edge that never formed are all unparse-invisible and fatal.
    The walker below compares every scalar, enum, list length, dict key set
    and class name across both trees;
  * the downstream code object -- field-by-field over `co_*`, recursively into
    nested code objects, from the marshalled bytecode each route produced.
    This is the artifact that ships, so it is the one that has to be identical.

RED FIRST. A parity suite that cannot fail is decoration. Two properties are
proven before any green result is trusted:

  1. `injected divergence` installs `diverging_prefix_entry`, a prefix that
     parses to a tree differing from the staged tree by exactly one string
     literal and then executes NOTHING -- so the driver runs the entire staged
     schedule over it and the compile is well-formed. The only difference
     between the routes is that one token. The test asserts every comparator
     reports it. If the harness were blind this test would pass green and the
     suite would be worthless.

  2. `the comparators are not vacuous` drives each comparator against a
     hand-perturbed input directly, so a comparator that silently returns "no
     differences" for everything is caught even if routing changes.

Only then does the corpus run. It routes through `reference_prefix_entry`, a
Python stand-in that honours the crossing's contract exactly: it takes the
driver-stamped facts, runs the claimed prefix passes, and reports what it ran.
Routing through it exercises the SEAM -- schedule trimming, PROVIDES marking,
facts stamping, the handoff -- against the same passes the staged route runs,
so a green corpus means the routing is transparent. When the native
`parse_and_run_prefix` lands it plugs into the same seam and this suite
becomes the canary the flip ships behind, unchanged.
"""

import marshal;
import os;
import from difflib { unified_diff }
import from pathlib { Path }
import from tests.support { JAC_ROOT }
import from tests.compiler.fixtures.prefix_reference {
    PERTURBED_LITERAL,
    diverging_prefix_entry,
    reference_prefix_entry
}
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.tool.unparse_pass { unparse_module }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.prefix_flip {
    clear_prefix_entry,
    prefix_outcomes_reset,
    prefix_quarantine_clear,
    prefix_snapshot,
    set_prefix_entry
}

"""The corpus, widening from a leaf module to a real application to compiler
sources -- the three shapes that break differently. Compiler-grade sources are
the harshest: they are the trees the compiler compiles itself from."""
glob PARITY_CORPUS: list[str] = [
         "tests/compiler/fixtures/fam.jac",
         "examples/littleX/social_graph.jac",
         "examples/mini_todo/main.jac",
         "jaclang/jac0core/srcloc.jac",
         "jaclang/jac0core/expr_keys.jac",
         "jaclang/compiler/expr_keys.jac",

     ],
     _SKIP_FIELDS: tuple[str] = ("rc_last_use", "_deferred_type_diags", "_gen", ),
     _CO_FIELDS: tuple[str] = (
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
         "co_filename",
         "co_name",
         "co_qualname",
         "co_firstlineno",

     );

def _corpus_paths -> list[str] {
    out: list[str] = [];
    for rel in PARITY_CORPUS {
        p = os.path.join(JAC_ROOT, rel);
        if os.path.exists(p) {
            out.append(p);
        }
    }
    return out;
}

def _reset {
    clear_prefix_entry();
    prefix_outcomes_reset();
    prefix_quarantine_clear();
}

"""Compile one source through whichever route `route` selects. `route` None
means the staged route: no prefix is installed, so the predicate declines and
the driver runs the whole schedule itself.

Two pins keep the two routes comparable, and both are about the NATIVE
LOWERING lane, which sits far downstream of the prefix and is not what this
suite measures.

`default_codespace="server"` stops the corpus's compiler-grade sources from
electing the native codespace. A module that prefers native and fails to lower
is DEMOTED: the driver invalidates it and re-runs `_compile_once`, so the
module that survives is not the one that became the program's main. Worse, the
demotion is memoized per process and per path, so the first route pays for it
and the second finds the path already marked and skips the native attempt
entirely. The routes then differ in `decided_codespace`, `parent`, and
everything the second pass recomputed -- by compile ORDER, not by route.

`na_coverage_begin` is called for its side effect rather than its coverage: it
clears that demotion memo and the native scan memo, so neither route inherits
the other's verdicts even for modules the pin does not cover.

Both are the same class of correction as the dependency warnings scoped out of
`_diag_diffs`: cure the cross-route coupling at its cause instead of excluding
the fields it corrupts. Every comparator, code objects included, still runs
over the full schedule."""
def _compile_route(path: str, route: any) -> tuple[any] {
    import from jaclang.jac0core.compiler { na_coverage_begin, na_coverage_end }
    _reset();
    na_coverage_begin();
    if route is not None {
        set_prefix_entry(route);
    }
    prog = JacProgram();
    try {
        mod = prog.compile(
            file_path=path,
            options=CompileOptions(
                type_check=False,
                no_cgen=False,
                force_target_program=True,
                default_codespace="server"
            )
        );
        snap = prefix_snapshot();
    } finally {
        clear_prefix_entry();
        na_coverage_end();
    }
    return (prog, mod, snap);
}

def _bytecode_of(mod: any) -> any {
    raw = mod.gen?.py_bytecode;
    if not raw {
        return None;
    }
    return marshal.loads(raw);
}

"""Field-by-field over two code objects, recursing into nested ones. Returns
the list of differences; empty means identical."""
def _code_diffs(a: any, b: any, where: str = "<module>") -> list[str] {
    diffs: list[str] = [];
    if a is None or b is None {
        if a is not b {
            diffs.append(
                f"{where}: one route produced bytecode and the other did not "
                f"({a is not None} vs {b is not None})"
            );
        }
        return diffs;
    }
    for f in _CO_FIELDS {
        va = getattr(a, f, None);
        vb = getattr(b, f, None);
        if va != vb {
            diffs.append(f"{where}.{f}: {repr(va)[:120]} vs {repr(vb)[:120]}");
        }
    }
    ca = [
        c
        for c in a.co_consts
        if hasattr(c, "co_code")
    ];
    cb = [
        c
        for c in b.co_consts
        if hasattr(c, "co_code")
    ];
    sa = [
        c
        for c in a.co_consts
        if not hasattr(c, "co_code")
    ];
    sb = [
        c
        for c in b.co_consts
        if not hasattr(c, "co_code")
    ];
    if sa != sb {
        diffs.append(f"{where}.co_consts: {repr(sa)[:160]} vs {repr(sb)[:160]}");
    }
    if len(ca) != len(cb) {
        diffs.append(
            f"{where}.co_consts: {len(ca)} nested code object(s) vs {len(cb)}"
        );
        return diffs;
    }
    for (x, y) in zip(ca, cb) {
        diffs.extend(_code_diffs(x, y, f"{where}.{x.co_name}"));
    }
    return diffs;
}

"""Every scalar, enum, list length, dict key set and class name across two
trees. Unparse sees kid text; this sees field VALUES.

`_SKIP_FIELDS` names the three slots whose contents are not compiler output:
`rc_last_use` and `_deferred_type_diags` are keyed by `id(node)`, so their key
SETS are allocator addresses and differ between any two compiles of anything;
`_gen` is a lazily materialized slot whose mere presence records that someone
read `.gen`, not what the compiler decided. Everything else is compared."""
def _field_diffs(a: any, b: any, where: str = "mod") -> list[str] {
    import enum as _py_enum;
    stack: list[any] = [(a, b, where, )];
    seen: set = set();
    diffs: list[str] = [];
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
        if dx is None or dy is None {
            continue;
        }
        kx = set(dx.keys());
        ky = set(dy.keys());
        if kx != ky {
            diffs.append(f"{p}: keys +{sorted(kx - ky)} -{sorted(ky - kx)}");
        }
        for k in sorted(kx & ky) {
            if k in _SKIP_FIELDS {
                continue;
            }
            vx = dx[k];
            vy = dy[k];
            if isinstance(vx, (int, str, bool, float, ))
                or vx is None
                or isinstance(vx, _py_enum.Enum) {
                if vx != vy or type(vx).__name__ != type(vy).__name__ {
                    diffs.append(f"{p}.{k}: {repr(vx)[:70]} vs {repr(vy)[:70]}");
                }
            } elif isinstance(vx, list) {
                if not isinstance(vy, list) or len(vx) != len(vy) {
                    diffs.append(f"{p}.{k}: list length diverged");
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
        if hasattr(x, "kid") and hasattr(y, "kid") {
            for (i, (cx, cy)) in enumerate(zip(x.kid, y.kid)) {
                stack.append((cx, cy, f"{p}.kid[{i}]", ));
            }
        }
    }
    return diffs;
}

"""Diagnostics are compiler output too, and the flip's whole premise is that
they cross the boundary as data without loss. Compares the delivered alert
stream by code, severity, location and message -- a prefix that swallows a
warning or invents an error is a divergence even when the tree matches.

Scoped to alerts whose location is the module under test. A compile also
delivers alerts for every dependency it pulls in, and whichever route reaches
a shared dependency FIRST pays for its warnings while the second finds it
already in the hub. That is a property of running both routes in one process,
not of either route, and it swings in both directions -- so comparing the
whole stream measures compile order, not parity."""
def _diag_diffs(prefix_prog: any, staged_prog: any, path: str) -> list[str] {
    diffs: list[str] = [];
    own_file = os.path.basename(path);
    for (kind, pa, sa) in [
        ("error", prefix_prog.errors_had, staged_prog.errors_had, ),
        ("warning", prefix_prog.warnings_had, staged_prog.warnings_had, )
    ] {
        pk = sorted(
            _diag_key(a)
            for a in pa
            if _diag_owns(a, own_file)
        );
        sk = sorted(
            _diag_key(a)
            for a in sa
            if _diag_owns(a, own_file)
        );
        if pk == sk {
            continue;
        }
        only_prefix = [
            k
            for k in pk
            if k not in sk
        ];
        only_staged = [
            k
            for k in sk
            if k not in pk
        ];
        diffs.append(
            f"{path}: {kind} stream diverged " f"(prefix {len(pk)}, staged {len(sk)})"
        );
        for k in only_prefix[:4] {
            diffs.append(f"    only on the prefix route: {k}");
        }
        for k in only_staged[:4] {
            diffs.append(f"    only on the staged route: {k}");
        }
    }
    return diffs;
}

def _diag_owns(alrt: any, own_file: str) -> bool {
    try {
        return os.path.basename(str(alrt.loc.mod_path)) == own_file;
    } except Exception {
        return False;
    }
}

def _diag_key(alrt: any) -> str {
    code = alrt.code.code if alrt.code is not None else "<uncoded>";
    loc = alrt.loc;
    return (
        f"{code}@{os.path.basename(str(loc.mod_path))}:"
        f"{loc.first_line}:{loc.col_start} {alrt.msg}"
    );
}

def _unparse_diff(prefix_mod: any, staged_mod: any, path: str) -> list[str] {
    a = unparse_module(prefix_mod);
    b = unparse_module(staged_mod);
    if a == b {
        return [];
    }
    return [
        f"{path}: unparse diverged",
        *list(unified_diff(b.splitlines(), a.splitlines(), lineterm=""))[:24]
    ];
}

"""The harness proper: compile `path` both ways and return every difference
the three comparators find. Empty means the routes agree."""
def parity_diffs(path: str, route: any) -> list[str] {
    (staged_prog, staged_mod, _ss) = _compile_route(path, None);
    (prefix_prog, prefix_mod, _ps) = _compile_route(path, route);
    diffs: list[str] = [];
    if staged_mod is None or prefix_mod is None {
        return [
            f"{path}: a route produced no module "
            f"(staged={staged_mod is not None}, prefix={prefix_mod is not None})"
        ];
    }
    diffs.extend(_diag_diffs(prefix_prog, staged_prog, path));
    diffs.extend(_field_diffs(prefix_mod, staged_mod, os.path.basename(path)));
    diffs.extend(_code_diffs(_bytecode_of(prefix_mod), _bytecode_of(staged_mod), path));
    diffs.extend(_unparse_diff(prefix_mod, staged_mod, path));
    return diffs;
}


test "the comparators are not vacuous" {
    src_a = 'glob a: str = "one";\nwith entry { print(a); }\n';
    src_b = 'glob a: str = "two";\nwith entry { print(a); }\n';
    prog_a = JacProgram();
    prog_b = JacProgram();
    mod_a = prog_a.parse_str(src_a, "vacuity_a.jac");
    mod_b = prog_b.parse_str(src_b, "vacuity_b.jac");
    fdiffs = _field_diffs(mod_a, mod_b, "vacuity");
    assert fdiffs , (
        "the field walker found no difference between trees built from "
        "different sources; it is comparing nothing"
    );
    code_a = compile("x = 1\n", "a", "exec");
    code_b = compile("x = 2\n", "a", "exec");
    cdiffs = _code_diffs(code_a, code_b);
    assert cdiffs , (
        "the code-object comparator found no difference between two "
        "different code objects; it is comparing nothing"
    );
    assert _code_diffs(code_a, code_a) == [] , (
        "the code-object comparator reports a difference against itself"
    );
    assert _code_diffs(None, code_a) , (
        "a missing bytecode on one route must be reported, not skipped"
    );
    assert _code_diffs(None, None) == [];
}

test "injected divergence: the harness fails when the routes disagree" {
    path = os.path.join(JAC_ROOT, "tests", "compiler", "fixtures", "fam.jac");
    if not os.path.exists(path) {
        testskip("fam.jac fixture is absent");
    }
    try {
        diffs = parity_diffs(path, diverging_prefix_entry);
    } finally {
        _reset();
    }
    assert diffs , (
        "a prefix that returned a tree with a perturbed string literal was "
        "declared at parity. The harness is blind and every green result "
        "below it is meaningless."
    );
    joined = chr(10).join(diffs);
    assert PERTURBED_LITERAL in joined , (
        "the harness saw a difference but not the injected one; it may be "
        f"reporting noise instead of the perturbation: {joined[:600]}"
    );
    kinds = {
        "field": any(d.startswith("fam") for d in diffs),
        "code": any(".co_" in d for d in diffs),
        "unparse": any("unparse diverged" in d for d in diffs)
    };
    assert kinds["code"] , (
        "the perturbed literal never reached the code object; the "
        "field-by-field bytecode comparator did not fire: "
        f"{joined[:600]}"
    );
    assert kinds["field"] or kinds["unparse"] , (
        f"neither tree comparator fired on the perturbation: {joined[:600]}"
    );
}

test "the reference prefix is transparent on the corpus" {
    paths = _corpus_paths();
    assert len(paths) >= 4 , (
        f"the parity corpus shrank to {len(paths)} file(s); update "
        "PARITY_CORPUS rather than letting coverage quietly drain"
    );
    failures: list[str] = [];
    admitted = 0;
    for path in paths {
        try {
            diffs = parity_diffs(path, reference_prefix_entry);
        } except Exception as exc {
            failures.append(f"{path}: harness raised {type(exc).__name__}: {exc}");
            continue;
        }
        if diffs {
            failures.append(
                f"{path}: {len(diffs)} divergence(s)"
                    + chr(10)
                    + chr(10).join(f"    {d}" for d in diffs[:8])
            );
        }
    }
    _reset();
    assert not failures , (
        "prefix and staged routes diverged:" + chr(10) + chr(10).join(failures[:4])
    );
}

test "the corpus actually rides the prefix, not a silent fallback" {
    paths = _corpus_paths();
    rode = 0;
    declined: list[str] = [];
    for path in paths {
        (_p, mod, snap) = _compile_route(path, reference_prefix_entry);
        rec = snap.get(os.path.realpath(path));
        if rec is not None and rec["admitted"] {
            rode += 1;
        } else {
            declined.append(f"{path}: {rec['clause'] if rec else '<unrecorded>'}");
        }
    }
    _reset();
    assert rode >= 1 , (
        "no corpus file rode the prefix, so the parity result above compared "
        "the staged route against itself and proves nothing. Declines: "
        + chr(10).join(declined)
    );
}

test "the staged route is unchanged when no prefix is installed" {
    path = os.path.join(JAC_ROOT, "tests", "compiler", "fixtures", "fam.jac");
    if not os.path.exists(path) {
        testskip("fam.jac fixture is absent");
    }
    diffs = parity_diffs(path, None);
    _reset();
    assert not diffs , (
        "two staged compiles of the same source disagreed, so the harness "
        "has a nondeterminism problem of its own: "
        + chr(10).join(diffs[:8])
    );
}
