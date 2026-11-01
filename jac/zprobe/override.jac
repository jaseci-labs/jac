obj Base {
    has n: int = 0;
    def process(data: str, k: int = 1) -> int { return len(data) + k; }
}
obj Good(Base) {
    def process(data: str, k: int = 1) -> int { return len(data) * 2; }
}
obj BadSig(Base) {
    def process(data: int, k: int = 1) -> str { return str(data); }
}
obj BadDefault(Base) {
    def process(data: str, k: int = 2) -> int { return 0; }
}
obj BadField(Base) {
    has n: str = "";
}
