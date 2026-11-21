import from base.util { Pair, twice, label }
import from core.beta { BetaBox }

obj AlphaBox {
    has n: int = 0;

    def pair -> Pair {
        return Pair(a=self.n, b=twice(self.n));
    }

    def name -> str {
        return label(self.pair());
    }

    def peer_beta -> BetaBox {
        return BetaBox(n=self.n + 1);
    }
}

def make_alpha(n: int) -> AlphaBox {
    return AlphaBox(n=n);
}

def:pub total_alpha(n: int) -> int {
    return make_alpha(n).pair().total();
}

def:pub name_alpha(n: int) -> str {
    return make_alpha(n).name();
}
