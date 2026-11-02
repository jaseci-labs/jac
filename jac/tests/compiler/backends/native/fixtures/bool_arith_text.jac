"""Arithmetic on bools, and sized integers, rendered as text."""

def sum_fstring(x: int) -> str {
    return f"{(x > 1) + (x > 0)}|{(x > 1) - (x > 2)}|{(x > 0) + (x > 1) + (x > 2)}";
}

def mixed_fstring(x: int) -> str {
    b = x > 1;
    return f"{b * 3}|{2 + b}|{b // 1}|{b % 2}|{b << 2}|{b + 0.5}";
}

def unary_fstring(x: int) -> str {
    b = x > 1;
    return f"{-b}|{+b}|{~(b + b)}|{abs(b)}|{-(x > 0) - (x > 1)}";
}

def bitwise_fstring(x: int) -> str {
    b = x > 1;
    c = x > 2;
    return f"{b & c}|{b | c}|{b ^ c}|{(x > 0) & (x < 3)}|{b & 1}|{b | 2}";
}

def spec_fstring(x: int) -> str {
    b = x > 1;
    return f"[{b + b:3}]|[{-b:+d}]|[{(x > 0) + b:x}]|[{b + (x > 0):.1f}]";
}

def text_calls(x: int) -> str {
    b = x > 1;
    c = x > 2;
    parts = [str(b + c), str(-b), str(b & c), repr(~(b + c)), repr(b ^ c), str(abs(c))];
    return "|".join(parts);
}

def local_text(x: int) -> str {
    b = x > 1;
    c = x > 2;
    s = b + b;
    n = -c;
    t = b | c;
    k = 0;
    k += b + c;
    return f"{s}|{n}|{t}|{k}|" + str(s) + "|" + str(t);
}

def sized_fstring(x: int) -> str {
    a: i32 = i32(x) - 3;
    u: u8 = u8(x + 200);
    h: i16 = i16(x) * -7;
    w: u32 = u32(x) + 4000000000;
    return f"{a}|{u}|{h}|{w}|{a + a}|{u:5}|{h:>6}|{w:x}";
}
