# na cliff: str concat drops NUL, len() is strlen. jac-py core site: bytes_to_str
# builds a str from bytes incl NUL. Memory: na-chr-concat-drops-nul,
# na-len-strlen-binary-guard.
def build -> str {
    s = "";
    s = s + chr(0);
    s = s + chr(65);
    return s;
}

def use -> int {
    return len(build());
}

with entry {
    print(use());
}
