import from base.util { Pair, twice, label }
import from core.gamma { GammaBox }

obj BetaBox {
    has n: int = 1;

    def pair -> Pair {
        return Pair(a=self.n, b=twice(self.n));
    }

    def name -> str {
        return label(self.pair());
    }

    def peer_gamma -> GammaBox {
        return GammaBox(n=self.n + 1);
    }
}

def make_beta(n: int) -> BetaBox {
    return BetaBox(n=n);
}

def:pub total_beta(n: int) -> int {
    return make_beta(n).pair().total();
}

def:pub name_beta(n: int) -> str {
    return make_beta(n).name();
}
