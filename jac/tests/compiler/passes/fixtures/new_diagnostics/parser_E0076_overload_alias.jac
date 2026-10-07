"""Fixture for E0076: aliased `typing.overload` stubs are not duplicate methods.

Mirrors torch's `SymBool` (`torch/__init__.py` imports `overload as _overload`):
the decorated stubs declare the signatures of the one real `__eq__`, so the
duplicate-method check must recognise the name the module bound the decorator
to, and the `typing.overload` attribute form, not only the spelling `overload`.
"""

import typing as t;
import from typing { overload as _overload }

obj SymBool {
    @_overload
    def __eq__(other: SymBool) -> SymBool { }  # <-- Ok: overload stub
    @_overload
    def __eq__(other: object) -> bool { }  # <-- Ok: overload stub
    def __eq__(other: object) -> bool {  # <-- Ok: the one real definition
        return self is other;
    }

    @t.overload
    def __ne__(other: SymBool) -> SymBool { }  # <-- Ok: overload stub
    @t.overload
    def __ne__(other: object) -> bool { }  # <-- Ok: overload stub
    def __ne__(other: object) -> bool {  # <-- Ok: the one real definition
        return self is not other;
    }
}
