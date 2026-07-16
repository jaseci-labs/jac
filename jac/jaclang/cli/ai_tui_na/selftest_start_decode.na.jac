"""Native selftest: decode a real managed start_result through bridge_schema.

Guards the Phase 4 startup seam (PLAN.md §5.3 / §5.4). The root cause of the
startup hang was native `str(any)` returning a JSON value's tag ("2") instead of
the underlying scalar, so `_require_schema` rejected every real start_result as a
schema mismatch. Python/static tests never exercise native `any` behavior, so
this is compiled with `jac nacompile` and run as a binary. Emits one tagged
PASS/FAIL line per assertion; the harness fails on any FAIL line.

Pure native: imports only `.bridge_schema` (which imports only `json`), so it
needs no libjacpyembed shim and runs wherever the jac native toolchain exists.
"""

import from .bridge_schema {
    decode_start_result,
    decode_dispose_result,
    decode_batch,
    SCHEMA_ID,
    as_str,
    as_int,
    as_bool
}


def _check(label: str, ok: bool) {
    if ok {
        print("PASS " + label);
    } else {
        print("FAIL " + label);
    }
}

with entry {
    # 1. A real managed start_result — mirrors embed_agent.encode_start_result,
    #    including CPython json.dumps separators (", " / ": ").
    wire: str = (
        "{\"schema_id\": \"" + SCHEMA_ID + "\", "
        + "\"kind\": \"start_result\", "
        + "\"ok\": true, "
        + "\"session_id\": \"sess-42\", "
        + "\"epoch\": 7, "
        + "\"error\": \"\"}"
    );

    # Regression: native decode must succeed. Before the fix, str(any) returned
    # the tag and decode_start_result raised "schema_id mismatch".
    data: dict[str, any] = {};
    raised: bool = False;
    try {
        data = decode_start_result(wire);
    } except Exception {
        raised = True;
    }
    _check("na_decode_start_result_ok", not raised);
    _check(
        "na_start_schema_id_matches",
        as_str(data.get("schema_id", "")) == SCHEMA_ID
    );
    _check(
        "na_start_kind_is_start_result",
        as_str(data.get("kind", "")) == "start_result"
    );
    _check("na_start_ok_true", as_bool(data.get("ok", False)) == True);
    _check(
        "na_start_session_id", as_str(data.get("session_id", "")) == "sess-42"
    );
    _check("na_start_epoch", as_int(data.get("epoch", 0)) == 7);

    # 2. Malformed schema_id must still raise (decoder stays strict).
    bad_raised: bool = False;
    try {
        decode_start_result("{\"schema_id\": \"x\", \"kind\": \"start_result\"}");
    } except Exception {
        bad_raised = True;
    }
    _check("na_malformed_schema_raises", bad_raised);

    # 3. Wrong kind must raise.
    wrong_kind_raised: bool = False;
    try {
        decode_start_result(
            "{\"schema_id\": \"" + SCHEMA_ID + "\", \"kind\": \"dispose_result\"}"
        );
    } except Exception {
        wrong_kind_raised = True;
    }
    _check("na_wrong_kind_raises", wrong_kind_raised);

    # 4. Dispose-result decode — the bounded-cleanup path uses this after a
    #    bad/failed start, so its decode must also be correct under native any.
    disp_wire: str = (
        "{\"schema_id\": \"" + SCHEMA_ID + "\", "
        + "\"kind\": \"dispose_result\", "
        + "\"ok\": true, "
        + "\"timed_out\": false, "
        + "\"reason\": \"bad_start_result\", "
        + "\"joined_workers\": 1}"
    );
    disp: dict[str, any] = {};
    disp_raised: bool = False;
    try {
        disp = decode_dispose_result(disp_wire);
    } except Exception {
        disp_raised = True;
    }
    _check("na_decode_dispose_result_ok", not disp_raised);
    _check(
        "na_dispose_not_timed_out",
        as_bool(disp.get("timed_out", True)) == False
    );
    _check(
        "na_dispose_joined_workers", as_int(disp.get("joined_workers", 0)) == 1
    );

    # 5. Direct coercion regression: the any->typed helpers must yield the
    #    underlying scalar, not the tag. Feeds a representative mutation batch.
    batch_wire: str = (
        "{\"schema_id\": \"" + SCHEMA_ID + "\", "
        + "\"kind\": \"session_event_batch\", "
        + "\"epoch\": 3, \"first_seq\": 1, \"last_seq\": 2, "
        + "\"mutations\": [{\"kind\": \"runtime_state_changed\", "
        + "\"lifecycle\": \"running\"}]}"
    );
    batch: dict[str, any] = {};
    batch_raised: bool = False;
    try {
        batch = decode_batch(batch_wire);
    } except Exception {
        batch_raised = True;
    }
    _check("na_decode_batch_ok", not batch_raised);
    _check("na_batch_epoch", as_int(batch.get("epoch", 0)) == 3);
    # Native lists are iterated with `for` (the only safe shape); avoid len()/index
    # on any-typed values. Find the runtime_state_changed mutation by scanning.
    muts_any = batch.get("mutations", None);
    mut_kind: str = "";
    if muts_any is not None {
        if isinstance(muts_any, list) {
            for m_any in muts_any {
                if isinstance(m_any, dict) {
                    fm: dict[str, any] = m_any;
                    mk = as_str(fm.get("kind", ""));
                    if mk == "runtime_state_changed" {
                        mut_kind = mk;
                    }
                }
            }
        }
    }
    _check("na_batch_mutation_kind", mut_kind == "runtime_state_changed");
}
