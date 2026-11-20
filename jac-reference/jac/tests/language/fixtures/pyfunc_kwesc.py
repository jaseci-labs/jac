def foo(type: int = 90) -> int:
    """This is a function with a docstring."""
    return type


print(foo(type=89))


def bar(node: int = 12, *args: object, **kwargs: object) -> tuple:
    """This is another function with a docstring."""
    return node, args, kwargs


print(str(bar(node=13, a=1, b=2)))


functions = [
    {
        "name": "replace_lines",
        "args": [
            {"name": "text", "type": "str", "default": None},
            {"name": "old", "type": "str", "default": None},
            {"name": "new", "type": "str", "default": None},
        ],
        "returns": {"type": "str", "default": None},
    },
]

print(f"Functions: {functions}")

dict = 90
print(f"Dict: {dict}")
