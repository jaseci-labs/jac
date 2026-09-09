enum Hue { RED = "red", GREEN = "green", EMPTY = "" }

def probe(which: int) -> int {
    text = "red"
        if which == 0
        else "green" if which == 1 else "" if which == 2 else "bad";
    try {
        member = Hue(text);
        again = Hue(member);
        return 1 if member == again and member.value == text else 0;
    } except ValueError {
        return -1;
    }
}

with entry {
    assert probe(0) == 1;
    assert probe(1) == 1;
    assert probe(2) == 1;
    assert probe(3) == -1;
}
