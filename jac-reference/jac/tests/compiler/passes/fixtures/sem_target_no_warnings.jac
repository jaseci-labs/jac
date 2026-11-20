"""Test: sem targets must not produce spurious W1051/W2001 warnings.

`sem Foo.field = "..."` is a dotted-name path, not a field access. The Name
nodes inside `SemDef.target` should resolve via the symbol-table walk done
by SemDefMatchPass — not be treated as standalone module-scope expressions.
"""
obj Ingredient {
    has name: str,
        cost: float,
        carby: bool;
}

sem Ingredient.cost = "Estimated cost in USD";
sem Ingredient.carby = "True if this ingredient is high in carbohydrates";

obj Outer {
    obj Inner {
        has tag: str;
    }
}

sem Outer.Inner.tag = "Tag string for the inner object.";
