"""Python supplies omitted stdlib arguments, including nonzero defaults."""


import from zlib { adler32 }
import from secrets { token_hex }

def adler32_default_seed() -> int {
    return adler32(b"hello");
}

def token_hex_default_len() -> int {
    return len(token_hex());
}
