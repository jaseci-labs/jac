"""An isinstance arm naming an ABC with no exact reduction over native values.

`Iterable` is inhabited by anything with `__iter__`, which an archetype can have
without ever naming `Iterable`. Reducing it to the builtin containers would
therefore answer `False` for such an archetype, which is wrong rather than
merely incomplete -- so the backend refuses this arm instead of guessing.
"""

def chk(k: int) -> int {
    x: any = [1, 2];
    if k == 1 {
        x = 5;
    }
    if isinstance(x, Iterable) {
        return 1;
    }
    return 0;
}
