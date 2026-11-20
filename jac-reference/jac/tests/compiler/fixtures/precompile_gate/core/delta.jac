import from base.util { Pair, twice, label }

obj DeltaBox {
    has n: int = 3;

    def pair -> Pair {
        return Pair(a=self.n, b=twice(self.n));
    }

    def name -> str {
        return label(self.pair());
    }
}

def make_delta(n: int) -> DeltaBox {
    return DeltaBox(n=n);
}

def:pub total_delta(n: int) -> int {
    return make_delta(n).pair().total();
}

def:pub name_delta(n: int) -> str {
    return make_delta(n).name();
}
