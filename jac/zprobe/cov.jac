obj D {}
obj E(D) {}
obj B {
    def m() -> D { return D(); }
    static def s() -> D { return D(); }
}
obj C(B) {
    def m() -> E { return E(); }
    static def s() -> E { return E(); }
}

obj BadRet(B) {
    def m() -> int { return 1; }
}

obj Animal {}
obj Dog(Animal) {}
obj Cat(Animal) {}

def kind(a: Dog | Cat) -> str {
    match a {
        case Animal():
            return "animal";
    }
}
