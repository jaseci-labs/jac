impl _ws_json_default(o: any) -> str {
    return str(o);
}

impl compute_accept_key(key: str) -> str {
    digest = sha1((key + WS_GUID).encode('utf-8')).digest();
    return b64encode(digest).decode('ascii');
}

impl encode_frame(opcode: int, payload: bytes, mask: bool = False) -> bytes {
    first = 0x80 | opcode;
    length = len(payload);
    mask_bit = 0x80 if mask else 0;
    if length < 126 {
        header = struct.pack('!BB', first, mask_bit | length);
    } elif length < 65536 {
        header = struct.pack('!BBH', first, mask_bit | 126, length);
    } else {
        header = struct.pack('!BBQ', first, mask_bit | 127, length);
    }
    if not mask {
        return header + payload;
    }
    mask_key = os.urandom(4);
    masked = bytes([b ^ mask_key[i % 4] for (i, b) in enumerate(payload)]);
    return header + mask_key + masked;
}

impl read_frame(reader: any, require_mask: bool = True) -> WSFrame {
    head: bytes = await reader.readexactly(2);
    fin = bool(head[0] & 0x80);
    opcode = head[0] & 0x0F;
    masked = bool(head[1] & 0x80);
    length = head[1] & 0x7F;
    if length == 126 {
        two: bytes = await reader.readexactly(2);
        length = struct.unpack('!H', two)[0];
    } elif length == 127 {
        eight: bytes = await reader.readexactly(8);
        length = struct.unpack('!Q', eight)[0];
    }
    if length > MAX_FRAME_BYTES {
        raise WebSocketDisconnect(code=1009);
    }
    if require_mask and not masked {
        raise WebSocketDisconnect(code=1002);
    }
    mask_key: bytes = await reader.readexactly(4) if masked else b'';
    payload: bytes = await reader.readexactly(length) if length else b'';
    if masked and payload {
        payload = bytes([b ^ mask_key[i % 4] for (i, b) in enumerate(payload)]);
    }
    return WSFrame(fin=fin, opcode=opcode, payload=payload);
}

impl WebSocket.start_keepalive(interval: float, timeout: float) {
    if interval <= 0 or self._keepalive_task is not None {
        return;
    }
    self.last_activity = time.monotonic();
    self._keepalive_task = asyncio.ensure_future(
        self._keepalive_loop(interval, timeout)
    );
}

impl WebSocket.stop_keepalive {
    task = self._keepalive_task;
    self._keepalive_task = None;
    if task is not None and not task.done() {
        task.cancel();
    }
}

impl WebSocket._keepalive_loop(interval: float, timeout: float) {
    awaiting_since: float = 0.0;
    try {
        while not self.closed {
            await asyncio.sleep(min(interval, max(0.5, timeout / 2.0)));
            now = time.monotonic();
            if awaiting_since {
                if self.last_activity >= awaiting_since {
                    awaiting_since = 0.0;
                } elif now - awaiting_since >= timeout {
                    _logger.info('websocket keepalive timed out; closing 1011');
                    await self.close(1011, 'keepalive timeout');
                    return;
                }
                continue;
            }
            if now - self.last_activity >= interval {
                try {
                    await self._send_raw(OP_PING, b'');
                } except Exception {
                    return;
                }
                awaiting_since = now;
            }
        }
    } except asyncio.CancelledError {} except Exception {
        _logger.debug('websocket keepalive loop ended', exc_info=True);
    }
}

impl WebSocket.accept(subprotocol: str = '') {
    if self.accepted or self.is_client_side {
        self.accepted = True;
        return;
    }
    chosen = subprotocol.strip();
    self.subprotocol = chosen;
    protocol_line = f'Sec-WebSocket-Protocol: {chosen}\r\n' if chosen else '';
    response = (
        'HTTP/1.1 101 Switching Protocols\r\n'
        'Upgrade: websocket\r\n'
        'Connection: Upgrade\r\n'
        f'Sec-WebSocket-Accept: {self.accept_key}\r\n'
        f'{protocol_line}'
        '\r\n'
    );
    self.writer.write(response.encode('latin-1'));
    await self.writer.drain();
    self.accepted = True;
}

