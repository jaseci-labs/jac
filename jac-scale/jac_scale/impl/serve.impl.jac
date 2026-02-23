"""Helper function to convert TransportResponse to dict for JSONResponse."""
def _transport_response_to_dict(
    transport_response: TransportResponse
) -> dict[str, Any] {
    result = {
        'ok': transport_response.ok,
        'type': transport_response.type,
        'data': transport_response.data,
        'error': None
    };
    if not transport_response.ok and transport_response.error {
        result['error'] = {
            'code': transport_response.error.code,
            'message': transport_response.error.message,
            'details': transport_response.error.details
        };
    }
    if transport_response.meta {
        meta_dict = {};
        if transport_response.meta.request_id {
            meta_dict['request_id'] = transport_response.meta.request_id;
        }
        if transport_response.meta.trace_id {
            meta_dict['trace_id'] = transport_response.meta.trace_id;
        }
        if transport_response.meta.timestamp {
            meta_dict['timestamp'] = transport_response.meta.timestamp;
        }
        if transport_response.meta.extra {
            meta_dict['extra'] = transport_response.meta.extra;
        }
        if meta_dict {
            result['meta'] = meta_dict;
        }
    }
    return result;
}

"""Helper function to get HTTP status code from TransportResponse."""
def _get_http_status(transport_response: TransportResponse) -> int {
    if transport_response.meta and transport_response.meta.extra {
        return transport_response.meta.extra.get(
            'http_status', 200 if transport_response.ok else 500
        );
    }
    return 200 if transport_response.ok else 500;
}

"""Helper function to convert TransportResponse directly to JSONResponse."""
def _transport_response_to_json_response(
    transport_response: TransportResponse
) -> JSONResponse {
    return JSONResponse(
        status_code=_get_http_status(transport_response),
        content=_transport_response_to_dict(transport_response)
    );
}
