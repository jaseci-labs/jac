node B {
    def __mul__(other: B) -> int {
        return 0;
    }
}

node A {
    def __add__(other: A) -> B {
        return B();
    }
}

glob a: A = A(),
     r1: B = a + a,  # <-- Ok
     r2: A = a + a,  # <-- Error
     r3: int = (a + a) * B(),  # <-- Ok
     r4: str = (a + a) * B(),  # <-- Error
     l: list = ["a", "b", "c"];

with entry {
    ''.join(l) + 'alpha';  # <-- Ok
    'beta' + ''.join(l);  # <-- Ok
    ''.join(l) + ''.join(l);  # <-- Ok
}
