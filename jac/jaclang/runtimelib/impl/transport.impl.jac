"""Create a success response with envelope pattern."""
impl TransportResponse.success(
    data: any = None,
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
    details: any = None,
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
impl HTTPTransport.send(data: any) -> None {
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
            if data.error.code {
                error_obj['code'] = data.error.code;
            }
            if data.error.message {
                error_obj['message'] = data.error.message;
            }
            if data.error.details is not None {
                error_obj['details'] = data.error.details;
            }
            response_body['error'] = error_obj;
        }
        # Include metadata if present
        if data.meta {
            meta_dict = {};
            if data.meta.request_id {
                meta_dict['request_id'] = data.meta.request_id;
            }
            if data.meta.trace_id {
                meta_dict['trace_id'] = data.meta.trace_id;
            }
            if data.meta.timestamp {
                meta_dict['timestamp'] = data.meta.timestamp;
            }
            if data.meta.extra {
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
        self.response_data.update(data) if isinstance(data, dict) else None;
        self.response_data = data if not isinstance(data, dict) else self.response_data;
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
impl StreamTransport.send(data: any) -> None {
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

"""Serialize a TransportResponse into the standard envelope dict.

Kept in this module so every transport sends the same shape on the wire.
"""
def serialize_transport_response(resp: TransportResponse) -> dict {
    body = {'ok': resp.ok, 'type': resp.type, 'data': resp.data, 'error': None};
    if not resp.ok and resp.error {
        error_obj = {};
        if resp.error.code {
            error_obj['code'] = resp.error.code;
        }
        if resp.error.message {
            error_obj['message'] = resp.error.message;
        }
        if resp.error.details is not None {
            error_obj['details'] = resp.error.details;
        }
        body['error'] = error_obj;
    }
    if resp.meta {
        meta_dict = {};
        if resp.meta.request_id {
            meta_dict['request_id'] = resp.meta.request_id;
        }
        if resp.meta.trace_id {
            meta_dict['trace_id'] = resp.meta.trace_id;
        }
        if resp.meta.timestamp {
            meta_dict['timestamp'] = resp.meta.timestamp;
        }
        if resp.meta.extra {
            meta_dict['extra'] = resp.meta.extra;
        }
        if meta_dict {
            body['meta'] = meta_dict;
        }
    }
    return body;
}

"""Accept the WebSocket connection (idempotent for already-accepted sockets)."""
impl WebSocketTransport.connect -> None {
    if self.websocket is None {
        return;
    }
    try {
        await self.websocket.accept();
    } except Exception as e {
        # Already accepted, or client disappeared; either way surface to caller.
        cb = self.on_error;
        if cb {
            cb(e);
        }
    }
}

"""Send an envelope or raw JSON message over the WebSocket."""
impl WebSocketTransport.send(data: any) -> None {
    payload = (
        serialize_transport_response(data)
            if isinstance(data, TransportResponse)
            else data
    );
    custom_sender = self.sender;
    if custom_sender is None and self.websocket is None {
        err_cb = self.on_error;
        if err_cb {
            err_cb(RuntimeError('WebSocketTransport has no websocket or sender'));
        }
        return;
    }
    try {
        if custom_sender is not None {
            await custom_sender(payload);
        } else {
            await self.websocket.send_json(payload);
        }
        msg_cb = self.on_message;
        if msg_cb {
            msg_cb(payload);
        }
    } except Exception as e {
        err_cb = self.on_error;
        if err_cb {
            err_cb(e);
        }
    }
}

"""Close the underlying WebSocket connection."""
impl WebSocketTransport.close -> None {
    if self.websocket is not None {
        try {
            await self.websocket.close();
        } except Exception as e {
            err_cb = self.on_error;
            if err_cb {
                err_cb(e);
            }
        }
    }
    close_cb = self.on_close;
    if close_cb {
        close_cb();
    }
}
