import asyncio;
import os;
import struct;
import from base64 { b64encode }
import from hashlib { sha1 }
import from json { dumps, loads }
import from jaclang.runtimelib.serving.datatypes {
    Headers,
    QueryParams,
    URL,
    WebSocketDisconnect
}


glob WS_GUID: str = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11',
     OP_CONT: int = 0,
     OP_TEXT: int = 1,
     OP_BINARY: int = 2,
     OP_CLOSE: int = 8,
     OP_PING: int = 9,
     OP_PONG: int = 10,
     MAX_FRAME_BYTES: int = 67108864;


def _ws_json_default(o: any) -> str {
    return str(o);
}

def compute_accept_key(key: str) -> str {
    digest = sha1((key + WS_GUID).encode('utf-8')).digest();
    return b64encode(digest).decode('ascii');
}

def encode_frame(opcode: int, payload: bytes, mask: bool = False) -> bytes {
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

obj WSFrame {
    has fin: bool = True,
        opcode: int = OP_TEXT,
        payload: bytes = b'';
}

async def read_frame(reader: any, require_mask: bool = True) -> WSFrame {
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

obj WebSocket {
    has reader: any = None,
        writer: any = None,
        headers: Headers = Headers(),
        url: URL = URL(),
        query_params: QueryParams = QueryParams(),
        path_params: dict[(str, str)] = {},
        client_host: str = '',
        accept_key: str = '',
        accepted: bool = False,
        closed: bool = False,
        close_code: int = 1000,
        is_client_side: bool = False;

    async def accept {
        if self.accepted or self.is_client_side {
            self.accepted = True;
            return;
        }
        response = (
            'HTTP/1.1 101 Switching Protocols\r\n'
            'Upgrade: websocket\r\n'
            'Connection: Upgrade\r\n'
            f'Sec-WebSocket-Accept: {self.accept_key}\r\n'
            '\r\n'
        );
        self.writer.write(response.encode('latin-1'));
        await self.writer.drain();
        self.accepted = True;
    }

    async def close(code: int = 1000, reason: str = '') {
        if self.closed {
            return;
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
        } except Exception {
            ;
        }
        try {
            self.writer.close();
        } except Exception {
            ;
        }
    }

    async def _send_raw(opcode: int, payload: bytes) {
        if self.closed {
            raise WebSocketDisconnect(code=self.close_code);
        }
        self.writer.write(encode_frame(opcode, payload, mask=self.is_client_side));
        await self.writer.drain();
    }

    async def send_text(text: str) {
        await self._send_raw(OP_TEXT, text.encode('utf-8'));
    }

    async def send_bytes(data: bytes) {
        await self._send_raw(OP_BINARY, data);
    }

    async def send_json(data: any) {
        await self._send_raw(
            OP_TEXT, dumps(data, default=_ws_json_default).encode('utf-8')
        );
    }

    async def _next_message_frame -> WSFrame {
        while True {
            frame = await read_frame(self.reader, require_mask=not self.is_client_side);
            if frame.opcode == OP_PING {
                await self._send_raw(OP_PONG, frame.payload);
                continue;
            }
            if frame.opcode == OP_PONG {
                continue;
            }
            if frame.opcode == OP_CLOSE {
                code = 1000;
                if len(frame.payload) >= 2 {
                    code = struct.unpack('!H', frame.payload[:2])[0];
                }
                if not self.closed {
                    self.closed = True;
                    self.close_code = code;
                    try {
                        self.writer.write(
                            encode_frame(
                                OP_CLOSE, frame.payload[:2], mask=self.is_client_side
                            )
                        );
                        await self.writer.drain();
                        self.writer.close();
                    } except Exception {
                        ;
                    }
                }
                raise WebSocketDisconnect(code=code);
            }
            while not frame.fin {
                cont = await read_frame(
                    self.reader, require_mask=not self.is_client_side
                );
                if cont.opcode != OP_CONT {
                    raise WebSocketDisconnect(code=1002);
                }
                frame = WSFrame(
                    fin=cont.fin,
                    opcode=frame.opcode,
                    payload=frame.payload + cont.payload
                );
            }
            return frame;
        }
    }

    async def receive -> dict[str, any] {
        try {
            frame = await self._next_message_frame();
        } except WebSocketDisconnect as d {
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

    async def receive_text -> str {
        message = await self.receive();
        if message['type'] == 'websocket.disconnect' {
            raise WebSocketDisconnect(code=message.get('code', 1006));
        }
        if 'text' in message {
            return message['text'];
        }
        return message.get('bytes', b'').decode('utf-8', errors='replace');
    }

    async def receive_json -> any {
        return loads(await self.receive_text());
    }

    async def __aenter__ -> WebSocket {
        return self;
    }

    async def __aexit__(exc_type: any, exc: any, tb: any) -> bool {
        await self.close();
        return False;
    }
}
