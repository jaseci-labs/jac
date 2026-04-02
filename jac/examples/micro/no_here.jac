"""Not focusing on the self is cleaner."""

obj MyObj {
    has a: int;

    def init(a: int) {
        self.a = a;
    }

    def set_a(val: int) {
        self.a = val;
    }
}
