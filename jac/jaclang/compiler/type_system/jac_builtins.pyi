# typing.pyi file definitions for special forms
class Final: ...

# Core Jaclang builtin types
class Node: ...
class Walker: ...
class Root(Node): ...

# Fixed-width integer types
class i8(int): ...  # noqa: N801
class u8(int): ...  # noqa: N801
class i16(int): ...  # noqa: N801
class u16(int): ...  # noqa: N801
class i32(int): ...  # noqa: N801
class u32(int): ...  # noqa: N801
class i64(int): ...  # noqa: N801
class u64(int): ...  # noqa: N801

# Fixed-width float types
class f32(float): ...  # noqa: N801
class f64(float): ...  # noqa: N801

# JSX types for client-side rendering
class JsxElement:
    tag: object
    props: dict[str, object]
    children: list[object]
