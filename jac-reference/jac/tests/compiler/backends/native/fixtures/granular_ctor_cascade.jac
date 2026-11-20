"""Fixture: constructing a class whose constructor demoted is loud (#8234).

`Maker.build` instantiates `Late`, whose `postinit` is a capability seam,
so the construction site has no initializer to call. It must refuse with
E5092 and cascade `Maker.build` into a seam of its own rather than build a
half-initialized object. `Late` is declared after `Maker` deliberately: the
refusal must not depend on which archetype the backend lowers first.
"""

obj Maker {
    def build -> int {
        made = Late();
        return made.n;
    }

    def pure(x: int) -> int {
        return x * 3;
    }
}

obj Late {
    has n: int = 0;

    def postinit {
        import collections;
        self.n = len(collections.OrderedDict());
    }
}

with entry {
    print(Maker().pure(2));
}
