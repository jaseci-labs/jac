"""Construct-by-construct harness for the JCIR emitter (epic #8201).

Every fixture is emitted twice over the same module. The first emission
is the pipeline's own: `JcirGenPass` writes the container and
`JcirBytecodeGenPass` transcribes it, leaving the tree on
`mod.gen.py_ast`. The second is a fresh `JcirGenPass` run over the
already-compiled module, transcribed through `codegen_shim`.

Two things are asserted of every fixture. Exact
`ast.dump(include_attributes=True)` equality between the two trees says
the emitter is deterministic and carries no state across a module that
has already been through the whole pipeline, native lane included --
the leak class this pass is most exposed to. Executing both code objects
and comparing selected globals says the lowering is not merely stable
but correct. Any mismatch is a bug in the emitter, the shim, or the
design doc, never in the fixture.

Cross-lane parity against the retired Python-AST emitter is not measured
here: that lane is gone. Its evidence is the corpus comparison recorded
in the cutover, plus `test_jcir_bound_emitter_bytes.jac`, which pins
that binding the emitter's artifact does not change the bytes it emits.
That file used to be named for a sealed-versus-source comparison it
cannot make: the binder retains no function pointer, so both sides of it
are the source lane until #8288 M1 rung 3.
"""

import ast as pyast;
import marshal;
import os;
import types;
import from builtins { compile as pycompile, exec as pyexec }
import from tests.support { JAC_ROOT }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.schedules { get_py_code_gen }
import from jaclang.compiler.backends.py.jcir_bc_gen_pass { JcirBytecodeGenPass }
import from jaclang.compiler.backends.py.jcir_gen_pass { JcirGenPass }
import from jaclang.compiler.backends.py.codegen_shim { compile_ir, transcribe }

"""Compile a source string, then re-emit it: (pipeline tree, fresh tree, bytes)."""
def dual_compile(src: str, path: str) -> tuple {
    prog = JacProgram();
    mod = prog.compile(
        use_str=src,
        file_path=path,
        options=CompileOptions(
            force_codespace="server",
            skip_native_engine=True,
            suppress_codes=["E5092"]
        )
    );
    assert len(prog.errors_had) == 0 , str([str(e) for e in prog.errors_had]);
    ref_tree = mod.gen.py_ast[0];
    emitter = JcirGenPass(ir_in=mod);
    blob = emitter.ir_bytes();
    (mods, diags) = transcribe(blob);
    assert diags == [];
    assert len(mods) == 1;
    assert mods[0][0] == path;
    return (ref_tree, mods[0][1], blob);
}

"""The same double emission, for a fixture that must be compiled from disk."""
def dual_compile_file(path: str) -> tuple {
    prog = JacProgram();
    mod = prog.compile(path, options=CompileOptions());
    assert len(prog.errors_had) == 0 , str([str(e) for e in prog.errors_had]);
    ref_tree = mod.gen.py_ast[0];
    emitter = JcirGenPass(ir_in=mod);
    blob = emitter.ir_bytes();
    (mods, diags) = transcribe(blob);
    assert diags == [];
    assert len(mods) == 1;
    return (ref_tree, mods[0][1], blob);
}

def assert_dump_equal(ref_tree: any, got_tree: any) {
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
            "tree mismatch near offset "
                + str(i)
                + "\nwant: ..."
                + want[lo:i + 200]
                + "\ngot:  ..."
                + got[lo:i + 200]
        );
    }
}

def code_diffs(a: any, b: any, path: str, out: list) -> list {
    for attr in [
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
    ] {
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
            code_diffs(x, y, f"{path}.consts[{i}]", out);
        } elif (x != y or type(x) is not type(y)) {
            out.append(f"{path}.consts[{i}]: pyast {x!r} vs jcir {y!r}");
        }
    }
    return out;
}

def assert_bytecode_equal(ref_tree: any, mod_path: str, bytecode: bytes) {
    ref_code = pycompile(ref_tree, mod_path, "exec");
    jcir_code = marshal.loads(bytecode);
    diffs = code_diffs(ref_code, jcir_code, "module", []);
    assert diffs == [] , "\n".join(diffs);
}

