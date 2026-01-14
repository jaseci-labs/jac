"""Transport abstraction layer implementations."""

"""Create a success response with envelope pattern."""
impl TransportResponse.success(
    data: Any = None,
    msg_type: MessageType = MessageType.RESPONSE,
    meta: (Meta | None) = None
) -> TransportResponse {
    final_meta = meta or Meta();
    response = TransportResponse();
    response.type = msg_type.value if isinstance(msg_type, MessageType) else msg_type;
    response.ok = True;
    response.data = data;
    response.error = None;
    response.meta = final_meta;
    return response;
}

"""Create an error response with envelope pattern."""
impl TransportResponse.fail(
    code: str,
    message: str,
    details: Any = None,
    msg_type: MessageType = MessageType.ERROR,
    meta: (Meta | None) = None
) -> TransportResponse {
    final_meta = meta or Meta();
    response = TransportResponse();
    response.type = msg_type.value if isinstance(msg_type, MessageType) else msg_type;
    response.ok = False;
    response.data = None;
    response.error = ErrorInfo(code=code, message=message, details=details);
    response.meta = final_meta;
    return response;
}

"""HTTP is stateless - nothing to connect."""
impl HTTPTransport.connect -> None { }

"""Serialize and send HTTP response. Converts TransportResponse to HTTP format."""
impl HTTPTransport.send(data: Any) -> None {
    if isinstance(data, TransportResponse) {
        # Extract HTTP status from meta.extra or use defaults
        status = data.meta.extra.get('http_status', 200 if data.ok else 500)
        if data.meta.extra
        else (200 if data.ok else 500);
        # Build response body following TransportResponse envelope pattern
        response_body = {
            'ok': data.ok,
            'type': data.type,
            'data': data.data,
            'error': None
        };
        # Serialize error if present
        if not data.ok and data.error {
            error_obj = {};
            if getattr(data.error, "code", None) {
                error_obj['code'] = data.error.code;
            }
            if getattr(data.error, "message", None) {
                error_obj['message'] = data.error.message;
            }
            if getattr(data.error, "details", None) is not None {
                error_obj['details'] = data.error.details;
            }
            response_body['error'] = error_obj;
        }
        # Include metadata if present
        if data.meta {
            meta_dict = {};
            if getattr(data.meta, "request_id", None) {
                meta_dict['request_id'] = data.meta.request_id;
            }
            if getattr(data.meta, "trace_id", None) {
                meta_dict['trace_id'] = data.meta.trace_id;
            }
            if getattr(data.meta, "timestamp", None) {
                meta_dict['timestamp'] = data.meta.timestamp;
            }
            if getattr(data.meta, "extra", None) {
                meta_dict['extra'] = data.meta.extra;
            }
            if meta_dict {
                response_body['meta'] = meta_dict;
            }
        }
        # Send HTTP response
        self.handler.send_response(status);
        self.handler.send_header('Content-Type', 'application/json');
        self.handler.send_header('Access-Control-Allow-Origin', '*');
        self.handler.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        self.handler.send_header(
            'Access-Control-Allow-Headers', 'Content-Type, Authorization'
        );
        self.handler.end_headers();
        self.handler.wfile.write(json.dumps(response_body).encode());
        # Store for any callbacks
        self.response_data = response_body;
    } else {
        # For non-TransportResponse data (backward compatibility)
        self.response_data.update(data) if isinstance(data, <>dict) else None;
        self.response_data = data
        if not isinstance(data, <>dict)
        else self.response_data;
    }
    # Trigger on_message callback if registered
    if self.on_message {
        self.on_message(data);
    }
}

"""HTTP is stateless - nothing to close."""
impl HTTPTransport.close -> None { }

"""SSE is stateless - nothing to connect."""
impl StreamTransport.connect -> None { }

"""Push data to the queue for SSE streaming."""
impl StreamTransport.send(data: Any) -> None {
    import asyncio;
    # Queue.put is async, so we need to handle it properly
    # In real usage, this would be: await self.queue.put(data)
    try {
        self.queue.put_nowait(data);
    } except Exception as e {
        if self.on_error {
            self.on_error(e);
        }
    }
}

"""Signal stream end by pushing None to queue."""
impl StreamTransport.close -> None {
    try {
        self.queue.put_nowait(None);
    } except Exception as e {
        if self.on_error {
            self.on_error(e);
        }
    }
    if self.on_close {
        self.on_close();
    }
}

"""Accept the WebSocket connection."""
impl WebSocketTransport.connect -> None {
# In real async usage: await self.websocket.accept()
# For now, assume websocket is already accepted
}

"""Send JSON data through WebSocket."""
impl WebSocketTransport.send(data: Any) -> None {
    # In real async usage: await self.websocket.send_json(data)
    try {
        json_data = json.dumps(data);
        # Placeholder for actual websocket send
        if self.on_message {
            self.on_message(data);
        }
    } except Exception as e {
        if self.on_error {
            self.on_error(e);
        }
    }
}

"""Close the WebSocket connection."""
impl WebSocketTransport.close -> None {
    # In real async usage: await self.websocket.close()
    if self.on_close {
        self.on_close();
    }
}
