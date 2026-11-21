"""Fixture for E0076: `__init__` and `init` are distinct Python methods.

Mirrors Pillow's `PIL.ImageFile.PyCodec` shape (issue #6556): a class with
both a real constructor and a plain method named `init` is valid Python and
must not be flagged as a duplicate method when raised into Jac's uniir.
"""


class PyCodec:
    def __init__(self, mode: str) -> None:
        self.mode = mode
        self.args: tuple | None = None

    def init(self, args: tuple) -> None:
        self.args = args
