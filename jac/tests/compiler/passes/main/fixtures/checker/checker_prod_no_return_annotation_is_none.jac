"""Production test: Functions without return annotation must infer as -> None.

In Jac, omitting the return type annotation is equivalent to -> None.
This is a deliberate syntax design decision for functions that don't
return values. The type checker must treat the return type as None,
NOT as UnknownType.

Currently, the type checker assigns UnknownType to functions without
return annotations (construct_types.impl.jac line 96 defaults to
UnknownType when no return type expression exists in FuncSignature).

Expected errors: 4
  1. bad1: int = no_ret_result     — None not assignable to int
  2. bad2: str = no_ret_result     — None not assignable to str
  3. bad3: list = no_ret_result    — None not assignable to list
  4. bad4: int = obj_result        — None not assignable to int
"""

def side_effect() {
    x = 42;
}

obj Foo {
    has x: int = 0;

    def mutate() {
        self.x = 10;
    }
}

with entry {
    no_ret_result = side_effect();

    # side_effect() has no return annotation -> should be None
    # These should all error: None is not assignable to int/str/list
    bad1: int = no_ret_result;     # Error: None -> int
    bad2: str = no_ret_result;     # Error: None -> str
    bad3: list = no_ret_result;    # Error: None -> list

    # Same for methods without return annotation
    f = Foo();
    obj_result = f.mutate();
    bad4: int = obj_result;        # Error: None -> int
}
