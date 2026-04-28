"""Minimal reproduction: @dataclass class with 'with entry' fields inside a function body.

Bug 1: 'class' keyword (SymbolType.TYPE) not treated as dataclass even with @dataclass decorator.
Bug 2: Fields declared inside 'with entry' block are not picked up by _build_field_params.

Expected: MyResult() call works, result.is_match and result.value are typed correctly.
Actual:   Type checker reports function-call / attribute errors.
"""

import from dataclasses { dataclass }

def test_func() -> None {
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

with entry {
    test_func();
}
