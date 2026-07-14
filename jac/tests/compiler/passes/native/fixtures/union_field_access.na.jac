"""Native union / tuple-trigger field access (issue #6470).

Field access on a union-typed value must lower to a real field load on the
native backend, matching py/sv -- not silently truncate the enclosing body.

Two shapes exercise the same gap:
  - `get_val(x: A | B)`         -- a `|` union on a free-function parameter.
  - `with (Sub, Other) entry`   -- a tuple trigger gives `here` a union type.

Both union members carry `val` at the same offset, so `x.val` / `here.val`
is resolvable via either member's layout.
"""

obj A { has val: int; }
obj B { has val: int; }

def get_val(x: A | B) -> int {
    return x.val;
}

node Sub { has val: int; }
node Other { has val: int; }

walker W {
    has either: int = 0;
    can on_either with (Sub, Other) entry {
        self.either = self.either + here.val;
    }
}
