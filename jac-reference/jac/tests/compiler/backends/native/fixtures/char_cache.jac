"""Single-character access should hit the immortal __jac_chars cache, not
heap-allocate a fresh string per character.

`char_scan` iterates a string and `char_index` indexes it; both extract single
characters. The native backend serves each character from a shared 256-entry
static table (a CPython latin1-style cache), so neither function calls the RC
allocator for the character, and iterating a string never leaks. `combine`
proves a cached character still behaves as a real string (concat / length)."""

def char_scan(s: str) -> int {
    # Count 'o' by iterating characters and comparing each.
    n: int = 0;
    for c in s {
        if c == "o" {
            n = n + 1;
        }
    }
    return n;
}


def char_index(s: str, i: int) -> str {
    return s[i];
}


def combine(s: str) -> int {
    # A cached character is a real string: concatenate and measure.
    out: str = "";
    for c in s {
        out = out + c;
    }
    return len(out);
}
