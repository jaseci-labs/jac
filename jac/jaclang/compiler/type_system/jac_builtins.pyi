# Module-level dunders injected by Python's import system.
# mypy already knows about these in .pyi files, so we suppress redefinition
# warnings; the Jac type checker needs them declared explicitly here.
__name__: str  # type: ignore[no-redef]
__file__: str | None  # type: ignore[no-redef]
__doc__: str | None  # type: ignore[no-redef]
__package__: str | None  # type: ignore[no-redef]
__spec__: object  # type: ignore[no-redef]

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
