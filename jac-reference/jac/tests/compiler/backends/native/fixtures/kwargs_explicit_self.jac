"""Fixture: a variadic method whose signature spells `self` out.

`TypeCheckPass.emit` is declared this way -- an explicit `self`, declared
parameters after it and a `**kwargs` sink -- and that is the only shape the
binder counted the receiver twice for. The call supplies the receiver as
argument zero, and the parameter list still holds the `self` that names it,
so every slot after it sat one past where it belonged: the sink was looked
for one argument past the end of the callee and the call refused.

`Plain.note` asks the same question with `self` left implicit, which is why
the fault stayed invisible -- that list never held the receiver, so its
slots were already right.
"""

class Spelled {
    def note(self: Spelled, base: int, scale: int = 1, **kw: int) -> int {
        out = (base * scale) + (len(kw) * 100);
        if "p" in kw {
            out += 1000;
        }
        if "q" in kw {
            out += 2000;
        }
        return out;
    }

    def forward(self: Spelled, base: int, **kw: int) -> int {
        return self.note(base, **kw);
    }
}


class Plain {
    def note(base: int, scale: int = 1, **kw: int) -> int {
        out = (base * scale) + (len(kw) * 100);
        if "p" in kw {
            out += 1000;
        }
        return out;
    }
}


def spelled_literal -> int {
    return Spelled().note(5, p=1, q=2);
}


def spelled_defaulted -> int {
    return Spelled().note(7);
}


def spelled_scaled -> int {
    return Spelled().note(7, 3, p=1);
}


def spelled_forwarded -> int {
    return Spelled().forward(4, q=2);
}


def plain_literal -> int {
    return Plain().note(5, p=1);
}


def run -> int {
    print(spelled_literal());
    print(spelled_defaulted());
    print(spelled_scaled());
    print(spelled_forwarded());
    print(plain_literal());
    return 0;
}


with entry {
    run();
}
