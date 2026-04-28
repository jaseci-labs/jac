"""Regression fixture: @dataclass class with fields in a 'with entry' block.

When a @dataclass class is declared inside a function body using the 'class'
keyword, and its fields are written inside a 'with entry' block, the type
checker should recognize those fields correctly.

Three bugs were present:
  1. Local 'class' (Ability node) was not recognized as a dataclass even with
     @dataclass decorator - constructor returned NoneType instead of the class type.
  2. Fields declared inside 'with entry' lived in a nested WithStmt scope,
     not in the Ability's own scope - _build_field_params missed them.
  3. lookup_member_symbol did not walk WithStmt children, so attribute access
     on instances failed with E1030.

Bonus: _build_field_params was scanning base classes including 'object', picking
up __doc__, __module__, __annotations__ as fake dataclass fields.

This fixture must produce 0 errors. Before the fix it produced E1030 and E1001
errors on result.is_match and result.value.
"""

import from dataclasses { dataclass }

def test_local_dataclass() -> None {
    @dataclass
    class MyResult {
        with entry {
            is_match: bool = False;
            value: (str | None) = None;
        }
    }

    result = MyResult();
    x: bool = result.is_match;
    y: (str | None) = result.value;
}

@dataclass
class ModuleLevelResult {
    with entry {
        count: int = 0;
        label: str = "";
    }
}

def test_module_level_dataclass() -> None {
    r = ModuleLevelResult();
    n: int = r.count;
    s: str = r.label;
}
