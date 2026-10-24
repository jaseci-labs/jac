def:pub utf8_cps(bv: bytes) -> list[int];


def:pub cp_off(bv: bytes, cp: int) -> int;


def:pub cp_len(bv: bytes, n: int) -> int;


def:pub cps_str(cps: list[int], a: int, b: int) -> str;


def:pub cpslice_str(bv: bytes, lo: int, hi: int) -> str;


def:pub is_ascii(bv: bytes) -> bool;
