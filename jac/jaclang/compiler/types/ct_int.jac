glob MAG_SHIFT: int = 30,
     MAG_BASE: int = 1073741824,
     MAG_MASK: int = 1073741823,
     MAX_STR_DIGITS: int = 4300;

def mag_norm(m: list[int]) -> list[int];

def mag_from_int(v: int) -> list[int];

def mag_to_int(m: list[int]) -> int;

def mag_is_zero(m: list[int]) -> bool;

def mag_cmp(a: list[int], b: list[int]) -> int;

def mag_add(a: list[int], b: list[int]) -> list[int];

def mag_sub(a: list[int], b: list[int]) -> list[int];

def mag_mul(a: list[int], b: list[int]) -> list[int];

def mag_mul_small(a: list[int], s: int) -> list[int];

def mag_add_small(a: list[int], s: int) -> list[int];

def mag_divmod_small(a: list[int], d: int) -> tuple[list[int], int];

def mag_bit_length(a: list[int]) -> int;

def mag_shl(a: list[int], bits: int) -> list[int];

def mag_shr(a: list[int], bits: int) -> list[int];

def mag_low_bits_nonzero(a: list[int], bits: int) -> bool;

def mag_divmod(a: list[int], b: list[int]) -> tuple[list[int], list[int]];

def mag_decimal_digits(a: list[int]) -> str;

def mag_to_pow2_str(a: list[int], bits_per_digit: int) -> str;

def mag_parse_digits(text: str, base: int) -> (list[int] | None);

def digit_value(ch: str) -> int;

def mag_pow2(bits: int) -> list[int];

def mag_isqrt(n: list[int]) -> list[int];

def mag_gcd(a: list[int], b: list[int]) -> list[int];

def twos_limbs(neg: bool, mag: list[int], width: int) -> list[int];

def twos_to_signed(limbs: list[int], neg: bool) -> tuple[bool, list[int]];
