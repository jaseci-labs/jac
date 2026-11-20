import from base.util { Pair, twice, label }
import from core.delta { DeltaBox }

obj GammaBox {
    has n: int = 2;

    def pair -> Pair {
        return Pair(a=self.n, b=twice(self.n));
    }

    def name -> str {
        return label(self.pair());
    }

    def peer_delta -> DeltaBox {
        return DeltaBox(n=self.n + 1);
    }
}

def make_gamma(n: int) -> GammaBox {
    return GammaBox(n=n);
}

def:pub total_gamma(n: int) -> int {
    return make_gamma(n).pair().total();
}

def:pub name_gamma(n: int) -> str {
    return make_gamma(n).name();
}