def exec_both(ref_tree: any, got_tree: any, path: str, names: list) {
    ref_ns: dict = {};
    got_ns: dict = {};
    pyexec(pycompile(ref_tree, path, "exec"), ref_ns);
    pyexec(pycompile(got_tree, path, "exec"), got_ns);
    for name in names {
        assert name in ref_ns , f"{name} missing from pyast lane";
        assert name in got_ns , f"{name} missing from jcir lane";
        assert ref_ns[name] == got_ns[name] , (
            f"{name}: pyast lane {ref_ns[name]!r} != jcir lane {got_ns[name]!r}"
        );
    }
}

glob ROUND_TRIP_FIXTURE: str = """
\"\"\"Round trip fixture.\"\"\"
def greet(name: str, excited: bool = False) -> str {
    msg = f"hello {name}";
    if excited {
        msg = msg + "!";
    }
    return msg;
}

obj Counter {
    has total: int = 0;

    def add(n: int) -> int {
        for i in range(n) {
            self.total = self.total + 1;
        }
        return self.total;
    }
}

with entry {
    result = greet("world", True);
    count = Counter().add(3);
}
""";

test "the round trip fixture re-emits identically" {
    (ref_tree, got_tree, blob) = dual_compile(ROUND_TRIP_FIXTURE, "rt_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    result = compile_ir(blob);
    assert len(result.diags) == 0;
    assert len(result.modules) == 1;
    assert len(result.modules[0].bytecode) > 0;
    assert_bytecode_equal(ref_tree, "rt_fixture.jac", result.modules[0].bytecode);
    exec_both(ref_tree, got_tree, "rt_fixture.jac", ["result", "count"]);
}

test "module scaffolding docstring and imports match" {
    src = """
\"\"\"Module docstring survives.\"\"\"
import os;
import sys as system;
import from os.path { join, basename as base }
import from __future__ { annotations }

with entry {
    p = join("a", "b");
    b = base(p);
    e = os.sep;
}
""";
    (ref_tree, got_tree, _) = dual_compile(src, "scaffold_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    exec_both(ref_tree, got_tree, "scaffold_fixture.jac", ["p", "b", "e"]);
    assert isinstance(got_tree.body[0], pyast.Expr);
    # `Expr.value` is typed as the `expr` base; the docstring is a Constant.
    docstring_expr: any = got_tree.body[0];
    assert docstring_expr.value.value == "Module docstring survives.";
}

test "typed imports wrap in TYPE_CHECKING" {
    src = """
import type from os { path }

def f(p: str) -> str {
    return p;
}
""";
    (ref_tree, got_tree, _) = dual_compile(src, "typed_import_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    found = [
        stmt
        for stmt in got_tree.body
        if isinstance(stmt, pyast.If)
            and isinstance(stmt.`test, pyast.Name)
            and stmt.`test.id == "TYPE_CHECKING"
    ];
    assert len(found) == 1;
}

test "functions defaults decorators and scope directives match" {
    src = """
glob counter: int = 0;

def outer(a: int, b: int = 2, *args: int, c: int = 5, **kw: int) -> int {
    counter += 1;
    return a + b + c + len(args) + len(kw);
}

def deco(fn: any) -> any {
    return fn;
}

@deco
def decorated(x: int) -> int {
    return x * 2;
}

with entry {
    r1 = outer(1);
    r2 = outer(1, 3, 9, 9, c=7, d=1);
    r3 = decorated(21);
    r4 = counter;
}
""";
    (ref_tree, got_tree, _) = dual_compile(src, "funcs_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    exec_both(ref_tree, got_tree, "funcs_fixture.jac", ["r1", "r2", "r3", "r4"]);
}

test "archetype has-field lowering keeps the field contract" {
    src = """
obj Point {
    has x: int = 0,
        y: int = 0,
        tags: list[str] = [],
        label: str = "p";

    def size -> int {
        return self.x + self.y + len(self.tags);
    }
}

class Plain {
    has z: int = 4;
}

obj Deferred {
    has ready: bool postinit;

    def postinit {
        self.ready = True;
    }
}

with entry {
    pt = Point(x=1, y=2);
    pt.tags.append("a");
    s1 = pt.size();
    s2 = Point().tags;
    s3 = Plain().z;
    s4 = Deferred().ready;
}
""";
    (ref_tree, got_tree, _) = dual_compile(src, "arch_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    exec_both(ref_tree, got_tree, "arch_fixture.jac", ["s1", "s2", "s3", "s4"]);
    dumped = pyast.dump(got_tree);
    assert "factory" in dumped;
    assert dumped.count("field(") == 0;
}

test "statement forms match" {
    src = """
def stmts(n: int) -> list[int] {
    out: list[int] = [];
    i = 0;
    while i < n {
        i += 1;
        if i == 2 {
            continue;
        } elif i > 4 {
            break;
        } else {
            out.append(i);
        }
    }
    for j in range(2) {
        out.append(j * 10);
    }
    for k = 0 while k < 2 with k += 1 {
        out.append(k + 100);
    }
    try {
        raise ValueError("boom");
    } except ValueError as e {
        out.append(len(str(e)));
    } finally {
        out.append(-1);
    }
    (a, b) = (1, 2);
    a += b;
    x = y = a;
    del y;
    assert x == a, "mirror";
    return out;
}

with entry {
    r = stmts(6);
}
""";
    (ref_tree, got_tree, _) = dual_compile(src, "stmts_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    exec_both(ref_tree, got_tree, "stmts_fixture.jac", ["r"]);
}

test "with statement and yield match" {
    src = """
import io;

def gen(n: int) -> any {
    for i in range(n) {
        yield i * 2;
    }
}

def consume -> int {
    total = 0;
    with io.StringIO("ab") as fh {
        total += len(fh.read());
    }
    for v in gen(3) {
        total += v;
    }
    return total;
}

with entry {
    r = consume();
}
""";
    (ref_tree, got_tree, _) = dual_compile(src, "with_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    exec_both(ref_tree, got_tree, "with_fixture.jac", ["r"]);
}

test "expression forms match" {
    src = """
def exprs(a: int, b: int) -> dict {
    lst = [a, b, a + b];
    st = {a, b};
    tp = (a, b);
    dc = {"a": a, "b": b};
    comp = [x * 2 for x in lst if x > 1];
    genc = sum(x for x in lst);
    setc = {x % 3 for x in lst};
    dictc = {str(x): x for x in lst};
    tern = a if a > b else b;
    chain = a < b < 100;
    boolop = (a > 0 and b > 0) or a == b;
    fstr = f"{a} and {b:>3} and {a + b!r}";
    sliced = lst[1:];
    stepped = lst[::2];
    idx = lst[0];
    star = [*lst, 99];
    kwargs_d = dict(x=a, **dc);
    walrus = (w := a + b) + w;
    neg = -a + (~b) + (not a);
    powed = a ** 2 // (b % 5 + 1);
    shifted = (a << 2) >> 1 | a & b ^ 3;
    return {
        "lst": lst, "st": sorted(st), "tp": tp, "dc": dc, "comp": comp,
        "genc": genc, "setc": sorted(setc), "dictc": dictc, "tern": tern,
        "chain": chain, "boolop": boolop, "fstr": fstr, "sliced": sliced,
        "stepped": stepped, "idx": idx, "star": star, "kwargs_d": kwargs_d,
        "walrus": walrus, "neg": neg, "powed": powed, "shifted": shifted
    };
}

with entry {
    r = exprs(3, 8);
}
""";
    (ref_tree, got_tree, _) = dual_compile(src, "exprs_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    exec_both(ref_tree, got_tree, "exprs_fixture.jac", ["r"]);
}

test "attribute chains null-ok and multistring match" {
    src = """
obj Box {
    has inner: (Box | None) = None,
        label: str = "leaf";
}

def probe(b: (Box | None)) -> tuple {
    lab = b?.label;
    deep = b.inner?.label if b else None;
    ms = "one "
        "two "
        "three";
    return (lab, deep, ms);
}

with entry {
    r1 = probe(None);
    r2 = probe(Box(inner=Box(label="mid")));
}
""";
    (ref_tree, got_tree, _) = dual_compile(src, "nullok_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    exec_both(ref_tree, got_tree, "nullok_fixture.jac", ["r1", "r2"]);
}

test "lambdas hoist with concrete locations" {
    src = """
def apply(fn: any, v: int) -> int {
    return fn(v);
}

def make_adder(n: int) -> any {
    return lambda (x: int) { x + n; };
}

def block_lambda_user -> int {
    fn = lambda (x: int) -> int {
        y = x * 2;
        return y + 1;
    };
    return apply(fn, 10) + apply(make_adder(5), 1);
}

def defaulted(cb: any = lambda {
    z = 40;
    return z + 2;
}) -> int {
    return cb();
}

with entry {
    r1 = block_lambda_user();
    r2 = defaulted();
}
""";
    (ref_tree, got_tree, _) = dual_compile(src, "lambda_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    exec_both(ref_tree, got_tree, "lambda_fixture.jac", ["r1", "r2"]);
    missing: list = [];
    for node in pyast.walk(got_tree) {
        if "lineno" in node._attributes {
            # `lineno` lives on concrete nodes, not the `AST` base the stub
            # types here; the `_attributes` guard is the real check.
            located: any = node;
            if (located.lineno is None or located.lineno < 1) {
                missing.append(pyast.dump(node)[:60]);
            }
        }
    }
    assert missing == [] , str(missing);
}

test "switch lowering duplicates shared recipes" {
    src = """
def pick(v: int) -> str {
    out = "";
    switch v {
        case 1:
            out = "one";
            break;

        case 2 | 3:
            out = "few";
            break;

        default:
            out = "many";

    }
    return out;
}

with entry {
    r = [pick(1), pick(2), pick(3), pick(9)];
}
""";
    (ref_tree, got_tree, _) = dual_compile(src, "switch_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    exec_both(ref_tree, got_tree, "switch_fixture.jac", ["r"]);
}

test "enums lower with auto and kind imports" {
    src = """
enum Color {
    RED,
    GREEN,
    BLUE
}

enum Size(int) {
    S = 1,
    M = 2
}

with entry {
    c = Color.GREEN.name;
    s = Size.M.value;
    total = Size.S.value + Size.M.value;
}
""";
    (ref_tree, got_tree, _) = dual_compile(src, "enum_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    exec_both(ref_tree, got_tree, "enum_fixture.jac", ["c", "s", "total"]);
}

test "python inline splice lands with jac line offsets" {
    src = """
with entry {
    seed = 40;
}

::py::
X = seed + 2
Y = X * 2
::py::
""";
    (ref_tree, got_tree, _) = dual_compile(src, "pyinline_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    exec_both(ref_tree, got_tree, "pyinline_fixture.jac", ["seed", "X", "Y"]);
}

test "global vars and module code guard match" {
    src = """
\"\"\"Doc.\"\"\"
glob threshold: int = 10,
     name: str = "mod";

with entry:__main__ {
    ran_main = True;
}

with entry {
    always = threshold + len(name);
}
""";
    (ref_tree, got_tree, _) = dual_compile(src, "globals_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    exec_both(ref_tree, got_tree, "globals_fixture.jac", ["always"]);
}

test "super calls type aliases and iter-for continue match" {
    src = """
type Plain = int;
type Branded := int;

obj Base {
    def describe -> str {
        return "base";
    }
}

obj Derived(Base) {
    def describe -> str {
        return "derived+" + super.describe();
    }
}

def skip_evens(n: Plain) -> list[Branded] {
    out: list[Branded] = [];
    for k = 0 while k < n with k += 1 {
        if k % 2 == 0 {
            continue;
        }
        out.append(Branded(k));
    }
    return out;
}

with entry {
    d = Derived().describe();
    ks = skip_evens(6);
    scratch = {"a": 1, "b": 2};
    del scratch["a"];
    left = sorted(scratch.keys());
}
""";
    (ref_tree, got_tree, _) = dual_compile(src, "super_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    exec_both(ref_tree, got_tree, "super_fixture.jac", ["d", "ks", "left"]);
}

test "native test shims lower identically via splice" {
    src = """
def double(x: int) -> int {
    return x * 2;
}

test "doubles correctly" {
    assert double(2) == 4;
}
""";
    (ref_tree, got_tree, blob) = dual_compile(src, "testblock_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    result = compile_ir(blob);
    assert len(result.diags) == 0;
    assert_bytecode_equal(
        ref_tree, "testblock_fixture.jac", result.modules[0].bytecode
    );
    dumped = pyast.dump(got_tree);
    assert "invoke_native_test" in dumped;
}

test "sem strings lower to sem decorators" {
    src = """
obj Greeter {
    has name: str = "anon";

    def hello -> str {
        return "hi " + self.name;
    }
}

sem Greeter = "A friendly greeter.";
sem Greeter.name = "The name to greet with.";

with entry {
    g = Greeter(name="zed");
    msg = g.hello();
}
""";
    (ref_tree, got_tree, _) = dual_compile(src, "sem_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    dumped = pyast.dump(got_tree);
    assert "A friendly greeter." in dumped;
    exec_both(ref_tree, got_tree, "sem_fixture.jac", ["msg"]);
}

test "llm ability bodies lower to call_llm recipes" {
    src = """
obj FakeModel {
    has call_params: dict = {};
}

def make_model -> FakeModel {
    return FakeModel();
}

def summarize(text: str) -> str by make_model();

obj Helper {
    def rate(text: str) -> int by make_model();
}
""";
    (ref_tree, got_tree, blob) = dual_compile(src, "llm_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    dumped = pyast.dump(got_tree);
    assert "call_llm" in dumped;
    assert "get_mtir" in dumped;
    result = compile_ir(blob);
    assert len(result.diags) == 0;
    assert_bytecode_equal(ref_tree, "llm_fixture.jac", result.modules[0].bytecode);
}

test "real repo file srcloc lowers identically end to end" {
    path = os.path.join(JAC_ROOT, "jaclang", "compiler", "frontend", "srcloc.jac");
    (ref_tree, got_tree, blob) = dual_compile_file(path);
    assert_dump_equal(ref_tree, got_tree);
    result = compile_ir(blob);
    assert len(result.diags) == 0;
    assert len(result.modules) == 1;
    assert_bytecode_equal(
        ref_tree, result.modules[0].mod_path, result.modules[0].bytecode
    );
}

test "walkers edges and visit lower identically" {
    src = """
node Spot {
    has name: str = "";
}

edge Road {}

walker Traveler {
    has seen: list[str] = [],
        hops: int = 0;

    can begin with Root entry {
        visit [-->[?:Spot]] else {
            disengage;
        }
    }

    can step with Spot entry {
        -> Spot {
            self.seen.append(here.name);
        }
        self.hops += 1;
        if self.hops > 3 {
            skip;
        }
        report here.name;
        visit [->:Road:->[?:Spot]];
    }

    can wrap with Root exit {
        report self.seen;
    }
}

def build_map -> list {
    a = Spot(name="a");
    b = Spot(name="b");
    root ++> a;
    a +>:Road():+> b;
    a del --> b;
    named = [root-->[?:Spot]][?name == "a"];
    first_two = [root-->][0:2];
    tagged = [root-->[?:Spot]](=name="seen");
    return named + first_two + tagged;
}

def launch -> Traveler {
    return root spawn Traveler();
}
""";
    (ref_tree, got_tree, blob) = dual_compile(src, "walker_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    result = compile_ir(blob);
    assert len(result.diags) == 0;
    assert_bytecode_equal(ref_tree, "walker_fixture.jac", result.modules[0].bytecode);
}

test "match statements lower identically" {
    src = """
obj Point {
    has x: int = 0,
        y: int = 0;
}

def classify(v: any) -> str {
    match v {
        case 1 | 2:
            return "small";

        case [first, *rest] if first == 9:
            return f"nine-led {rest}";

        case {"kind": k, **extra}:
            return f"map {k}/{extra}";

        case Point(x=0, y=0):
            return "origin";

        case Point(x=xx):
            return f"x {xx}";

        case str() as sv:
            return f"str {sv}";

        case None:
            return "none";

        case _:
            return "other";

    }
}

with entry {
    r = [
        classify(1),
        classify([9, 8, 7]),
        classify({"kind": "z", "extra": 1}),
        classify(Point()),
        classify(Point(x=5, y=2)),
        classify("hi"),
        classify(None),
        classify(3.5)
    ];
}
""";
    (ref_tree, got_tree, _) = dual_compile(src, "match_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    exec_both(ref_tree, got_tree, "match_fixture.jac", ["r"]);
}

test "async constructs lower identically" {
    src = """
import asyncio;

async def worker(n: int) -> int {
    await asyncio.sleep(0);
    return n * 2;
}

async def gather_all -> int {
    total = 0;
    a = await worker(2);
    b = await worker(3);
    lock = asyncio.Lock();
    async with lock {
        total = a + b;
    }
    return total;
}

with entry {
    r = asyncio.run(gather_all());
}
""";
    (ref_tree, got_tree, _) = dual_compile(src, "async_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    exec_both(ref_tree, got_tree, "async_fixture.jac", ["r"]);
}

test "real repo walker file social_graph lowers identically" {
    path = os.path.join(
        JAC_ROOT, "examples", "jaclang_org", "socialize", "social_graph.jac"
    );
    (ref_tree, got_tree, blob) = dual_compile_file(path);
    assert_dump_equal(ref_tree, got_tree);
    result = compile_ir(blob);
    assert len(result.diags) == 0;
    assert_bytecode_equal(
        ref_tree, result.modules[0].mod_path, result.modules[0].bytecode
    );
}

test "the pipeline's codegen tail is jcir, with nothing to select" {
    # The container is not an option the pipeline can be talked out of:
    # a plain compile leaves JCIR bytes on the module, and the bytecode
    # the driver hands the runtime is the one the container produced.
    src = """
\"\"\"Tail fixture.\"\"\"
def double(x: int) -> int {
    return x * 2;
}

with entry {
    r = double(21);
}
""";
    prog = JacProgram();
    mod = prog.compile(
        use_str=src,
        file_path="tail_fixture.jac",
        options=CompileOptions(
            force_codespace="server", skip_native_engine=True, suppress_codes=["E5092"]
        )
    );
    assert len(prog.errors_had) == 0 , str([str(e) for e in prog.errors_had]);
    assert mod.gen.jcir , "a compiled module must carry its codegen container";
    assert mod.gen.py_bytecode;
    sched = get_py_code_gen(native=False);
    assert JcirGenPass in sched , f"jcir is not in the codegen schedule: {sched}";
    assert JcirBytecodeGenPass in sched;
    for `entry in sched {
        assert "Pyast" not in `entry.__name__ and "PyBytecode" not in `entry.__name__ , (
            f"a legacy emitter is back in the codegen schedule: {`entry.__name__}"
        );
    }
    piped_code = marshal.loads(mod.gen.py_bytecode);
    round_tripped = pycompile(mod.gen.py_ast[0], "tail_fixture.jac", "exec");
    diffs = code_diffs(round_tripped, piped_code, "module", []);
    assert diffs == [] , "\n".join(diffs);
}

test "server-side jsx lowers to jaclib jsx calls" {
    import tempfile;
    src = """
def page(title: str, items: list[str], extra: dict) -> JsxElement {
    rows = [<li key={it}>{it}</li> for it in items];
    return <div title="box" active data={len(items)}>
        <h1>Hello &amp; {title}</h1>
        <ul>{rows}</ul>
        <span {...extra}>tail</span>
        <>fragment text</>
    </div>;
}

with entry {
    rendered = page("srv", ["s1", "s2"], {"id": "x"});
}
""";
    tdir = tempfile.mkdtemp(prefix="jcir_jsx_");
    with open(os.path.join(tdir, "jac.toml"), "w") as f {
        f.write('[placement.pins]\n"*" = "server"\n');
    }
    comp_path = os.path.join(tdir, "comp.jac");
    with open(comp_path, "w") as f {
        f.write(src);
    }
    (ref_tree, got_tree, blob) = dual_compile_file(comp_path);
    assert_dump_equal(ref_tree, got_tree);
    dumped = pyast.dump(got_tree);
    assert "'jsx'" in dumped;
    assert "Hello & " in dumped;
    result = compile_ir(blob);
    assert len(result.diags) == 0;
    assert_bytecode_equal(ref_tree, comp_path, result.modules[0].bytecode);
}

test "a genai call refuses deliberately rather than lowering wrong" {
    src = """
def g -> int {
    return 1;
}

def f -> int {
    return g();
}
""";
    prog = JacProgram();
    mod = prog.compile(use_str=src, file_path="genai_fixture.jac", no_cgen=True);
    calls = mod.get_all_sub_nodes(uni.FuncCall);
    assert calls;
    calls[0].genai_call = calls[0].target;
    caught_jcir = "";
    try {
        JcirGenPass(ir_in=mod);
    } except NotImplementedError as e {
        caught_jcir = str(e);
    }
    assert "genai call expression" in caught_jcir , (
        "a genai call must refuse by name, not lower to something else"
    );
}

test "concurrency flow and wait lower identically" {
    src = """
def slow(n: int) -> int {
    return n + 1;
}

def run_pair -> int {
    t1 = flow slow(1);
    t2 = flow slow(2);
    a = wait t1;
    b = wait t2;
    return int(a) + int(b);
}

with entry {
    r = run_pair();
}
""";
    (ref_tree, got_tree, _) = dual_compile(src, "flow_fixture.jac");
    assert_dump_equal(ref_tree, got_tree);
    exec_both(ref_tree, got_tree, "flow_fixture.jac", ["r"]);
}
