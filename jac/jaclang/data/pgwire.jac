import base64;
import hashlib;
import hmac;
import re;
import logging;
import secrets as _pysecrets;
import socket;
import struct;
import from collections { OrderedDict, deque }
import from functools { lru_cache }
glob logger = logging.getLogger(__name__),
     PROTOCOL_VERSION = 196608,
     READ_CHUNK = 65536,
     REWRITE_CACHE_SIZE = 1024,
     STATEMENT_CACHE_SIZE = 512,
     _SQL_COMMENT = re.compile('--[^\\n]*|/\\*.*?\\*/', re.S),
     _DEALLOCATE_ONE = re.compile(
         '\\s*DEALLOCATE\\s+(?:PREPARE\\s+)?(?:"((?:[^"]|"")+)"|([A-Za-z_][A-Za-z0-9_$]*))\\s*;?\\s*$',
         re.I
     ),
     __all__ = ['PgWireConnection', 'PgWireError'];


class PgWireError(Exception) {}


def _encode_param(v: any) -> (bytes | None);
def _array_literal(vals: any) -> str;
def _decode_value(oid: int, raw: bytes) -> any;
def _named_to_positional(sql: str, params: dict[str, any]) -> tuple[str, list[any]];

@lru_cache(maxsize=REWRITE_CACHE_SIZE)
def _rewrite_named(sql: str, names: frozenset[str]) -> tuple[str, tuple[str, ...]];


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
        _closed: bool postinit,
        _rbuf: bytearray postinit,
        _rpos: int postinit,
        _stmts: OrderedDict postinit,
        _stmt_seq: int postinit,
        _evicted: list[str] postinit;

    def postinit -> None;
    def run(sql: str, **params: any) -> list[tuple[any, ...]];
    def close -> None;
    def _connect_socket -> None;
    def _startup -> None;
    def _authenticate(code: int, payload: bytes) -> None;
    def _scram_auth(payload: bytes) -> None;
    def _send(msg_type: str, payload: bytes) -> None;
    def _read_message -> tuple[str, bytes];
    def _fill(n: int) -> None;
    def _drain_async -> None;
    def _handle_async(msg_type: str, payload: bytes) -> bool;
}
