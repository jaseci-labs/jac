"""Operators and keyword calls keep their meaning in emitted JavaScript."""

import json;
import shutil;
import from jaclang.compiler.passes.execution { run_walker }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
import from jaclang.compiler.driver.pass_driver { run_pass }
import from tests.compiler.backends.es.codegen_helpers { run_js_module }

def compile_client(source: str) -> str {
    program = JacProgram();
    module = program.compile(
        "operator_call_lowering.jac",
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

def run_probe(js: str, probe: str) -> list[object] {
    result = run_js_module(js + "\n" + probe, timeout=10.0);
    assert result.returncode == 0 , result.stderr + "\n" + js;
    return json.loads(result.stdout.strip());
}

glob UNTYPED_OPS_SRC = """
def power(a: any) -> any { return a ** 2; }
def power_of(a: any, b: any) -> any { return a ** b; }
def neg_power(a: any, b: any) -> any { return (-a) ** b; }
def floor_div(a: any, b: any) -> any { return a // b; }
def floor_div_in_place(a: any, b: any) -> any { a //= b; return a; }
def int_floor_div_in_place(a: int, b: int) -> int { a //= b; return a; }
""";

test "power and floor division on untyped operands keep their operator" {
    js = compile_client(UNTYPED_OPS_SRC);
    assert "return (a ** 2);" in js , js;
    assert "(a + 2)" not in js , js;
    assert "return ((-a) ** b);" in js , js;
    assert "a = Math.floor((a / b));" in js , js;
    if not shutil.which("node") {
        testskip("node not on PATH");
    }
    probe = """
console.log(JSON.stringify([
    power(3), power_of(2, 10), neg_power(2, 3),
    floor_div(7, 2), floor_div(-7, 2),
    floor_div_in_place(9, 2), int_floor_div_in_place(-9, 2)
]));
""";
    assert run_probe(js, probe) == [9, 1024, -8, 3, -4, 4, -5] , js;
}

glob AWAITED_POWER_SRC = """
async def num() -> int { return 3; }
async def ratio() -> float { return 2.0; }
async def int_base(n: int) -> any { return (await num()) ** n; }
async def float_base(n: float) -> any { return (await ratio()) ** n; }
async def awaited_exponent(n: int) -> any { return n ** (await num()); }
def negated_base(b: int, n: int) -> any { return (-b) ** n; }
""";

test "an awaited or negated base of a power stays parenthesized" {
    js = compile_client(AWAITED_POWER_SRC);
    assert "((await num()) ** n)" in js , js;
    assert "((await ratio()) ** n)" in js , js;
    assert "await num() **" not in js , js;
    if not shutil.which("node") {
        testskip("node not on PATH");
    }
    probe = """
console.log(JSON.stringify([
    await int_base(2), await float_base(3.0), await awaited_exponent(2),
    negated_base(2, 3)
]));
""";
    assert run_probe(js, probe) == [9, 8, 8, -8] , js;
}

glob UNRESOLVED_KWARGS_SRC = """
glob made: list[int] = [];
def opts() -> dict[str, int] { made.append(1); return {"a": 1}; }
def more() -> dict[str, int] { return {"b": 2}; }
def spread_kw(x: any, kw: dict[str, int]) -> any { return x.f(1, **kw); }
def named_kw(x: any) -> any { return x.f(1, 2, b=3); }
def star_and_kw(x: any, xs: list[int]) -> any { return x.f(*xs, c=1); }
def two_spreads(x: any) -> any { return x.f(1, **opts(), **more()); }
def only_kw(x: any) -> any { return x.f(c=1); }
""";

test "a call to an unresolved target keeps its positional arguments beside keywords" {
    js = compile_client(UNRESOLVED_KWARGS_SRC);
    assert "x.f(1, {...kw})" in js , js;
    assert "x.f(1, 2, {b: 3})" in js , js;
    if not shutil.which("node") {
        testskip("node not on PATH");
    }
    probe = """
const rec = {f: (...args) => args};
console.log(JSON.stringify([
    spread_kw(rec, {b: 2}), named_kw(rec), star_and_kw(rec, [4, 5]),
    two_spreads(rec), made.length, only_kw(rec)
]));
""";
    assert run_probe(js, probe)
        == [
            [1, {"b": 2}],
            [1, 2, {"b": 3}],
            [4, 5, {"c": 1}],
            [1, {"a": 1, "b": 2}],
            1,
            [{"c": 1}]
        ] , js;
}

glob AUG_ONCE_SRC = """
glob seen: list[str] = [];
obj Cell { has v: i32 = 0; }
def make_cell(v: i32) -> Cell { return Cell(v=v); }
def idx(i: int) -> int { seen.append("i"); return i; }
def get(x: any) -> any { seen.append("r"); return x; }
def cell(c: Cell) -> Cell { seen.append("c"); return c; }
async def key(i: int) -> int { seen.append("k"); return i; }
def floor_index(a: any) -> any { get(a)[idx(1)] //= 2; return a; }
def floor_attr(a: any) -> any { get(a).v //= 3; return a; }
def floor_typed(a: list[int]) -> any { a[idx(0)] //= 2; return a; }
def fixed_attr(c: Cell) -> Cell { cell(c).v += 5; return c; }
def fixed_floor(c: Cell) -> Cell { cell(c).v //= 2; return c; }
def fixed_index(a: list[i32]) -> any { a[idx(1)] -= 1; return a; }
async def floor_awaited(a: any) -> any { get(a)[await key(0)] //= 4; return a; }
def plain(a: list[int], b: int) -> any { a[0] //= b; return a; }
""";

test "an augmented store lowered through a helper evaluates its receiver and key once" {
    js = compile_client(AUG_ONCE_SRC);
    assert "a[0] = Math.floor((a[0] / b));" in js , js;
    if not shutil.which("node") {
        testskip("node not on PATH");
    }
    probe = """
const log = () => seen.splice(0).join("");
const out = [];
out.push(floor_index([0, 9, 4]), log());
out.push(floor_attr({v: 10}).v, log());
out.push(floor_typed([-7, 1]), log());
out.push(fixed_attr(make_cell(1)).v, log());
out.push(fixed_floor(make_cell(-9)).v, log());
out.push(fixed_index([3, 3]), log());
out.push(await floor_awaited([9, 1]), log());
console.log(JSON.stringify(out));
""";
    assert run_probe(js, probe)
        == [
            [0, 4, 4],
            "ri",
            3,
            "r",
            [-4, 1],
            "i",
            6,
            "c",
            -5,
            "c",
            [3, 2],
            "i",
            [2, 1],
            "rk"
        ] , js;
}

glob YIELD_ONCE_SRC = """
glob seen: list[str] = [];
def idx(i: int) -> int { seen.append("i"); return i; }
def opts() -> any { seen.append("o"); return {"b": 5}; }
def mk(a: any, b: any = 0) -> any { return [a, b]; }
def add(a: any, b: any) -> any { return a + b; }
async def tick(v: int) -> int { return v; }
def floor_gen(a: any) -> any { a[idx(1)] //= yield 2; yield a; }
def kw_gen() -> any { r = mk(**opts(), a=(yield "v")); yield r; }
async def floor_agen(a: any) -> any {
    a[idx(1)] //= add((yield 2), await tick(1));
    yield a;
}
obj Acc {
    has items: list[int] = [];
    def shrink() -> any {
        self.items[idx(0)] //= yield self.items[0];
        yield self.items;
    }
}
def plain_floor(a: any) -> any { a[idx(0)] //= 2; return a; }
def plain_kw() -> any { return mk(**opts(), a=1); }
""";

test "a store or keyword call whose value yields binds its receiver once inside the generator" {
    js = compile_client(YIELD_ONCE_SRC);
    assert "(__jac_key => a[__jac_key] = Math.floor((a[__jac_key] / 2)))(idx(0))"
        in js , js;
    assert "(__jac_kwargs => mk(1, __jac_kwargs[\"b\"]))(opts())" in js , js;
    assert "yield* (async function* (__jac_key)" in js , js;
    if not shutil.which("node") {
        testskip("node not on PATH");
    }
    probe = """
const log = () => seen.splice(0).join("");
const out = [];
const g = floor_gen([0, 9]);
out.push(g.next().value, log(), g.next(4).value, log());
const k = kw_gen();
out.push(k.next().value, log(), k.next(7).value, log());
const ag = floor_agen([0, 9]);
out.push((await ag.next()).value, log(), (await ag.next(2)).value, log());
const s = new Acc({items: [9, 1]}).shrink();
out.push(s.next().value, s.next(4).value, log());
out.push(plain_floor([5]), plain_kw(), log());
console.log(JSON.stringify(out));
""";
    assert run_probe(js, probe)
        == [
            2,
            "i",
            [0, 2],
            "",
            "v",
            "o",
            [7, 5],
            "",
            2,
            "i",
            [0, 3],
            "",
            9,
            [2, 1],
            "i",
            [2],
            [1, 5],
            "io"
        ] , js;
}
