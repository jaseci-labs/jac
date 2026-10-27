"""A `T | None` operand in an arithmetic/bitwise/shift operator is E1160.

Attribute access on `T | None` already errors (E1099) because member lookup
requires every union member to carry the attribute. Binary operators went
through magic-method resolution, which accepted a union as long as one
member answered, so `x + 1` on `int | None` type-checked and then crashed
at runtime on the None case. The operator path now rejects an un-narrowed
optional operand the same way, and augmented assignment does too.

`fail_` functions each raise exactly one E1160. `ok_` functions stay clean:
narrowing, equality against None, and `any` operands are all still fine.
"""

# ---------------------------------------------------------------------------
# fail_: an un-narrowed optional operand
# ---------------------------------------------------------------------------

def fail_add_left(x: int | None) -> int {
    return x + 1;
}

def fail_add_right(x: int, y: int | None) -> int {
    return x + y;
}

def fail_add_both(x: int | None, y: int | None) -> int {
    return x + y;
}

def fail_str_concat(s: str | None) -> str {
    return s + "!";
}

def fail_sub(x: float | None) -> float {
    return x - 1.0;
}

def fail_mul(x: int | None) -> int {
    return x * 2;
}

def fail_floordiv(x: int | None) -> int {
    return x // 2;
}

def fail_mod(x: int | None) -> int {
    return x % 2;
}

def fail_pow(x: int | None) -> int {
    return x ** 2;
}

def fail_bitand(x: int | None) -> int {
    return x & 1;
}

def fail_bitxor(x: int | None) -> int {
    return x ^ 1;
}

def fail_lshift(x: int | None) -> int {
    return x << 1;
}

def fail_rshift(x: int | None) -> int {
    return x >> 1;
}

def fail_list_concat(xs: list[int] | None) -> list[int] {
    return xs + [1];
}

def fail_aug_add(x: int | None) -> int {
    x += 1;
    return x;
}

def fail_aug_mul(x: int | None) -> int {
    x *= 3;
    return x;
}

def fail_union_receiver_format(fmt: str | int, value: str | None) -> str {
    return fmt % value;
}

# ---------------------------------------------------------------------------
# ok_: patterns that must stay clean
# ---------------------------------------------------------------------------

def ok_narrowed_is_not_none(x: int | None) -> int {
    if x is not None {
        return x + 1;
    }
    return 0;
}

def ok_narrowed_early_return(x: int | None) -> int {
    if x is None {
        return 0;
    }
    return x + 1;
}

def ok_narrowed_truthiness(x: int | None) -> int {
    if x {
        return x + 1;
    }
    return 0;
}

def ok_narrowed_or_default(x: int | None) -> int {
    v = x if x is not None else 0;
    return v + 1;
}

def ok_plain_int(x: int) -> int {
    return x + 1;
}

def ok_non_optional_union(x: int | float) -> float {
    return x + 1;
}

def ok_equality_against_none(x: int | None) -> bool {
    return x == None or x != None;
}

def ok_any_operand(x: any, y: int) -> int {
    return x + y;
}

def ok_aug_after_narrowing(x: int | None) -> int {
    if x is None {
        x = 0;
    }
    x += 1;
    return x;
}

# An attribute whose only visible assignment is None infers as bare NoneType,
# not as a union. Callers set it dynamically, so the guard below is real and
# the operand is not an un-narrowed optional. Only a union carrying None is.
class DynamicAttr {
    def init(self: DynamicAttr) {
        self.align = None;
    }

    def ok_bare_none_attr_render(self: DynamicAttr) -> str {
        if self.align is not None {
            return "align %d" % self.align;
        }
        return "";
    }
}

def ok_str_format_optional(x: str | None) -> str {
    return "%s" % x;
}

def ok_str_format_optional_aug(x: str | None) -> str {
    s = "%s";
    s %= x;
    return s;
}

def ok_any_member_receiver_format(fmt: str | any, value: str | None) -> str {
    return fmt % value;
}
