"""Subclasses defined by an importer satisfy isinstance checks compiled in
the module that defines their base."""

import from shapes { Base, Mid, Plain, is_base, is_mid, is_plain, base_is_mid }

obj Child(Base) {
    has name: str = "child";
}

obj Leaf(Mid) {}

obj Loose {
    has count: int;
}

with entry {
    child: own Child = Child(level=1);
    leaf: own Leaf = Leaf(level=2, depth=3);
    loose: own Loose = Loose(count=4);
    plain: own Plain = Plain(tag=5);
    base: own Base = Base(level=6);
    print(is_base(&child), is_mid(&child), is_plain(&child));
    print(is_base(&leaf), is_mid(&leaf), is_plain(&leaf));
    print(is_base(&loose), is_mid(&loose), is_plain(&loose));
    print(is_base(&plain), is_mid(&plain), is_plain(&plain));
    print(is_base(&base), is_mid(&base));
    print(base_is_mid(&child), base_is_mid(&leaf), base_is_mid(&base));
    print(isinstance(child, Base), isinstance(leaf, Mid), isinstance(loose, Base));
}
