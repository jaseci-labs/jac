"""Member-level access encapsulation (OOP axis).

pub    -> accessible anywhere
protect -> accessible in the declaring class and its subclasses
priv   -> accessible only inside the declaring class
"""

obj Base {
    has :pub pub_f: int = 0;
    has :protect prot_f: int = 0;
    has :priv priv_f: int = 0;

    def :pub pub_m() -> int { return 1; }
    def :priv priv_m() -> int { return 2; }

    def own() -> None {
        a = self.pub_f;     # ok
        b = self.prot_f;    # ok
        c = self.priv_f;    # ok -- declaring class
        d = self.priv_m();  # ok -- declaring class
    }
}

obj Derived(Base) {
    def sub() -> None {
        a = self.pub_f;     # ok
        b = self.prot_f;    # ok -- subclass may see protected
        c = self.priv_f;    # VIOLATION -- private not visible in subclass
        d = self.priv_m();  # VIOLATION -- private method not visible in subclass
    }
}

with entry {
    base = Base();
    p = base.pub_f;      # ok
    q = base.pub_m();    # ok
    r = base.prot_f;     # VIOLATION -- protected outside class hierarchy
    s = base.priv_f;     # VIOLATION -- private outside class
}
