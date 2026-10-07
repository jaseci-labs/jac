# ══════════════════════════════════════════════════════════════════════════════
# 5.  Smoke test
# ══════════════════════════════════════════════════════════════════════════════

import from engine.src.parser.parser { parse }
import from engine.src.parser.ast {
    ASTNode,
    make_program,
    make_if,
    make_block,
    make_literal,
    ZERO_RANGE,
    ASTNodeType
}
import from engine.src.bytecode.op { Opcode, CompiledFunction }
import from engine.src.bytecode.compiler { make_compiler }
import from engine.src.bytecode.optimizer { bcopt_gate_set }
import from engine.src.ffi.libc { fflush, _exit }

with entry {
    ok: int = 0;
    fail: int = 0;

    # These checks pin the compiler's own emission. The bytecode optimizer
    # (megaops, copy-prop, filler compaction) rewrites it afterwards and is
    # covered by execution tests; JS_BCOPT=0 / bcopt_gate_set(False) is the
    # engine's switch for exactly this view.
    bcopt_gate_set(False);

    # A Script's value is its completion value (ES §16.1.6): local 0 of <main>
    # is the completion slot, seeded with undefined, updated by each expression
    # statement, and returned at the end.

    # 1: empty program → returns the (undefined) completion slot
    c1 = make_compiler();
    fn1: CompiledFunction = c1.compile_program(parse(""));
    n1: int = len(fn1.code);
    if n1 == 4
        and fn1.code[0].opcode == Opcode.LOAD_UNDEFINED
        and fn1.code[1].opcode == Opcode.STORE_LOCAL
        and fn1.code[1].arg == 0
        and fn1.code[2].opcode == Opcode.LOAD_LOCAL
        and fn1.code[2].arg == 0
        and fn1.code[3].opcode == Opcode.RETURN {
        ok += 1;
        print("OK  empty program → return completion slot (undefined)");
    } else {
        fail += 1;
        print("FAIL empty program code len=", n1);
    }

    # 2: numeric literal → value stored into the completion slot
    c2 = make_compiler();
    fn2: CompiledFunction = c2.compile_program(parse("42;"));
    if len(fn2.code) == 6
        and fn2.code[2].opcode == Opcode.LOAD_CONST
        and fn2.code[3].opcode == Opcode.STORE_LOCAL
        and fn2.code[3].arg == 0
        and fn2.code[5].opcode == Opcode.RETURN {
        ok += 1;
        print("OK  numeric literal → LOAD_CONST STORE_LOCAL 0 (completion)");
    } else {
        fail += 1;
        print("FAIL numeric literal code len=", len(fn2.code));
    }
    if fn2.constants.get(0) == "n:42" {
        ok += 1;
        print("OK  constant pool[0] = n:42");
    } else {
        fail += 1;
        print("FAIL constant pool[0] =", fn2.constants.get(0));
    }

    # 3: top-level var is a global binding (ES §16.1.7), not a <main> local
    c4 = make_compiler();
    fn4: CompiledFunction = c4.compile_program(parse("var x = 1;"));
    has_smg4: bool = False;
    local_store4: bool = False;
    for instr in fn4.code {
        if instr.opcode == Opcode.STORE_MODULE_GLOBAL {
            has_smg4 = True;
        }
        if instr.opcode == Opcode.STORE_LOCAL and instr.arg != 0 {
            local_store4 = True;
        }
    }
    if has_smg4 and not local_store4 and fn4.num_locals == 1 {
        ok += 1;
        print("OK  top-level var x = 1 → STORE_MODULE_GLOBAL (no local)");
    } else {
        fail += 1;
        print(
            "FAIL top-level var global smg=", has_smg4, "num_locals=", fn4.num_locals
        );
    }

    # 3b: function-scoped var → LOAD_CONST STORE_LOCAL 0
    # Function-scoped cases set source_text like the engine does: without it the
    # compiler cannot prove a body never names `arguments` and reserves slot 0 for it.
    c5 = make_compiler();
    c5.source_text = "function f() { var x = 1; return x; }";
    c5.compile_program(parse(c5.source_text));
    fn5: CompiledFunction = c5.all_fns[0];
    if fn5.code[0].opcode == Opcode.LOAD_CONST
        and fn5.code[1].opcode == Opcode.STORE_LOCAL
        and fn5.code[1].arg == 0 {
        ok += 1;
        print("OK  var x = 1 → LOAD_CONST STORE_LOCAL 0");
    } else {
        fail += 1;
        print("FAIL var x=1");
    }
    if fn5.num_locals == 1 {
        ok += 1;
        print("OK  var x: num_locals = 1");
    } else {
        fail += 1;
        print("FAIL var x num_locals =", fn5.num_locals);
    }

    # 4: two function-scoped declarations
    c6 = make_compiler();
    c6.source_text = "function f() { var a = 1; var b = 2; }";
    c6.compile_program(parse(c6.source_text));
    fn6: CompiledFunction = c6.all_fns[0];
    if fn6.num_locals == 2 {
        ok += 1;
        print("OK  two vars: num_locals = 2");
    } else {
        fail += 1;
        print("FAIL two vars num_locals =", fn6.num_locals);
    }

    # 5: binary expression
    c7 = make_compiler();
    fn7: CompiledFunction = c7.compile_program(parse("1 + 2;"));
    has_add: bool = False;
    for instr in fn7.code {
        if instr.opcode == Opcode.ADD {
            has_add = True;
        }
    }
    if has_add {
        ok += 1;
        print("OK  1+2 → ADD");
    } else {
        fail += 1;
        print("FAIL 1+2 no ADD");
    }

    # 6: global identifier
    c8 = make_compiler();
    fn8: CompiledFunction = c8.compile_program(parse("foo;"));
    # code[0..1] seed the completion slot; the expression starts at 2.
    if fn8.code[2].opcode == Opcode.LOAD_GLOBAL {
        ok += 1;
        print("OK  undeclared → LOAD_GLOBAL");
    } else {
        fail += 1;
        print("FAIL undeclared op", fn8.code[2].opcode);
    }

    # 7: local identifier load (function-scoped var)
    c9 = make_compiler();
    c9.source_text = "function f() { var x = 1; return x; }";
    c9.compile_program(parse(c9.source_text));
    fn9: CompiledFunction = c9.all_fns[0];
    found_ll: bool = False;
    for instr in fn9.code {
        if instr.opcode == Opcode.LOAD_LOCAL and instr.arg == 0 {
            found_ll = True;
        }
    }
    if found_ll {
        ok += 1;
        print("OK  declared var → LOAD_LOCAL 0");
    } else {
        fail += 1;
        print("FAIL declared var");
    }

    # 7b: a top-level var is read back through the global object
    c9b = make_compiler();
    fn9b: CompiledFunction = c9b.compile_program(parse("var x = 1; x;"));
    found_lg: bool = False;
    for instr in fn9b.code {
        if instr.opcode == Opcode.LOAD_GLOBAL {
            found_lg = True;
        }
    }
    if found_lg {
        ok += 1;
        print("OK  top-level var read → LOAD_GLOBAL");
    } else {
        fail += 1;
        print("FAIL top-level var read");
    }

    # 8: if-else
    c10 = make_compiler();
    fn10: CompiledFunction = c10.compile_program(parse("if (true) { 1; } else { 2; }"));
    has_jf: bool = False;
    has_jmp: bool = False;
    for instr in fn10.code {
        if instr.opcode == Opcode.JUMP_IF_FALSE {
            has_jf = True;
        }
        if instr.opcode == Opcode.JUMP {
            has_jmp = True;
        }
    }
    if has_jf and has_jmp {
        ok += 1;
        print("OK  if-else → JUMP_IF_FALSE + JUMP");
    } else {
        fail += 1;
        print("FAIL if-else");
    }

    # 9: while loop back-edge
    c11 = make_compiler();
    c11.source_text = "function f() { while (true) { 1; } }";
    c11.compile_program(parse(c11.source_text));
    fn11: CompiledFunction = c11.all_fns[0];
    # The loop head is the condition at 0; the back-edge jumps to it.
    has_back: bool = False;
    for instr in fn11.code {
        if instr.opcode == Opcode.JUMP and instr.arg == 0 {
            has_back = True;
        }
    }
    if has_back and fn11.code[0].opcode == Opcode.LOAD_TRUE {
        ok += 1;
        print("OK  while → back-edge JUMP to loop head");
    } else {
        fail += 1;
        print("FAIL while no back-edge");
    }

    # 10: function declaration → MAKE_FUNCTION + all_fns
    c12 = make_compiler();
    fn12: CompiledFunction = c12.compile_program(
        parse("function add(a, b) { return a + b; }")
    );
    has_make_fn: bool = False;
    for instr in fn12.code {
        if instr.opcode == Opcode.MAKE_FUNCTION {
            has_make_fn = True;
        }
    }
    if has_make_fn {
        ok += 1;
        print("OK  function decl → MAKE_FUNCTION");
    } else {
        fail += 1;
        print("FAIL function decl");
    }
    if len(c12.all_fns) == 1 {
        ok += 1;
        print("OK  1 inner function");
        inner12: CompiledFunction = c12.all_fns[0];
        if len(inner12.params) == 2 {
            ok += 1;
            print("OK  inner fn 2 params");
        } else {
            fail += 1;
            print("FAIL inner fn params", len(inner12.params));
        }
    } else {
        fail += 1;
        print("FAIL all_fns", len(c12.all_fns));
    }

    # 11: call
    c13 = make_compiler();
    fn13: CompiledFunction = c13.compile_program(parse("foo(1, 2);"));
    has_call: bool = False;
    for instr in fn13.code {
        if instr.opcode == Opcode.CALL and instr.arg == 2 {
            has_call = True;
        }
    }
    if has_call {
        ok += 1;
        print("OK  foo(1,2) → CALL 2");
    } else {
        fail += 1;
        print("FAIL call");
    }

    # 12: method call
    c14 = make_compiler();
    fn14: CompiledFunction = c14.compile_program(parse("obj.method(1);"));
    has_cm: bool = False;
    for instr in fn14.code {
        if instr.opcode == Opcode.CALL_METHOD {
            has_cm = True;
        }
    }
    if has_cm {
        ok += 1;
        print("OK  obj.method(1) → CALL_METHOD");
    } else {
        fail += 1;
        print("FAIL method call");
    }

    # 13: member / computed member
    c15 = make_compiler();
    fn15: CompiledFunction = c15.compile_program(parse("a.b;"));
    has_gp: bool = False;
    for instr in fn15.code {
        if instr.opcode == Opcode.GET_PROP {
            has_gp = True;
        }
    }
    if has_gp {
        ok += 1;
        print("OK  a.b → GET_PROP");
    } else {
        fail += 1;
        print("FAIL GET_PROP");
    }

    c16 = make_compiler();
    fn16: CompiledFunction = c16.compile_program(parse("a[0];"));
    has_gi: bool = False;
    for instr in fn16.code {
        if instr.opcode == Opcode.GET_INDEX {
            has_gi = True;
        }
    }
    if has_gi {
        ok += 1;
        print("OK  a[0] → GET_INDEX");
    } else {
        fail += 1;
        print("FAIL GET_INDEX");
    }

    # 14: new
    c17 = make_compiler();
    fn17: CompiledFunction = c17.compile_program(parse("new Foo(1, 2);"));
    has_new: bool = False;
    for instr in fn17.code {
        if instr.opcode == Opcode.NEW and instr.arg == 2 {
            has_new = True;
        }
    }
    if has_new {
        ok += 1;
        print("OK  new Foo(1,2) → NEW 2");
    } else {
        fail += 1;
        print("FAIL new");
    }

    # 15: array / object literals
    c18 = make_compiler();
    fn18: CompiledFunction = c18.compile_program(parse("[1, 2, 3];"));
    has_arr: bool = False;
    for instr in fn18.code {
        if instr.opcode == Opcode.NEW_ARRAY and instr.arg == 3 {
            has_arr = True;
        }
    }
    if has_arr {
        ok += 1;
        print("OK  [1,2,3] → NEW_ARRAY 3");
    } else {
        fail += 1;
        print("FAIL NEW_ARRAY");
    }

    c19 = make_compiler();
    fn19: CompiledFunction = c19.compile_program(parse("({a: 1});"));
    has_obj: bool = False;
    has_set: bool = False;
    for instr in fn19.code {
        if instr.opcode == Opcode.NEW_OBJECT {
            has_obj = True;
        }
        if instr.opcode == Opcode.SET_PROP {
            has_set = True;
        }
    }
    if has_obj and has_set {
        ok += 1;
        print("OK  ({a:1}) → NEW_OBJECT + SET_PROP");
    } else {
        fail += 1;
        print("FAIL object literal");
    }

    # 16: logical &&
    c20 = make_compiler();
    fn20: CompiledFunction = c20.compile_program(parse("a && b;"));
    has_jf20: bool = False;
    for instr in fn20.code {
        if instr.opcode == Opcode.JUMP_IF_FALSE {
            has_jf20 = True;
        }
    }
    if has_jf20 {
        ok += 1;
        print("OK  a&&b → JUMP_IF_FALSE");
    } else {
        fail += 1;
        print("FAIL &&");
    }

    # 17: return inside function
    c21 = make_compiler();
    c21.compile_program(parse("function f() { return 42; }"));
    has_ret: bool = False;
    for instr in c21.all_fns[0].code {
        if instr.opcode == Opcode.RETURN {
            has_ret = True;
        }
    }
    if has_ret {
        ok += 1;
        print("OK  return 42 → RETURN");
    } else {
        fail += 1;
        print("FAIL return");
    }

    # 18: arrow function
    c22 = make_compiler();
    fn22: CompiledFunction = c22.compile_program(parse("const f = (x) => x * 2;"));
    has_arrow: bool = False;
    for instr in fn22.code {
        if instr.opcode == Opcode.MAKE_ARROW {
            has_arrow = True;
        }
    }
    if has_arrow {
        ok += 1;
        print("OK  arrow → MAKE_ARROW");
    } else {
        fail += 1;
        print("FAIL arrow");
    }

    # 19: throw
    c23 = make_compiler();
    fn23: CompiledFunction = c23.compile_program(parse("throw new Error(\"x\");"));
    has_throw: bool = False;
    for instr in fn23.code {
        if instr.opcode == Opcode.THROW {
            has_throw = True;
        }
    }
    if has_throw {
        ok += 1;
        print("OK  throw → THROW");
    } else {
        fail += 1;
        print("FAIL throw");
    }

    # 20: unary
    c24 = make_compiler();
    fn24: CompiledFunction = c24.compile_program(parse("!x;"));
    has_not: bool = False;
    for instr in fn24.code {
        if instr.opcode == Opcode.NOT {
            has_not = True;
        }
    }
    if has_not {
        ok += 1;
        print("OK  !x → NOT");
    } else {
        fail += 1;
        print("FAIL NOT");
    }

    # 21: typeof
    c25 = make_compiler();
    fn25: CompiledFunction = c25.compile_program(parse("typeof x;"));
    has_to: bool = False;
    for instr in fn25.code {
        if instr.opcode == Opcode.TYPEOF {
            has_to = True;
        }
    }
    if has_to {
        ok += 1;
        print("OK  typeof → TYPEOF");
    } else {
        fail += 1;
        print("FAIL TYPEOF");
    }

    # 22: ternary
    c26 = make_compiler();
    fn26: CompiledFunction = c26.compile_program(parse("a ? 1 : 2;"));
    jf26: bool = False;
    jmp26: bool = False;
    for instr in fn26.code {
        if instr.opcode == Opcode.JUMP_IF_FALSE {
            jf26 = True;
        }
        if instr.opcode == Opcode.JUMP {
            jmp26 = True;
        }
    }
    if jf26 and jmp26 {
        ok += 1;
        print("OK  ternary");
    } else {
        fail += 1;
        print("FAIL ternary");
    }

    # 23: assignment → STORE_LOCAL
    c27 = make_compiler();
    fn27: CompiledFunction = c27.compile_program(parse("var x = 0; x = 5;"));
    has_sl: bool = False;
    for instr in fn27.code {
        if instr.opcode == Opcode.STORE_LOCAL {
            has_sl = True;
        }
    }
    if has_sl {
        ok += 1;
        print("OK  x=5 → STORE_LOCAL");
    } else {
        fail += 1;
        print("FAIL STORE_LOCAL");
    }

    # 24: try-catch
    c28 = make_compiler();
    fn28: CompiledFunction = c28.compile_program(
        parse("try { foo(); } catch (e) { bar(); }")
    );
    has_pc: bool = False;
    has_poc: bool = False;
    for instr in fn28.code {
        if instr.opcode == Opcode.PUSH_CATCH {
            has_pc = True;
        }
        if instr.opcode == Opcode.POP_CATCH {
            has_poc = True;
        }
    }
    if has_pc and has_poc {
        ok += 1;
        print("OK  try-catch → PUSH_CATCH + POP_CATCH");
    } else {
        fail += 1;
        print("FAIL try-catch");
    }

    # 25: for loop
    c29 = make_compiler();
    fn29: CompiledFunction = c29.compile_program(
        parse("for (var i = 0; i < 10; i++) {}")
    );
    has_jf29: bool = False;
    for instr in fn29.code {
        if instr.opcode == Opcode.JUMP_IF_FALSE {
            has_jf29 = True;
        }
    }
    if has_jf29 {
        ok += 1;
        print("OK  for loop → JUMP_IF_FALSE");
    } else {
        fail += 1;
        print("FAIL for loop");
    }

    # 26: function params count
    c30 = make_compiler();
    c30.compile_program(parse("function f(a, b, c) { return a; }"));
    if len(c30.all_fns) == 1 and len(c30.all_fns[0].params) == 3 {
        ok += 1;
        print("OK  function(a,b,c) params=3");
    } else {
        fail += 1;
        print("FAIL params", len(c30.all_fns[0].params));
    }

    # 27: top-level function decl → CreateGlobalFunctionBinding (ES §16.1.7)
    c31 = make_compiler();
    fn31: CompiledFunction = c31.compile_program(parse("function greet() {}"));
    has_sg: bool = False;
    for instr in fn31.code {
        if instr.opcode == Opcode.CREATE_GLOBAL_FN_BINDING {
            has_sg = True;
        }
    }
    if has_sg {
        ok += 1;
        print("OK  top-level function decl → CREATE_GLOBAL_FN_BINDING");
    } else {
        fail += 1;
        print("FAIL function decl global binding");
    }

    # 28: var hoisting — var inside a block declares at the function boundary
    c32 = make_compiler();
    c32.source_text = "function f() { { var x = 1; } return x; }";
    c32.compile_program(parse(c32.source_text));
    fn32: CompiledFunction = c32.all_fns[0];
    found_local: bool = False;
    for instr in fn32.code {
        if instr.opcode == Opcode.LOAD_LOCAL and instr.arg == 0 {
            found_local = True;
        }
    }
    if found_local and fn32.num_locals == 1 {
        ok += 1;
        print("OK  var hoisting → LOAD_LOCAL 0 after block");
    } else {
        fail += 1;
        print("FAIL var hoisting");
    }

    # 29: TODO template literal (quasis + expressions interleaved)
    # (skipped until ast template node shape is verified)

    # 30: logical ||
    c33 = make_compiler();
    fn33: CompiledFunction = c33.compile_program(parse("a || b;"));
    has_jt33: bool = False;
    for instr in fn33.code {
        if instr.opcode == Opcode.JUMP_IF_TRUE {
            has_jt33 = True;
        }
    }
    if has_jt33 {
        ok += 1;
        print("OK  a||b → JUMP_IF_TRUE");
    } else {
        fail += 1;
        print("FAIL ||");
    }

    # 31: nullish coalescing ?? emits JUMP_IF_NULL and JUMP_IF_UNDEFINED
    c34 = make_compiler();
    fn34: CompiledFunction = c34.compile_program(parse("a ?? b;"));
    has_jn34: bool = False;
    has_ju34: bool = False;
    for instr in fn34.code {
        if instr.opcode == Opcode.JUMP_IF_NULL {
            has_jn34 = True;
        }
        if instr.opcode == Opcode.JUMP_IF_UNDEFINED {
            has_ju34 = True;
        }
    }
    if has_jn34 and has_ju34 {
        ok += 1;
        print("OK  a??b → JUMP_IF_NULL + JUMP_IF_UNDEFINED");
    } else {
        fail += 1;
        print("FAIL ?? jn=", has_jn34, "ju=", has_ju34);
    }

    # 32: do-while
    c35 = make_compiler();
    fn35: CompiledFunction = c35.compile_program(parse("do { 1; } while (true);"));
    has_jt35: bool = False;
    for instr in fn35.code {
        if instr.opcode == Opcode.JUMP_IF_TRUE {
            has_jt35 = True;
        }
    }
    if has_jt35 {
        ok += 1;
        print("OK  do-while → JUMP_IF_TRUE back-edge");
    } else {
        fail += 1;
        print("FAIL do-while");
    }

    # 33: compound += on a local → ADD + STORE_LOCAL, never a global store
    c36 = make_compiler();
    c36.source_text = "function f() { var x = 0; x += 1; }";
    c36.compile_program(parse(c36.source_text));
    fn36: CompiledFunction = c36.all_fns[0];
    has_add36: bool = False;
    has_sl36: bool = False;
    has_sg36: bool = False;
    for instr in fn36.code {
        if instr.opcode == Opcode.ADD {
            has_add36 = True;
        }
        if instr.opcode == Opcode.STORE_LOCAL and instr.arg == 0 {
            has_sl36 = True;
        }
        if instr.opcode == Opcode.STORE_GLOBAL
            or instr.opcode == Opcode.STORE_MODULE_GLOBAL {
            has_sg36 = True;
        }
    }
    if has_add36 and has_sl36 and not has_sg36 {
        ok += 1;
        print("OK  x+=1 → ADD + STORE_LOCAL");
    } else {
        fail += 1;
        print("FAIL +=");
    }

    # ++/-- are emitted as `x - (-1)` / `x - 1`: SUB applies ToNumeric to x,
    # where ADD would string-concatenate (`"5"++` must yield 6, not "51").

    # 34: prefix ++x → LOAD_LOCAL; LOAD_CONST n:-1; SUB; DUP; STORE_LOCAL
    c37 = make_compiler();
    c37.source_text = "function f() { var x = 0; ++x; }";
    c37.compile_program(parse(c37.source_text));
    fn37: CompiledFunction = c37.all_fns[0];
    pre_ok: bool = False;
    pi37: int = 0;
    while pi37 + 3 < len(fn37.code) {
        if fn37.code[pi37].opcode == Opcode.LOAD_CONST
            and fn37.constants.get(fn37.code[pi37].arg) == "n:-1"
            and fn37.code[pi37 + 1].opcode == Opcode.SUB
            and fn37.code[pi37 + 2].opcode == Opcode.DUP
            and fn37.code[pi37 + 3].opcode == Opcode.STORE_LOCAL
            and fn37.code[pi37 + 3].arg == 0 {
            pre_ok = True;
        }
        pi37 = pi37 + 1;
    }
    if pre_ok {
        ok += 1;
        print("OK  ++x → SUB n:-1, DUP, STORE_LOCAL");
    } else {
        fail += 1;
        print("FAIL prefix ++");
    }

    # 35: postfix x++ → ToNumeric(x) (SUB n:0), DUP keeps the old value as the
    # result, then SUB n:-1 and STORE_LOCAL write the incremented value.
    c38 = make_compiler();
    c38.source_text = "function f() { var x = 0; x++; }";
    c38.compile_program(parse(c38.source_text));
    fn38: CompiledFunction = c38.all_fns[0];
    post_ok: bool = False;
    pi38: int = 0;
    while pi38 + 5 < len(fn38.code) {
        if fn38.code[pi38].opcode == Opcode.LOAD_CONST
            and fn38.constants.get(fn38.code[pi38].arg) == "n:0"
            and fn38.code[pi38 + 1].opcode == Opcode.SUB
            and fn38.code[pi38 + 2].opcode == Opcode.DUP
            and fn38.code[pi38 + 3].opcode == Opcode.LOAD_CONST
            and fn38.constants.get(fn38.code[pi38 + 3].arg) == "n:-1"
            and fn38.code[pi38 + 4].opcode == Opcode.SUB
            and fn38.code[pi38 + 5].opcode == Opcode.STORE_LOCAL
            and fn38.code[pi38 + 5].arg == 0 {
            post_ok = True;
        }
        pi38 = pi38 + 1;
    }
    if post_ok {
        ok += 1;
        print("OK  x++ → SUB n:0, DUP, SUB n:-1, STORE_LOCAL");
    } else {
        fail += 1;
        print("FAIL postfix ++");
    }

    # 36: switch → STRICT_EQ + JUMP_IF_FALSE per case
    c39 = make_compiler();
    fn39: CompiledFunction = c39.compile_program(
        parse("switch (x) { case 1: 10; break; case 2: 20; break; }")
    );
    eq_count: int = 0;
    jf_count: int = 0;
    for instr in fn39.code {
        if instr.opcode == Opcode.STRICT_EQ {
            eq_count += 1;
        }
        if instr.opcode == Opcode.JUMP_IF_FALSE {
            jf_count += 1;
        }
    }
    if eq_count == 2 and jf_count == 2 {
        ok += 1;
        print("OK  switch 2 cases → 2 STRICT_EQ + 2 JUMP_IF_FALSE");
    } else {
        fail += 1;
        print("FAIL switch eq=", eq_count, "jf=", jf_count);
    }

    # 37: labeled break exits outer loop
    c40 = make_compiler();
    fn40: CompiledFunction = c40.compile_program(
        parse("outer: while (true) { while (true) { break outer; } }")
    );
    has_jmp40: bool = False;
    for instr in fn40.code {
        if instr.opcode == Opcode.JUMP {
            has_jmp40 = True;
        }
    }
    if has_jmp40 {
        ok += 1;
        print("OK  labeled break → JUMP");
    } else {
        fail += 1;
        print("FAIL labeled break");
    }

    # 38: LOAD_GLOBAL name is interned — constant pool entry matches name
    c41 = make_compiler();
    fn41: CompiledFunction = c41.compile_program(parse("globalVar;"));
    lg_arg: int = -1;
    for instr in fn41.code {
        if instr.opcode == Opcode.LOAD_GLOBAL {
            lg_arg = instr.arg;
        }
    }
    if lg_arg >= 0 and fn41.constants.get(lg_arg) == "globalVar" {
        ok += 1;
        print("OK  LOAD_GLOBAL arg points to name in const pool");
    } else {
        fail += 1;
        print("FAIL LOAD_GLOBAL name interning arg=", lg_arg);
    }

    # ── closure / free-variable tests ─────────────────────────────────────

    # 39: simple read capture — inner fn reads outer local → LOAD_FREE
    c42 = make_compiler();
    fn42: CompiledFunction = c42.compile_program(
        parse("function outer() { var x = 1; function inner() { return x; } }")
    );
    # inner fn is in all_fns
    inner42: CompiledFunction = c42.all_fns[0];
    has_lf42: bool = False;
    for instr in inner42.code {
        if instr.opcode == Opcode.LOAD_FREE {
            has_lf42 = True;
        }
    }
    if has_lf42 and len(inner42.free_vars) == 1 and inner42.free_vars[0] == "x" {
        ok += 1;
        print("OK  simple read capture → LOAD_FREE 0, free_vars[0]=x");
    } else {
        fail += 1;
        print("FAIL simple read capture lf=", has_lf42, "fv=", inner42.free_vars);
    }

    # 40: write capture — inner fn assigns outer local → STORE_FREE
    c43 = make_compiler();
    fn43: CompiledFunction = c43.compile_program(
        parse("function outer() { var n = 0; function inner() { n = n + 1; } }")
    );
    inner43: CompiledFunction = c43.all_fns[0];
    has_sf43: bool = False;
    has_lf43: bool = False;
    for instr in inner43.code {
        if instr.opcode == Opcode.STORE_FREE {
            has_sf43 = True;
        }
        if instr.opcode == Opcode.LOAD_FREE {
            has_lf43 = True;
        }
    }
    if has_sf43 and has_lf43 and len(inner43.free_vars) == 1 {
        ok += 1;
        print("OK  write capture → STORE_FREE + LOAD_FREE");
    } else {
        fail += 1;
        print("FAIL write capture sf=", has_sf43, "lf=", has_lf43);
    }

    # 41: same name captured twice → only one free_vars entry
    c44 = make_compiler();
    c44.compile_program(
        parse("function outer() { var y = 1; function inner() { return y + y; } }")
    );
    inner44: CompiledFunction = c44.all_fns[0];
    lf_count44: int = 0;
    for instr in inner44.code {
        if instr.opcode == Opcode.LOAD_FREE {
            lf_count44 += 1;
        }
    }
    if len(inner44.free_vars) == 1 and lf_count44 == 2 {
        ok += 1;
        print("OK  same name captured once → 1 free_var entry, 2 LOAD_FREE");
    } else {
        fail += 1;
        print("FAIL dedup fv=", len(inner44.free_vars), "lf=", lf_count44);
    }

    # 42: multi-level capture — grandchild captures grandparent local
    c45 = make_compiler();
    c45.compile_program(
        parse("function a() { var z = 5; function b() { function c() { return z; } } }")
    );
    # c is the innermost — compiled depth-first, appended to all_fns first: all_fns[0]
    inner45: CompiledFunction = c45.all_fns[0];
    has_lf45: bool = False;
    for instr in inner45.code {
        if instr.opcode == Opcode.LOAD_FREE {
            has_lf45 = True;
        }
    }
    if has_lf45 and len(inner45.free_vars) == 1 and inner45.free_vars[0] == "z" {
        ok += 1;
        print("OK  multi-level capture → LOAD_FREE in grandchild");
    } else {
        fail += 1;
        print(
            "FAIL multi-level capture lf=", has_lf45, "fvlen=", len(inner45.free_vars)
        );
    }

    # 43: arrow function captures outer variable
    c46 = make_compiler();
    c46.compile_program(parse("function outer() { var v = 42; var f = () => v; }"));
    arrow46: CompiledFunction = c46.all_fns[0];
    has_lf46: bool = False;
    for instr in arrow46.code {
        if instr.opcode == Opcode.LOAD_FREE {
            has_lf46 = True;
        }
    }
    if has_lf46 and len(arrow46.free_vars) >= 1 and arrow46.free_vars[0] == "v" {
        ok += 1;
        print("OK  arrow closure → LOAD_FREE, free_vars[0]=v");
    } else {
        fail += 1;
        print("FAIL arrow closure lf=", has_lf46, "fv=", arrow46.free_vars);
    }

    # 44: malformed if (missing test) → THROW SyntaxError bytecode, not silent no-op
    c47 = make_compiler();
    lit_true: ASTNode = make_literal("true", "true", ZERO_RANGE);
    bad_if: ASTNode = make_if(lit_true, make_block([], ZERO_RANGE), None, ZERO_RANGE);
    bad_if.cond_expr = None;  # ASTNode.test was renamed to cond_expr
    fn47: CompiledFunction = c47.compile_program(make_program([bad_if], ZERO_RANGE));
    has_throw47: bool = False;
    has_syn_msg47: bool = False;
    for instr in fn47.code {
        if instr.opcode == Opcode.THROW {
            has_throw47 = True;
        }
    }
    ci47: int = 0;
    n47: int = fn47.constants.size();
    while ci47 < n47 {
        cv47: str = fn47.constants.get(ci47);
        if cv47.find("if statement missing test") >= 0 {
            has_syn_msg47 = True;
        }
        ci47 = ci47 + 1;
    }
    if has_throw47 and has_syn_msg47 {
        ok += 1;
        print("OK  malformed if missing test → THROW + SyntaxError message");
    } else {
        fail += 1;
        print("FAIL malformed if guard throw=", has_throw47, "msg=", has_syn_msg47);
    }

    # 48: `arguments` is allocated only when the body can reference it (it names
    # `arguments` or calls `eval`); otherwise every call would build one.
    c48 = make_compiler();
    c48.source_text = "function a(x) { return x; } function b() { return arguments.length; } function c(s) { return eval(s); }";
    c48.compile_program(parse(c48.source_text));
    if len(c48.all_fns) == 3 {
        if c48.all_fns[0].arguments_slot == -1 {
            ok += 1;
            print("OK  no arguments slot when unused");
        } else {
            fail += 1;
            print(
                "FAIL arguments slot allocated for a() =", c48.all_fns[0].arguments_slot
            );
        }
        if c48.all_fns[1].arguments_slot >= 0 {
            ok += 1;
            print("OK  arguments slot when named");
        } else {
            fail += 1;
            print("FAIL no arguments slot for b()");
        }
        if c48.all_fns[2].arguments_slot >= 0 {
            ok += 1;
            print("OK  arguments slot when eval may reach it");
        } else {
            fail += 1;
            print("FAIL no arguments slot for c()");
        }
    } else {
        fail += 1;
        print("FAIL arguments gating all_fns", len(c48.all_fns));
    }
    # Without source text the compiler must stay conservative.
    c49 = make_compiler();
    c49.compile_program(parse("function a(x) { return x; }"));
    if c49.all_fns[0].arguments_slot >= 0 {
        ok += 1;
        print("OK  no source text → conservative arguments slot");
    } else {
        fail += 1;
        print("FAIL arguments slot dropped without source text");
    }

    print("compiler smoke: passed=" + str(ok) + " failed=" + str(fail));
    if fail > 0 {
        fflush(0);
        _exit(1);
    }
}
