"""
VM smoke tests (standalone).

A subset of the tests embedded in vm/vm.na.jac, factored out to follow
the same pattern as other test_*.na.jac files in this directory.
"""

import from engine.src.runtime.global {
    GlobalContext,
    global_context_create,
    init_global,
    run_script
}
import from engine.src.ffi.libc { fflush, _exit }
import from engine.src.vm.vm {
    VM,
    JSClosure,
    js_str,
    js_undefined,
    make_vm,
    is_fn_val,
    get_fn_idx
}
import from engine.src.runtime.jsvalue {
    JSValue,
    js_int,
    js_false,
    jsv_is_bool,
    jsv_is_int32,
    jsv_is_string_cell,
    jsv_to_bool,
    jsv_to_int32
}

"""Declare `fname` by evaluating `js_src` in `ctx` (run_script: the engine's own
parse+compile+eval path), then invoke its closure directly through VM.run."""
def _call(ctx: GlobalContext, js_src: str, fname: str, args: list[JSValue]) -> JSValue {
    fn_val: JSValue = run_script(ctx, js_src + "\n" + fname + ";");
    if not is_fn_val(fn_val) {
        return js_undefined();
    }
    cl: JSClosure = ctx.realm.closures[get_fn_idx(fn_val)];
    vm: VM = make_vm();
    return vm.run(cl.func, js_undefined(), args, cl.free_vals, fn_val);
}

with entry {
    # Engine startup: wire every module's realm singleton and install the
    # builtin prototypes, as the runtime does before running any script.
    ctx = global_context_create();
    init_global(ctx);

    ok: int = 0;
    fail: int = 0;

    # 1: return numeric literal
    r1: JSValue = _call(ctx, "function f() { return 42; }", "f", []);
    if jsv_is_int32(r1) and jsv_to_int32(r1) == 42 {
        ok += 1;
        print("OK  return 42");
    } else {
        fail += 1;
        print("FAIL return 42 tag=", r1, "int=", jsv_to_int32(r1));
    }

    # 2: add two args
    r2: JSValue = _call(
        ctx, "function add(a,b) { return a+b; }", "add", [js_int(3), js_int(4)]
    );
    if jsv_is_int32(r2) and jsv_to_int32(r2) == 7 {
        ok += 1;
        print("OK  add(3,4) = 7");
    } else {
        fail += 1;
        print("FAIL add(3,4) tag=", r2, "int=", jsv_to_int32(r2));
    }

    # 3: local variable + while loop (sum 1..5)
    r3: JSValue = _call(
        ctx,
        "function sum(n) { var r = 0; while (n > 0) { r = r + n; n = n - 1; } return r; }",
        "sum",
        [js_int(5)]
    );
    if jsv_is_int32(r3) and jsv_to_int32(r3) == 15 {
        ok += 1;
        print("OK  sum(5) = 15");
    } else {
        fail += 1;
        print("FAIL sum(5) tag=", r3, "int=", jsv_to_int32(r3));
    }

    # 4: recursion — factorial
    r4: JSValue = _call(
        ctx,
        "function fact(n) { if (n <= 1) { return 1; } return n * fact(n-1); }",
        "fact",
        [js_int(5)]
    );
    if jsv_is_int32(r4) and jsv_to_int32(r4) == 120 {
        ok += 1;
        print("OK  fact(5) = 120");
    } else {
        fail += 1;
        print("FAIL fact(5) tag=", r4, "int=", jsv_to_int32(r4));
    }

    # 5: try-catch — throw and catch an integer
    r5: JSValue = _call(
        ctx, "function f() { try { throw 99; } catch(e) { return e; } }", "f", []
    );
    if jsv_is_int32(r5) and jsv_to_int32(r5) == 99 {
        ok += 1;
        print("OK  try-catch = 99");
    } else {
        fail += 1;
        print("FAIL try-catch tag=", r5, "int=", jsv_to_int32(r5));
    }

    # 6: closure — inner reads outer local
    r6: JSValue = _call(
        ctx,
        "function outer() { var x = 10; function inner() { return x; } return inner(); }",
        "outer",
        []
    );
    if jsv_is_int32(r6) and jsv_to_int32(r6) == 10 {
        ok += 1;
        print("OK  closure read outer var = 10");
    } else {
        fail += 1;
        print("FAIL closure tag=", r6, "int=", jsv_to_int32(r6));
    }

    # 7: SET_PROP result — `obj.x = 5` as expression yields 5, not obj
    r7: JSValue = _call(
        ctx, "function f() { var o = {}; var v = (o.x = 5); return v; }", "f", []
    );
    if jsv_is_int32(r7) and jsv_to_int32(r7) == 5 {
        ok += 1;
        print("OK  SET_PROP result = 5");
    } else {
        fail += 1;
        print("FAIL SET_PROP result tag=", r7, "int=", jsv_to_int32(r7));
    }

    # 8: SET_INDEX result — `arr[0] = 7` as expression yields 7
    r8: JSValue = _call(
        ctx, "function f() { var a = [0]; var v = (a[0] = 7); return v; }", "f", []
    );
    if jsv_is_int32(r8) and jsv_to_int32(r8) == 7 {
        ok += 1;
        print("OK  SET_INDEX result = 7");
    } else {
        fail += 1;
        print("FAIL SET_INDEX result tag=", r8, "int=", jsv_to_int32(r8));
    }

    # 9: string concatenation via ADD
    r9: JSValue = _call(
        ctx,
        "function f(a, b) { return a + b; }",
        "f",
        [js_str("hello"), js_str(" world")]
    );
    if jsv_is_string_cell(r9) {
        ok += 1;
        print("OK  string concat");
    } else {
        fail += 1;
        print("FAIL string concat tag=", r9);
    }

    # 10: boolean NOT
    r10: JSValue = _call(ctx, "function f(x) { return !x; }", "f", [js_false()]);
    if jsv_is_bool(r10) and jsv_to_bool(r10) {
        ok += 1;
        print("OK  !false = true");
    } else {
        fail += 1;
        print("FAIL !false tag=", r10);
    }

    print("vm smoke: passed=" + str(ok) + " failed=" + str(fail));
    if fail > 0 {
        fflush(0);
        _exit(1);
    }
}