impl WebSocket.close(code: int = 1000, reason: str = '') {
    if self.closed {
        return;
    }
    self.stop_keepalive();
    if not self.accepted and not self.is_client_side and code != 1000 {
        try {
            await self.accept();
        } except Exception {}
    }
    self.closed = True;
    self.close_code = code;
    try {
        if not self.accepted and not self.is_client_side {
            response = (
                'HTTP/1.1 403 Forbidden\r\n'
                'Content-Length: 0\r\n'
                'Connection: close\r\n'
                '\r\n'
            );
            self.writer.write(response.encode('latin-1'));
        } else {
            payload = struct.pack('!H', code);
            if reason {
                payload = payload + reason.encode('utf-8')[:123];
            }
            self.writer.write(
                encode_frame(OP_CLOSE, payload, mask=self.is_client_side)
            );
        }
        await self.writer.drain();
    } except Exception {}
    try {
        self.writer.close();
    } except Exception {}
}

impl WebSocket._send_raw(opcode: int, payload: bytes) {
    if self.closed {
        raise WebSocketDisconnect(code=self.close_code);
    }
    self.writer.write(encode_frame(opcode, payload, mask=self.is_client_side));
    await self.writer.drain();
}

impl WebSocket.send_text(text: str) {
    await self._send_raw(OP_TEXT, text.encode('utf-8'));
}

impl WebSocket.send_bytes(data: bytes) {
    await self._send_raw(OP_BINARY, data);
}

impl WebSocket.send_json(data: any) {
    await self._send_raw(
        OP_TEXT, dumps(data, `default=_ws_json_default).encode('utf-8')
    );
}

impl WebSocket._on_close_frame(frame: WSFrame) {
    code = 1000;
    if len(frame.payload) >= 2 {
        code = struct.unpack('!H', frame.payload[:2])[0];
    }
    if not self.closed {
        self.closed = True;
        self.close_code = code;
        try {
            self.writer.write(
                encode_frame(OP_CLOSE, frame.payload[:2], mask=self.is_client_side)
            );
            await self.writer.drain();
            self.writer.close();
        } except Exception {}
    }
    raise WebSocketDisconnect(code=code);
}

impl WebSocket._next_message_frame -> WSFrame {
    cap = self.max_message_bytes or MAX_FRAME_BYTES;
    while True {
        frame = await read_frame(self.reader, require_mask=not self.is_client_side);
        self.last_activity = time.monotonic();
        if frame.opcode == OP_PING {
            await self._send_raw(OP_PONG, frame.payload);
            continue;
        }
        if frame.opcode == OP_PONG {
            continue;
        }
        if frame.opcode == OP_CLOSE {
            await self._on_close_frame(frame);
        }
        if len(frame.payload) > cap {
            raise WebSocketDisconnect(code=1009);
        }
        while not frame.fin {
            cont = await read_frame(self.reader, require_mask=not self.is_client_side);
            if cont.opcode == OP_PING {
                await self._send_raw(OP_PONG, cont.payload);
                continue;
            }
            if cont.opcode == OP_PONG {
                continue;
            }
            if cont.opcode == OP_CLOSE {
                await self._on_close_frame(cont);
            }
            if cont.opcode != OP_CONT {
                raise WebSocketDisconnect(code=1002);
            }
            if len(frame.payload) + len(cont.payload) > cap {
                raise WebSocketDisconnect(code=1009);
            }
            frame = WSFrame(
                fin=cont.fin, opcode=frame.opcode, payload=frame.payload + cont.payload
            );
        }
        return frame;
    }
}

impl WebSocket.receive -> dict[str, any] {
    try {
        frame = await self._next_message_frame();
    } except WebSocketDisconnect as d {
        if not self.closed and d.code in (1002, 1009) {
            await self.close(d.code);
        }
        return {'type': 'websocket.disconnect', 'code': d.code};
    } except (asyncio.IncompleteReadError, ConnectionError, OSError) {
        self.closed = True;
        return {'type': 'websocket.disconnect', 'code': 1006};
    }
    if frame.opcode == OP_BINARY {
        return {'type': 'websocket.receive', 'bytes': frame.payload};
    }
    return {
        'type': 'websocket.receive',
        'text': frame.payload.decode('utf-8', errors='replace')
    };
}

impl WebSocket.receive_text -> str {
    message = await self.receive();
    if message['type'] == 'websocket.disconnect' {
        raise WebSocketDisconnect(code=message.get('code', 1006));
    }
    if 'text' in message {
        return message['text'];
    }
    return message.get('bytes', b'').decode('utf-8', errors='replace');
}

impl WebSocket.receive_json -> any {
    return loads(await self.receive_text());
}

impl WebSocket.__aenter__ -> WebSocket {
    return self;
}

impl WebSocket.__aexit__(exc_type: any, exc: any, tb: any) -> bool {
    await self.close();
    return False;
}
