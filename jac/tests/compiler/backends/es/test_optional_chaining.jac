"""Null-safe trailers (`?.`, `?[...]`) keep their short-circuit in emitted JavaScript."""

import json;
import shutil;
import from jaclang.compiler.passes.execution { run_walker }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
import from jaclang.compiler.driver.pass_driver { run_pass }
import from tests.compiler.backends.es.codegen_helpers { run_js_module }

glob OPTIONAL_SRC = """
obj Box {
    has inner: Box | None = None;
    has n: int = 0;
    def get -> int { return self.n; }
}
glob hits: list[int] = [];
def bump(x: any) -> any { hits.append(1); return x; }
def attr(x: any) -> any { return x?.a; }
def chain(x: any) -> any { return x?.a?.b; }
def index(x: any) -> any { return x?[0]; }
def index_var(x: any, i: int) -> any { return x?[i]; }
def slice_of(x: any) -> any { return x?[1:2]; }
def call(x: any) -> any { return x?.f(); }
def method(b: Box | None) -> any { return b?.get(); }
def upper(s: str | None) -> any { return s?.upper(); }
def typed_chain(b: Box | None) -> any { return b?.inner?.n; }
def once(x: any, i: int) -> any { return bump(x)?[i]; }
def subtle -> any { return globalThis.crypto?.subtle; }
def fields(details: any, envelope: any) -> any {
    return [details.error?.message, envelope.data?.identities];
}
def store(x: any) { x?.a = 1; }
""";

def compile_client(source: str) -> str {
    program = JacProgram();
    module = program.compile(
        "optional_chaining.jac",
        use_str=source,
        options=CompileOptions(force_codespace="client", no_cgen=True)
    );
    run_pass(TypeCheckPass, module, program);
    run_walker(EsastGenPass, module=module, prog=program);
    assert not program.errors_had , "\n".join(
        str(error) for error in program.errors_had
    );
    return module.gen.js;
}

test "optional chaining on any-typed values emits JavaScript optional chains" {
    js = compile_client(OPTIONAL_SRC);
    for expected in [
        "return x?.a;",
        "return x?.a?.b;",
        "return x?.[0];",
        "return x?.slice(1, 2);",
        "return x?.f();",
        "return b?.inner?.n;",
        "return globalThis.crypto?.subtle;",
        "details.error?.message",
        "envelope.data?.identities"
    ] {
        assert expected in js , f"missing {expected!r} in:\n{js}";
    }
    # JavaScript rejects an optional chain as an assignment target.
    assert "x.a = 1;" in js , js;
}

test "reading through a missing value yields undefined instead of throwing" {
    if not shutil.which("node") {
        testskip("node not on PATH");
    }
    js = compile_client(OPTIONAL_SRC);
    probe = """
const u = (v) => v === undefined;
console.log(JSON.stringify([
    u(attr(null)), u(attr(undefined)), attr({a: 1}),
    u(chain(null)), u(chain({})), chain({a: {b: 2}}),
    u(index(null)), index([5]),
    u(index_var(null, 0)), index_var([5, 6], 1),
    u(slice_of(null)), slice_of([1, 2, 3]),
    u(call(null)), call({f: () => 7}),
    u(method(null)), method(new Box({n: 4})),
    u(upper(null)), upper("ab"),
    u(typed_chain(null)), u(typed_chain(new Box())),
    typed_chain(new Box({inner: new Box({n: 9})})),
    u(once(null, 0)), once([3], 0), hits.length,
    u(fields({}, {})[0]), u(fields({}, {})[1])
]));
""";
    result = run_js_module(js + "\n" + probe, timeout=10.0);
    assert result.returncode == 0 , result.stderr + "\n" + js;
    assert json.loads(result.stdout.strip())
        == [
            True,
            True,
            1,
            True,
            True,
            2,
            True,
            5,
            True,
            6,
            True,
            [2],
            True,
            7,
            True,
            4,
            True,
            "AB",
            True,
            True,
            9,
            True,
            3,
            2,
            True,
            True
        ] , result.stdout + "\n" + js;
}

glob AWAITED_SRC = """
glob seen: list[int] = [];
def recv(x: any) -> any { seen.append(1); return x; }
async def key() -> int { return 1; }
async def word() -> str { return ","; }
async def num() -> int { return 3; }
def total(a: int, b: int = 0, c: int = 0) -> int { return a + b + c; }
async def awaited_index(x: any) -> any { return recv(x)?[await key()]; }
async def awaited_split(s: str | None) -> any { return recv(s)?.split(await word()); }
async def awaited_callee(x: any) -> any { return recv(x)?[await key()](await num()); }
async def awaited_kwargs(kw: dict[str, int]) -> int {
    return total(await num(), **kw, **kw);
}
""";

