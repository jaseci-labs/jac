"""A fresh object wrapped into an optional keeps the wrap alive.

`TABLE.append(Item(...))` into a `list[Item | None]` wraps the fresh
object in an optional that takes its ownership, then reads the payload
back out to store it. The RC pass derives each value from the value it was
made from and kept only the chain's root alive across the derived uses;
once the optional wrap joined that chain, the root was the already-moved
object, so the owning optional was released before the store and the list
held freed memory. Every value on the chain now lives as long as what is
derived from it.
"""

import from pathlib { Path }
import from tests.support { assert_native_identity }

glob FIXTURES = Path(__file__).resolve().parent / "fixtures";

test "a fresh object appended as an optional stays alive" {
    out = assert_native_identity(
        str(FIXTURES / "optional_wrap_owned.jac"), profiles=["rc", "managed"]
    );
    assert "1,-,7 1 8\n" == out , out;
}
