import from enum { StrEnum }

enum Hue { RED = "red", GREEN = "green", EMPTY = "" }

class Tokens(StrEnum) {
    A = "a";
    B = "b";
}

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

def by_name(which: int) -> int {
    name = "GREEN" if which == 0 else "B" if which == 1 else "red";
    try {
        if which == 1 {
            return 1 if Tokens[name].value == "b" and Tokens["A"].value == "a" else 0;
        }
        return 1 if Hue[name] == Hue.GREEN and Hue["RED"] == Hue.RED else 0;
    } except KeyError {
        return -1;
    }
}

with entry {
    assert probe(0) == 1;
    assert probe(1) == 1;
    assert probe(2) == 1;
    assert probe(3) == -1;
    assert by_name(0) == 1;
    assert by_name(1) == 1;
    assert by_name(2) == -1;
}
