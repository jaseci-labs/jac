"""Union[('A', 'B')] should resolve strings as type names, not Literal["A"] | Literal["B"]."""

import from typing { Union }

glob MyType = Union[('Foo', 'Bar')];

obj Foo {}
obj Bar {}

def make -> MyType {
    return Foo();  # Error before fix: Cannot return Foo, expected Literal["Foo"] | Literal["Bar"]
}
