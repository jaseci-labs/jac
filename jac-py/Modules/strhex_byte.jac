glob _hexdigits: list[int] = [
         48,
         49,
         50,
         51,
         52,
         53,
         54,
         55,
         56,
         57,
         97,
         98,
         99,
         100,
         101,
         102
     ];

def strhex_pack_byte(value: int) -> int {
    hi: int = 0;
    lo: int = 0;
    hi = _hexdigits[(value >> 4)];
    lo = _hexdigits[(value & 15)];
    return ((hi << 8) | lo);
}
