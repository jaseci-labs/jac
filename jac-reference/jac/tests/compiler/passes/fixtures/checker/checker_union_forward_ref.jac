"""Union/Optional string forward refs resolve to types, not Literal[...]."""

import from typing { Union, Optional }

obj Foo {}
obj Bar {}

glob MyTypeTuple = Union[('Foo', 'Bar')];
glob MyTypeSingle = Union['Foo'];
glob MyTypeOptional = Optional['Foo'];

def make_tuple -> MyTypeTuple {
    return Foo();
}

def make_single -> MyTypeSingle {
    return Foo();
}

def make_optional -> MyTypeOptional {
    return Foo();
}
