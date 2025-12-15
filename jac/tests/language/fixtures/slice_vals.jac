obj MyObj {
    has a: Annotated[Str, INT, BLAH] = "a";

    def foo(edge_spec: tuple[int, Optional[type], Optional[tuple]]) -> Archetype;
}

impl MyObj.foo(edge_spec: tuple[int, Optional[type], Optional[tuple]]) -> Archetype { }
