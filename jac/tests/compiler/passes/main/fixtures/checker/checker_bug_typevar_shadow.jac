"""Bug #TVAR-5: Module-level TypeVars shadowed by class type parameters.

Module-level T (bound=int) should NOT be substituted with inherited str.
"""
import from typing { TypeVar }

class Transform[T] {
    def get_input(self: Transform) -> T;
}

class StrTransform(Transform[str]) {}

# Module-level T with bound=int (different from Transform's T)
glob T = TypeVar('T', bound=int);

class MyPass(StrTransform) {
    # Uses module-level T, NOT inherited T from Transform
    def sync(self: MyPass, value: T) -> T;
}

def test_typevar_shadow(p: MyPass) -> None {
    # Should NOT error - sync returns T (bound=int), not str
    check: int = p.sync(42);

    # Should work - get_input returns str (inherited)
    inherited_type: str = p.get_input();

    # Should error - str -> int
    bad_inherited: int = p.get_input();
}
