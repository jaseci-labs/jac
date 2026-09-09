obj Inner {
    has n: int = 0;

    def bump {
        self.n += 1;
    }
}

obj Outer {
    has child: own Inner = Inner();

    def bump {
        self.child.bump();
    }
}

def observe(x: &Outer) {
    x.bump();
}
with entry {
    x: own Outer = Outer();
    observe(&x);
    print(x.child.n);
}
