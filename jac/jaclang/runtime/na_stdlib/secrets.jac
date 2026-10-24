import from base64 { urlsafe_b64encode }
import from hmac { compare_digest as _hmac_compare_digest }

glob:pub DEFAULT_ENTROPY: int = 32;


def:pub compare_digest(a: bytes, b: bytes) -> bool;


def:pub token_bytes(nbytes: any = None) -> bytes;


def:pub token_hex(nbytes: any = None) -> str;


def:pub token_urlsafe(nbytes: any = None) -> str;


def:pub randbelow(exclusive_upper_bound: int) -> int;
