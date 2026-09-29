"""An endpoint is a type position, so it admits a union like every other one."""
node Base {
    has tag: str = "";
}

node A(Base) {
    has av: int = 0;
}

node B(Base) {
    has bv: int = 0;
}

node C(Base) {
    has cv: int = 0;
}

edge Multi: Base --> A | B {}
edge Narrow: A | B --> C {}

with entry {
    origin = Base();
    a = A();
    b = B();
    c = C();
    origin +>:Multi:+> a;
    origin +>:Multi:+> b;
    a +>:Narrow:+> c;
    multi_out = [origin->:Multi:->];
    narrow_out = [a->:Narrow:->];
    narrow_in = [c<-:Narrow:<-];
    shared_field = multi_out[0].tag;
}
