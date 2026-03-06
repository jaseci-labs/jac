"""Bug #7: Protocol checking only compares method names, not signatures.

The class_implements_protocol function checks that all method names from
the protocol exist in the class, but does NOT verify that the signatures
match. This means a class with completely wrong method signatures can
satisfy a protocol.

Expected: MyClass should NOT satisfy Drawable because its draw() signature
is incompatible (takes int instead of str, returns str instead of None).
"""

import from typing { Protocol }

class Drawable(Protocol) {
    def draw(canvas: str) -> None;
}

obj WrongSignature {
    # draw exists but has completely wrong signature
    def draw(x: int) -> str {
        return "wrong";
    }
}

obj CorrectSignature {
    def draw(canvas: str) -> None { }
}

def render(item: Drawable) -> None {
    item.draw("canvas");
}

with entry {
    correct = CorrectSignature();
    render(correct);  # <-- Ok (correct signature)

    wrong = WrongSignature();
    render(wrong);  # <-- Should be Error (wrong signature) but passes due to name-only check
}
