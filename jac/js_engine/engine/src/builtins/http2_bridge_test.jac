"""
Smoke tests for http2_bridge.na.jac (Phase E).

Must be run as a standalone entry module:
    jac run engine/src/builtins/http2_bridge_test.na.jac

These tests are deliberately NOT in http2_bridge.na.jac because library modules
must not contain `with entry {}` blocks — the compiler always emits `jac_entry`
from them even when compiling as an imported module, which causes a duplicate
`jac_entry` symbol that overwrites main's entry point and crashes the engine
with SIGSEGV at JIT startup.
See: js_engine/issues/with-entry-in-imported-module-collides-jac-entry/
"""

import from engine.src.builtins.http2_bridge {
    H2_HANDLE_BASE,
    h2_session_create_client,
    h2_session_create_server,
    h2_session_del,
    h2_session_want_write,
    h2_session_send,
    h2_get_send_ptr,
    h2_pop_event
}
import from engine.src.runtime.jsvalue { JSValue, jsv_is_int32, jsv_to_int32 }

glob no_args: list[JSValue] = [];

with entry {
    # 1. Create a client session.
    hv: JSValue = h2_session_create_client(no_args);
    handle: int = 0;
    if jsv_is_int32(hv) {
        handle = jsv_to_int32(hv);
    }
    if handle < H2_HANDLE_BASE {
        print("FAIL: h2_session_create_client returned " + str(handle));
    } else {
        print("OK: h2_session_create_client -> handle=" + str(handle));
    }

    # 2. After creation the session must want to write (connection preface queued).
    wargs: list[JSValue] = [hv];
    ww: int = 0;
    ww_jsv: JSValue = h2_session_want_write(wargs);
    if jsv_is_int32(ww_jsv) {
        ww = jsv_to_int32(ww_jsv);
    }
    if ww != 1 {
        print("FAIL: h2_session_want_write expected 1, got " + str(ww));
    } else {
        print("OK: h2_session_want_write=1 (preface queued)");
    }

    # 3. Drain the send queue — we should get the client connection preface bytes.
    sargs: list[JSValue] = [hv];
    send_jsv: JSValue = h2_session_send(sargs);
    send_n: int = 0;
    if jsv_is_int32(send_jsv) {
        send_n = jsv_to_int32(send_jsv);
    }
    if send_n <= 0 {
        print("FAIL: h2_session_send returned 0 bytes");
    } else {
        print("OK: h2_session_send returned " + str(send_n) + " bytes");
    }

    # 3b. Verify h2_get_send_ptr returns a non-zero pointer.
    spargs: list[JSValue] = [hv];
    sp_jsv: JSValue = h2_get_send_ptr(spargs);
    sp_ok: int = 0;
    # jsv_from_double(0.0) IS an int32 (value=0); non-zero double is not int32.
    # We check the raw double value: if it's a double (not zero int), ptr is set.
    if jsv_is_int32(sp_jsv) {
        sp_ok = 0;
    } else {
        sp_ok = 1;
    }
    if sp_ok != 1 {
        print("FAIL: h2_get_send_ptr returned 0 or wrong type");
    } else {
        print("OK: h2_get_send_ptr returned non-zero pointer");
    }

    # 4. h2_pop_event on a fresh session (no data received) must return undefined.
    pargs: list[JSValue] = [hv];
    ev_jsv: JSValue = h2_pop_event(pargs);
    # js_undefined() is not int32, so jsv_is_int32 returns false — indirect check:
    no_ev: int = 1;
    if jsv_is_int32(ev_jsv) {
        no_ev = 0;
    }
    if no_ev != 1 {
        print("FAIL: h2_pop_event should return undefined when no events");
    } else {
        print("OK: h2_pop_event returns undefined when buffer empty");
    }

    # 5. Create a server session — verify it succeeds too.
    sv: JSValue = h2_session_create_server(no_args);
    srv_handle: int = 0;
    if jsv_is_int32(sv) {
        srv_handle = jsv_to_int32(sv);
    }
    if srv_handle < H2_HANDLE_BASE {
        print("FAIL: h2_session_create_server returned " + str(srv_handle));
    } else {
        print("OK: h2_session_create_server -> handle=" + str(srv_handle));
    }

    # 6. Delete both sessions.
    del_args_c: list[JSValue] = [hv];
    h2_session_del(del_args_c);
    print("OK: h2_session_del (client)");

    del_args_s: list[JSValue] = [sv];
    h2_session_del(del_args_s);
    print("OK: h2_session_del (server)");
}
