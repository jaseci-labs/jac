"""Unit tests for jaclang transport envelope serialization."""

import sys;
import from jaclang.runtimelib.transport {
    TransportResponse,
    ErrorInfo,
    Meta,
    MessageType
}

# `serialize_transport_response` is defined in the impl file; pull it from
# the loaded module at runtime so the type checker doesn't flag the import.
glob _transport_mod = sys.modules.get('jaclang.runtimelib.transport'),
     serialize_transport_response = (
         _transport_mod?.serialize_transport_response if _transport_mod else None
     );


"""Success envelope: ok=True, data set, no error."""
test "serialize success response" {
    resp = TransportResponse.success(data={"value": 42});
    body = serialize_transport_response(resp);
    assert body["ok"] is True;
    assert body["type"] == MessageType.RESPONSE.value;
    assert body["data"] == {"value": 42};
    assert body["error"] is None;
    # No meta fields set → key should be absent (helper only adds non-empty meta).
    assert "meta" not in body or body.get("meta") == {};
}


"""Failure envelope: ok=False, error object with code/message/details."""
test "serialize fail response" {
    resp = TransportResponse.fail(
        code="BAD_INPUT", message="bad", details={"field": "x"}
    );
    body = serialize_transport_response(resp);
    assert body["ok"] is False;
    assert body["data"] is None;
    err = body["error"];
    assert err["code"] == "BAD_INPUT";
    assert err["message"] == "bad";
    assert err["details"] == {"field": "x"};
}


"""Meta fields round-trip into a meta dict when present."""
test "serialize response with meta" {
    resp = TransportResponse(
        ok=True,
        data="ok",
        meta=Meta(request_id="req-1", trace_id="tr-1", timestamp="2026-04-17T00:00:00Z")
    );
    body = serialize_transport_response(resp);
    assert body["meta"]["request_id"] == "req-1";
    assert body["meta"]["trace_id"] == "tr-1";
    assert body["meta"]["timestamp"] == "2026-04-17T00:00:00Z";
}
