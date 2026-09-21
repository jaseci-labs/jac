class Holder[T] {
    def get(self: Holder) -> T;
}

class Fwd(Holder[Later]) {}

class Later(Holder[int]) {}

class Selfy(Holder[Selfy]) {}

def probe(f: Fwd, l: Later, s: Selfy, text: str) {
    a: int = f.get();
    b: str = l.get();
    c: int = s.get();
    d: int = sorted(text);
    e: int = list(text);
}
