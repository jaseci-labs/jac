"""A raised exception reaches the caller as a message and the server log as a stack."""

import logging;
import from logging.handlers { MemoryHandler }
import from jaclang.scale.tests.scale_test_client { make_client }

def _hit_with_capture(path: str) -> tuple[any, list[any]] {
    serve_logger = logging.getLogger("jaclang.serve");
    capture = MemoryHandler(10000);
    prev_level = serve_logger.level;
    prev_disabled = serve_logger.disabled;
    prev_global = logging.root.manager.disable;
    serve_logger.setLevel(logging.ERROR);
    serve_logger.disabled = False;
    logging.disable(logging.NOTSET);
    serve_logger.addHandler(capture);
    client = make_client("error_paths.jac");
    try {
        resp = client.post(path, json={});
        return (resp, list(capture.buffer));
    } finally {
        client.close();
        serve_logger.removeHandler(capture);
        serve_logger.setLevel(prev_level);
        serve_logger.disabled = prev_disabled;
        logging.disable(prev_global);
    }
}

def _stacks(records: list[any]) -> list[str] {
    fmt = logging.Formatter();
    return [
        fmt.format(r)
        for r in records
        if r.exc_info
    ];
}

def _assert_message_only(resp: any, unit: str) {
    assert resp.status_code == 500 , resp.text;
    body = resp.json();
    assert body["ok"] is False , body;
    err = body["error"];
    assert err["code"] == "EXECUTION_ERROR" , err;
    assert err["message"] == "boom" , err;
    assert "details" not in err , f"{unit} put details on the wire: {err}";
    assert "Traceback" not in resp.text , resp.text;
}

def _assert_stack_logged(records: list[any], unit: str) {
    stacks = _stacks(records);
    hits = [
        s
        for s in stacks
        if f"{unit} raised ValueError: boom" in s and "ValueError: boom" in s
    ];
    assert len(hits) == 1 , (
        f"expected one ERROR record with the stack for {unit}, got "
        f"{len(hits)} of {len(records)} records: {stacks}"
    );
    assert "error_paths.jac" in hits[0] , hits[0];
}

test "walker exception: message on the wire, stack in the server log" {
    (resp, records) = _hit_with_capture("/walker/Boom");
    _assert_message_only(resp, "Boom");
    _assert_stack_logged(records, "Boom");
}

test "function exception: message on the wire, stack in the server log" {
    (resp, records) = _hit_with_capture("/function/boom_fn");
    _assert_message_only(resp, "boom_fn");
    _assert_stack_logged(records, "boom_fn");
}
