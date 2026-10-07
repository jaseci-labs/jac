"""Regression: own property with undefined value must not fall through prototype."""

import from engine.src.runtime.global { global_context_create }
import from engine.src.runtime.jsvalue {
    js_undefined,
    js_int,
    jsv_is_undefined,
    jsv_to_int32
}
import from engine.src.ffi.libc { fflush, _exit }
import from engine.src.runtime.jsobject {
    KEY_BASE,
    js_object_create_null,
    js_object_set,
    js_object_get,
    js_object_set_prototype
}

with entry {
    # Engine startup: wire every module's realm singleton (string table,
    # object table, …); the engine code under test reads them.
    ctx = global_context_create();

    ok: int = 0;
    err: int = 0;
}

glob key_x: int = KEY_BASE + 50;
with entry {
    child = js_object_create_null();
    parent = js_object_create_null();
    js_object_set(child, key_x, js_undefined());
    js_object_set(parent, key_x, js_int(42));
    js_object_set_prototype(child, parent);
    got = js_object_get(child, key_x);
    if jsv_is_undefined(got) {
        ok += 1;
    } else {
        print("FAIL: expected undefined, got", jsv_to_int32(got));
        err += 1;
    }
    print("undefined-own-prop: ok=" + str(ok) + " err=" + str(err));
    if err > 0 {
        fflush(0);
        _exit(1);
    }
}
