"""Regression fixture: decorated class declared inside a function body.

When a class declaration with a decorator (e.g. @dataclass) appears inside a
function body, the parser should emit an Archetype node, not an Ability node.
The wrong node type caused the type checker to return NoneType for the
constructor call and fail to find fields on instances.

This fixture must produce 0 type errors.
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