test "awaited reads inside a null-safe guard stay in their async scope" {
    js = compile_client(AWAITED_SRC);
    assert "(__jac_opt =>" not in js , js;
    assert "await (async __jac_opt =>" in js , js;
    assert "await (async __jac_kwargs =>" in js , js;
}

test "awaited reads inside a null-safe guard evaluate the receiver once" {
    if not shutil.which("node") {
        testskip("node not on PATH");
    }
    js = compile_client(AWAITED_SRC);
    probe = """
const u = (v) => v === undefined;
const out = [
    u(await awaited_index(null)), await awaited_index([5, 6]), seen.length,
    u(await awaited_split(null)), await awaited_split("a,b"), seen.length,
    await awaited_callee([0, (n) => n * 2]), seen.length,
    await awaited_kwargs({b: 1, c: 2})
];
console.log(JSON.stringify(out));
""";
    result = run_js_module(js + "\n" + probe, timeout=10.0);
    assert result.returncode == 0 , result.stderr + "\n" + js;
    assert json.loads(result.stdout.strip())
        == [True, 6, 2, True, ["a", "b"], 4, 6, 5, 6] , result.stdout + "\n" + js;
}

glob STORED_PROMISE_SRC = """
glob seen: list[int] = [];
def recv(x: any) -> any { seen.append(1); return x; }
async def key() -> int { return 1; }
async def num() -> int { return 3; }
def pick(a: any, b: int = 0, c: int = 0) -> any { return a; }
async def stored(x: any) -> list[any] {
    value = recv(x)?[await key()];
    return [value];
}
async def stored_kwargs(p: any, kw: dict[str, int]) -> list[any] {
    value = pick(p, await num(), **kw, **kw);
    return [value];
}
""";

test "an awaited null-safe guard keeps a stored promise a promise" {
    if not shutil.which("node") {
        testskip("node not on PATH");
    }
    js = compile_client(STORED_PROMISE_SRC);
    probe = """
const thenable = (v) => v !== null && typeof v === "object" && typeof v.then === "function";
// An async function adopts a promise it returns, so each one hands back
// the value it read in a list.
const [r] = await stored([0, Promise.resolve(7)]);
const [k] = await stored_kwargs(Promise.resolve(8), {c: 1});
console.log(JSON.stringify([
    thenable(r), await r, seen.length,
    (await stored(null))[0] === undefined, seen.length,
    (await stored([0, 5]))[0],
    thenable(k), await k
]));
""";
    result = run_js_module(js + "\n" + probe, timeout=10.0);
    assert result.returncode == 0 , result.stderr + "\n" + js;
    assert json.loads(result.stdout.strip()) == [True, 7, 1, True, 2, 5, True, 8] , result.stdout
        + "\n"
        + js;
}

glob CHAIN_SRC = """
glob hits: list[int] = [];
def bump(x: any) -> any { hits.append(1); return x; }
def idx_call(x: any, k: int, n: int) -> any { return x?[k](n); }
def once_call(x: any, k: int, n: int) -> any { return bump(x)?[k](n); }
def idx_attr(x: any, k: int) -> any { return x?[k].b; }
def idx_idx(x: any, k: int, j: int) -> any { return x?[k][j]; }
def idx_method(x: any, k: int) -> any { return x?[k].m(1); }
def idx_curry(x: any, k: int) -> any { return x?[k](1)(2); }
def nested_call(x: any, k: int, j: int, n: int) -> any { return x?[k]?[j](n); }
def strip_upper(s: str | None) -> any { return s?.strip().upper(); }
def split_first(s: str | None) -> any { return s?.split(",")[0]; }
def paren_call(x: any, k: int) -> any { return (x?[k])(1); }
def store_through(x: any, k: int) { x?[k].a = 1; }
""";

test "a trailer after a null-safe subscript or method short-circuits with it" {
    js = compile_client(CHAIN_SRC);
    assert "? undefined : _jac.poly.getitem(x, k)(n))" in js , js;
    # A store does not short-circuit, like `x?.a = 1` storing to `x.a`.
    assert "_jac.poly.getitem(x, k).a = 1;" in js , js;
    if not shutil.which("node") {
        testskip("node not on PATH");
    }
    probe = """
const u = (v) => v === undefined;
let threw = false;
try { paren_call(null, 0); } catch (e) { threw = e instanceof TypeError; }
const box = [{a: 0}];
store_through(box, 0);
console.log(JSON.stringify([
    u(idx_call(null, 0, 2)), idx_call([(n) => n * 3], 0, 2),
    u(once_call(null, 0, 2)), once_call([(n) => n + 1], 0, 2), hits.length,
    u(idx_attr(null, 0)), idx_attr([{b: 4}], 0),
    u(idx_idx(null, 0, 1)), idx_idx([[1, 2]], 0, 1),
    u(idx_method(null, 0)), idx_method([{m: (v) => v + 10}], 0),
    u(idx_curry(null, 0)), idx_curry([(a) => (b) => a + b], 0),
    u(nested_call(null, 0, 0, 1)), u(nested_call([null], 0, 0, 1)),
    nested_call([[(n) => n * 5]], 0, 0, 2),
    u(strip_upper(null)), strip_upper(" ab "),
    u(split_first(null)), split_first("a,b"),
    threw, box[0].a
]));
""";
    result = run_js_module(js + "\n" + probe, timeout=10.0);
    assert result.returncode == 0 , result.stderr + "\n" + js;
    assert json.loads(result.stdout.strip())
        == [
            True,
            6,
            True,
            3,
            2,
            True,
            4,
            True,
            2,
            True,
            11,
            True,
            3,
            True,
            True,
            10,
            True,
            "AB",
            True,
            "a",
            True,
            1
        ] , result.stdout + "\n" + js;
}

