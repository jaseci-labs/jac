import base64;
import hashlib;
import hmac;
import logging;
import secrets as _pysecrets;
import socket;
import struct;
import from collections { deque }
glob logger = logging.getLogger(__name__),
     PROTOCOL_VERSION = 196608,
     __all__ = ['PgWireConnection', 'PgWireError'];


class PgWireError(Exception) {}


def _encode_param(v: any) -> (bytes | None);
def _array_literal(vals: any) -> str;
def _decode_value(oid: int, raw: bytes) -> any;
def _named_to_positional(sql: str, params: dict) -> tuple[str, list];


obj PgWireConnection {
    has user: str,
        host: (str | None) = None,
        port: int = 5432,
        unix_sock: (str | None) = None,
        database: str = 'postgres',
        password: (str | None) = None,
        timeout: (float | None) = None,
        application_name: str = 'jac',
        notifications: deque postinit,
        parameters: dict[str, str] postinit,
        _sock: (any | None) postinit,
        _closed: bool postinit;

    def postinit -> None;
    def run(sql: str, **params: any) -> list;
    def close -> None;
    def _connect_socket -> None;
    def _startup -> None;
    def _authenticate(code: int, payload: bytes) -> None;
    def _scram_auth(payload: bytes) -> None;
    def _send(msg_type: str, payload: bytes) -> None;
    def _read_message -> tuple[str, bytes];
    def _read_exact(n: int) -> bytes;
    def _pump_ready -> None;
    def _handle_async(msg_type: str, payload: bytes) -> bool;
}
