"""Bug: isinstance narrowing not applied when the narrowed expression is a non-Name target.

Root cause: In the case uni.AtomTrailer() handler in _get_type_of_expression_core,
the narrowed type was only applied when expr.target was a simple Name node.
For complex targets like c.pet (another AtomTrailer), get_narrowed_type_for_expr
was not called at all, so base_type stayed as the full union.

Fix: Added an elif branch in the AtomTrailer handler that calls
get_narrowed_type_for_expr for non-Name targets and uses the returned narrowed type.

All functions below should produce 0 errors after the fix.
"""

obj Cat {
    has meow: str = "";
}

obj Dog {
    has bark: str = "";
}

obj Container {
    has pet: Cat | Dog = Cat();
}

# isinstance on c.pet (AtomTrailer target) should narrow c.pet from
# Cat|Dog to Cat, allowing .meow access.
def get_meow(c: Container) -> str {
    if isinstance(c.pet, Cat) {
        return c.pet.meow;  # c.pet: Cat
    }
    return "";
}

# elif branch: each isinstance narrows c.pet to the checked type.
def describe_pet(c: Container) -> str {
    if isinstance(c.pet, Cat) {
        return c.pet.meow;   # c.pet: Cat
    } elif isinstance(c.pet, Dog) {
        return c.pet.bark;   # c.pet: Dog
    }
    return "unknown";
}