glob STORE_SRC = """
glob seen: list[int] = [];
def recv(x: any) -> any { seen.append(1); return x; }
async def key(k: int) -> int { return k; }
def index_attr(x: any, k: any) { recv(x)?[k].a = 1; }
def attr_attr(x: any) { recv(x)?.b.c = 2; }
def nested(x: any, k: any, j: any) { recv(x)?[k]?[j].a = 3; }
def named_nested(x: any, k: any, j: any) { x?[k]?[j].a = 4; }
def aug_through(x: any, k: any) { recv(x)?[k].a += 5; }
def floor_through(x: any, k: any) { recv(x)?[k].a //= 2; }
async def awaited_key(x: any) { recv(x)?[await key(0)].a = 6; }
""";

test "a store through a null-safe chain binds its receiver once" {
    js = compile_client(STORE_SRC);
    if not shutil.which("node") {
        testskip("node not on PATH");
    }
    probe = """
const count = () => seen.splice(0).length;
const out = [];
const a = [{a: 0}];
index_attr(a, 0);
out.push(a[0].a, count());
const b = {b: {c: 0}};
attr_attr(b);
out.push(b.b.c, count());
const n = [[{a: 0}, {a: 0}]];
nested(n, 0, 1);
out.push(n[0][1].a, n[0][0].a, count());
const m = [[{a: 0}]];
named_nested(m, 0, 0);
out.push(m[0][0].a);
const g = [{a: 1}];
aug_through(g, 0);
out.push(g[0].a, count());
const f = [{a: 9}];
floor_through(f, 0);
out.push(f[0].a, count());
const w = [{a: 0}];
await awaited_key(w);
out.push(w[0].a, count());
console.log(JSON.stringify(out));
""";
    result = run_js_module(js + "\n" + probe, timeout=10.0);
    assert result.returncode == 0 , result.stderr + "\n" + js;
    assert json.loads(result.stdout.strip())
        == [1, 1, 2, 1, 3, 0, 1, 4, 6, 1, 4, 1, 6, 1] , result.stdout + "\n" + js;
}

glob YIELD_KEY_SRC = """
glob seen: list[int] = [];
def recv(x: any) -> any { seen.append(1); return x; }
def add(a: any, b: any) -> any { return a + b; }
async def tick(v: int) -> int { return v; }
def key_gen(x: any) -> any { r = recv(x)?[(yield "k")]; yield r; }
async def key_agen(x: any) -> any {
    r = recv(x)?[add((yield "k"), await tick(1))];
    yield r;
}
obj Shelf {
    has items: list[int] = [];
    def pick(x: any) -> any { r = recv(x)?[(yield self.items[0])]; yield r; }
}
def plain(x: any, k: any) -> any { return recv(x)?[k]; }
""";

test "a null-safe read whose key yields binds its receiver once inside the generator" {
    js = compile_client(YIELD_KEY_SRC);
    assert "(__jac_opt => ((__jac_opt == null) ? undefined : _jac.poly.getitem(__jac_opt, k)))(recv(x))"
        in js , js;
    assert "yield* (async function* (__jac_opt)" in js , js;
    if not shutil.which("node") {
        testskip("node not on PATH");
    }
    probe = """
const count = () => seen.splice(0).length;
const out = [];
const g = key_gen([5, 6]);
out.push(g.next().value, count(), g.next(1).value, count());
const n = key_gen(null);
out.push(n.next().value ?? "none", count());
const ag = key_agen([5, 6, 7]);
out.push((await ag.next()).value, count(), (await ag.next(1)).value, count());
const p = new Shelf({items: [1]}).pick([3, 4]);
out.push(p.next().value, p.next(0).value, count());
out.push(plain([8], 0), count());
console.log(JSON.stringify(out));
""";
    result = run_js_module(js + "\n" + probe, timeout=10.0);
    assert result.returncode == 0 , result.stderr + "\n" + js;
    assert json.loads(result.stdout.strip())
        == ["k", 1, 6, 0, "none", 1, "k", 1, 7, 0, 1, 3, 1, 8, 1] , result.stdout
        + "\n"
        + js;
}
