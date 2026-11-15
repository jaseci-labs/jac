glob _B16: bytes = b"0123456789ABCDEF",
     _B32: bytes = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567",
     _B64: bytes = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
     _B85: bytes = b"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~",
     _PAD: int = 61,
     _rev_b16: list[int] = [],
     _rev_b32: list[int] = [],
     _rev_b64: list[int] = [],
     _rev_b64url: list[int] = [],
     _rev_b85: list[int] = [];


def _make_rev(alphabet: bytes) -> list[int];


def _rev_for(alphabet: bytes, cache: list[int]) -> list[int];


def _casefold_rev(rev: list[int], alphabet: bytes);


def _copy_rev(rev: list[int]) -> list[int];


def _encode_bits(data: bytes, alphabet: bytes, bits: int, quantum: int) -> bytes;


def _decode_bits(data: bytes, rev: list[int], bits: int, errmsg: str) -> bytes;


def:pub b16encode(s: bytes) -> bytes;


def:pub b16decode(s: bytes, casefold: bool = False) -> bytes;


def:pub b32encode(s: bytes) -> bytes;


def:pub b32decode(s: bytes, casefold: bool = False, map01: bytes = b"") -> bytes;


def _b64_alphabet(altchars: bytes) -> bytes;


def _b64_decode_core(data: bytes, rev: list[int], strict: bool) -> bytes;


def:pub b64encode(s: bytes, altchars: bytes = b"") -> bytes;


def:pub b64decode(s: bytes, altchars: bytes = b"", validate: bool = False) -> bytes;


def:pub standard_b64encode(s: bytes) -> bytes;


def:pub standard_b64decode(s: bytes) -> bytes;


def _rev_urlsafe_for(cache: list[int]) -> list[int];


def:pub urlsafe_b64encode(s: bytes) -> bytes;


def:pub urlsafe_b64decode(s: bytes) -> bytes;


def:pub b85encode(b: bytes, pad: bool = False) -> bytes;


def:pub b85decode(b: bytes) -> bytes;
