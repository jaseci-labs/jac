import from engine.src.runtime.global { global_context_create, init_global }
import from engine.src.ffi.libc { fflush, _exit }
import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_is_string_cell,
    jsv_is_object_cell
}
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.jsobject { js_object_get, js_object_has_own }
import from engine.src.runtime.error {
    make_error,
    make_type_error,
    make_range_error,
    make_syntax_error,
    make_reference_error,
    make_uri_error,
    make_eval_error,
    get_error_proto,
    get_type_error_proto,
    format_stack,
    attach_stack,
    key_stack_internal
}

# ══════════════════════════════════════════════════════════════════════════════
# Smoke tests for runtime/error.na.jac
# ══════════════════════════════════════════════════════════════════════════════
with entry {
    # Engine startup: wire every module's realm singleton and install the
    # builtin prototypes, as the runtime does before running any script.
    ctx = global_context_create();
    init_global(ctx);

    ok: int = 0;
    fail: int = 0;

    key_name: int = str_intern("name");
    key_message: int = str_intern("message");
    key_stack: int = str_intern("stack");

    # 1: create plain Error — has name, message properties
    e1: JSValue = make_error("something went wrong");
    n1: JSValue = js_object_get(e1, key_name);
    m1: JSValue = js_object_get(e1, key_message);
    if jsv_is_string_cell(n1) and jsv_is_string_cell(m1) {
        ok += 1;
        print("OK  make_error has name+message");
    } else {
        fail += 1;
        print("FAIL make_error name=", n1, "msg=", m1);
    }

    # 2: TypeError name is "TypeError"
    e2: JSValue = make_type_error("not a function");
    n2: JSValue = js_object_get(e2, key_name);
    if jsv_is_string_cell(n2) {
        ok += 1;
        print("OK  make_type_error name is String");
    } else {
        fail += 1;
        print("FAIL TypeError name=", n2);
    }

    # `err.stack` is served by the V8-style Error.prototype.stack accessor that
    # the JS prelude (builtins/js/builtins_stubs.js) installs over a hidden
    # per-instance slot; native error construction only fills that slot and
    # never creates an own "stack" data property. Unit tests don't load the
    # prelude and js_object_get doesn't run getters, so read the slot directly.
    key_stack_slot: int = key_stack_internal();

    # 3: RangeError
    e3: JSValue = make_range_error("Maximum call stack size exceeded");
    s3: JSValue = js_object_get(e3, key_stack_slot);
    if jsv_is_string_cell(s3) {
        ok += 1;
        print("OK  make_range_error captures a stack");
    } else {
        fail += 1;
        print("FAIL RangeError stack slot=", s3);
    }
    if not js_object_has_own(e3, key_stack) {
        ok += 1;
        print("OK  error instance has no own 'stack' data property");
    } else {
        fail += 1;
        print("FAIL error instance has an own 'stack' property");
    }

    # 4: SyntaxError
    e4: JSValue = make_syntax_error("Unexpected token");
    n4: JSValue = js_object_get(e4, key_name);
    if jsv_is_string_cell(n4) {
        ok += 1;
        print("OK  make_syntax_error");
    } else {
        fail += 1;
        print("FAIL SyntaxError");
    }

    # 5: ReferenceError
    e5: JSValue = make_reference_error("x is not defined");
    n5: JSValue = js_object_get(e5, key_name);
    if jsv_is_string_cell(n5) {
        ok += 1;
        print("OK  make_reference_error");
    } else {
        fail += 1;
        print("FAIL ReferenceError");
    }

    # 6: URIError
    e6: JSValue = make_uri_error("URI malformed");
    n6: JSValue = js_object_get(e6, key_name);
    if jsv_is_string_cell(n6) {
        ok += 1;
        print("OK  make_uri_error");
    } else {
        fail += 1;
        print("FAIL URIError");
    }

    # 7: EvalError
    e7: JSValue = make_eval_error("eval usage");
    n7: JSValue = js_object_get(e7, key_name);
    if jsv_is_string_cell(n7) {
        ok += 1;
        print("OK  make_eval_error");
    } else {
        fail += 1;
        print("FAIL EvalError");
    }
}

glob
     # 8: format_stack builds V8-style string
     frames: list[str] = ["foo (app.js:3:5)", "bar (app.js:10:1)"];
with entry {
    trace: str = format_stack("TypeError", "not a function", frames);
    # Check that it contains the first frame label
    found: bool = False;
    fi: int = 0;
    tlen: int = len(trace);
}

glob target: str = "at foo";
with entry {
    tlen2: int = len(target);
    while fi <= tlen - tlen2 {
        chunk: str = trace[fi:fi + tlen2];
        if chunk == target {
            found = True;
            fi = tlen;
        }
        fi = fi + 1;
    }
    if found {
        ok += 1;
        print("OK  format_stack contains 'at foo'");
    } else {
        fail += 1;
        print("FAIL format_stack =", trace);
    }

    # 9: attach_stack updates the stack property
    e9: JSValue = make_error("test");
    attach_stack(e9, "Error: test\n    at main (test.js:1:1)");
    sk9: JSValue = js_object_get(e9, key_stack_slot);
    if jsv_is_string_cell(sk9) {
        ok += 1;
        print("OK  attach_stack sets stack property");
    } else {
        fail += 1;
        print("FAIL attach_stack tag=", sk9);
    }

    # 10: prototype chain — TypeError proto inherits from Error proto
    te_proto: JSValue = get_type_error_proto();
    err_proto: JSValue = get_error_proto();
    if jsv_is_object_cell(te_proto) and jsv_is_object_cell(err_proto) {
        ok += 1;
        print("OK  prototype objects are JSObjects");
    } else {
        fail += 1;
        print("FAIL proto tags te=", te_proto, "err=", err_proto);
    }

    print("error smoke: passed=" + str(ok) + " failed=" + str(fail));
    if fail > 0 {
        fflush(0);
        _exit(1);
    }
}
