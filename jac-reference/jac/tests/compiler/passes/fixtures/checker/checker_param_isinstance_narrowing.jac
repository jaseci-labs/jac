"""Tests for isinstance narrowing on function/method parameters.

Parameters typed as a base class (e.g., `object`) should be narrowable
via isinstance checks, just like union-typed local variables.  The key
scenario is narrowing surviving through BoolExpr (and/or) short-circuit
CfgExpr chains inside the guarded block.
"""

obj Animal {
    has name: str;
}

obj Dog(Animal) {
    has name: str;

    def bark -> str {
        return "woof";
    }
}

# 1. isinstance narrowing of `object`-typed parameter — simple access
def test_param_object_narrowing(other: object) -> str {
    if isinstance(other, Dog) {
        return other.bark();  # <-- Ok after narrowing (Dog)
    }
    return "not a dog";
}

# 2. isinstance narrowing of base-class parameter to subclass
def test_param_base_class_narrowing(animal: Animal) -> str {
    if isinstance(animal, Dog) {
        return animal.bark();  # <-- Ok after narrowing (Dog)
    }
    return animal.name;
}

# 3. isinstance narrowing with BoolExpr (and) inside guarded block
#    This is the pattern that triggered the original bug: the `and`
#    creates CfgExpr short-circuit nodes that must be transparent to
#    the backward narrowing walk.
obj Anchor {
    has id: int;

    def __eq__(other: object) -> bool {
        if isinstance(other, Anchor) {
            return (self.id == other.id) and isinstance(other, Anchor);  # <-- Ok
        }
        return False;
    }
}

# 4. isinstance narrowing with BoolExpr in a separated impl block
obj Container {
    has value: int;

    def equals(other: object) -> bool;
}

impl Container.equals(other: object) -> bool {
    if isinstance(other, Container) {
        return (self.value == other.value) and isinstance(other, Container);  # <-- Ok
    }
    return False;
}

# 5. Negative case: accessing attribute WITHOUT isinstance guard should error
def test_no_guard(other: object) -> str {
    return other.bark();  # <-- Error: object has no attribute "bark"
}
