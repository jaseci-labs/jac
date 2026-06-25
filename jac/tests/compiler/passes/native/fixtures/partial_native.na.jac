# Workstream A4 (#6930): partial-native classes / per-method native opt-out.
#
# `Literal` mixes a native-eligible method (`length`) with one the native
# backend cannot lower (`evaluate`, which uses `eval`). The class must keep a
# native layout + native constructor + the lowerable method; the un-lowerable
# method is skipped (left to the Python implementation) instead of poisoning
# the whole module's native compile.
obj Literal {
    has raw: str;
    def length -> int { return len(self.raw); }     # native-eligible
    def evaluate -> int { return eval(self.raw); }   # eval -> NOT native, stays Python
}

"""Construct natively and call the native-eligible sibling method.

Native code only ever touches the native layout + the lowerable method; the
Python-only `evaluate` is never called from the native pathway.
"""
def measure(s: str) -> int {
    lit = Literal(raw=s);
    return lit.length();
}

with entry { print(measure("42")); }
