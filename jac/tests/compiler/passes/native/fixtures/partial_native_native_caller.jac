# Workstream A4 (#6930): a native caller of a method demoted to Python-only.
#
# `Box.evaluate` (uses `eval`) is demoted to Python-only, but here a *native*
# free function calls it. The native pathway cannot fall back to Python
# mid-stream, so the caller cascades into a seam of its own (granular
# demotion, epic #8201) and the module entry that calls it surfaces a loud
# E5092 rather than silently dropping to a null result.
obj Box {
    has raw: str;

    def length -> int {
        return len(self.raw);
    }  # native-eligible

    def evaluate -> int {
        return eval(self.raw);
    }  # demoted to Python-only
}

def call_evaluate(s: str) -> int {
    b = Box(raw=s);
    return b.evaluate();  # native call to a Python-only method -> cascade seam
}

with entry {
    print(call_evaluate("1"));
}
