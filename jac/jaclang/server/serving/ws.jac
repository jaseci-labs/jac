import asyncio;
import logging;
import os;
import struct;
import time;
import from base64 { b64encode }
import from hashlib { sha1 }
import from json { dumps, loads }


glob WS_GUID: str = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11',
     OP_CONT: int = 0,
     OP_TEXT: int = 1,
     OP_BINARY: int = 2,
     OP_CLOSE: int = 8,
     OP_PING: int = 9,
     OP_PONG: int = 10,
     MAX_FRAME_BYTES: int = 67108864,
     _logger: logging.Logger = logging.getLogger('jaclang.server.serving.ws');


def _ws_json_default(o: any) -> str;

def compute_accept_key(key: str) -> str;

def encode_frame(opcode: int, payload: bytes, mask: bool = False) -> bytes;

obj WSFrame {
    has fin: bool = True,
        opcode: int = OP_TEXT,
        payload: bytes = b'';
}

async def read_frame(reader: any, require_mask: bool = True) -> WSFrame;

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
        max_message_bytes: int = MAX_FRAME_BYTES,
        is_client_side: bool = False,
        subprotocol: str = '',
        last_activity: float = 0.0,
        _keepalive_task: any = None;

    def start_keepalive(interval: float, timeout: float);
    def stop_keepalive;
    async def _keepalive_loop(interval: float, timeout: float);
    async def accept(subprotocol: str = '');
    async def close(code: int = 1000, reason: str = '');
    async def _send_raw(opcode: int, payload: bytes);
    async def send_text(text: str);
    async def send_bytes(data: bytes);
    async def send_json(data: any);
    async def _on_close_frame(frame: WSFrame);
    async def _next_message_frame -> WSFrame;
    async def receive -> dict[str, any];
    async def receive_text -> str;
    async def receive_json -> any;
    async def __aenter__ -> WebSocket;
    async def __aexit__(exc_type: any, exc: any, tb: any) -> bool;
}
