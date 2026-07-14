"""Regression fixture for issue #6688: `for (k, v) in d.items()` must not
over-release the dict's key/val.

`__dict_get_key` / `__dict_get_val` hand back BORROWED pointers into the dict's
backing arrays. The items loop binds them to pointer locals (`k`, `v`) which the
enclosing function's scope-exit cleanup releases -- so without a matching
per-iteration retain the dict's last key+val are over-released, freeing their
heap backing under the still-live dict. A later read then sees freed (and reused)
memory: the class of use-after-free that lands a dangling `char*` into a C-FFI
call in a long-running native OSP loop.

`verify_items_rc` forces the latent bug to surface deterministically: it drains a
dict (with RUNTIME-built heap strings) once via `.items()` in a helper -- so the
over-release fires at the helper's scope exit while the dict, owned by the
caller, stays alive -- then churns same-size allocations to reuse the freed
block, and reads the value back. With the bug the readback is corrupted; with the
fix it still equals the original. Returns 1 when intact, 0 when corrupted, so the
test asserts a stable result regardless of what bytes the reused block held."""

def drain_items(d: dict[str, str]) -> int {
    # `d` is a borrowed param; iterating its items must not steal a reference
    # from the dict's own key/val storage.
    n = 0;
    for (k, v) in d.items() {
        n = n + len(k);
    }
    return n;
}

def verify_items_rc() -> int {
    d: dict[str, str] = {};
    # Runtime-built (heap) key + value, NOT static literals (statics are immortal
    # and immune to RC over-release).
    d["dkey" + "0001"] = "dval" + "0002";
    # Drain once in a helper: the buggy items loop over-releases the value at the
    # helper's scope exit -> rc 1 -> 0 -> the "dval0002" backing is freed while
    # the caller's dict `d` is still alive.
    drain_items(d);
    # Churn same-size allocations so the freed value block is reused/overwritten.
    i = 0;
    while i < 256 {
        junk = "wrck" + str(1000 + i);
        i = i + 1;
    }
    # Read the value back. Intact => "dval0002"; corrupted => reused junk bytes.
    ok = 1;
    for (k, v) in d.items() {
        if v != "dval0002" {
            ok = 0;
        }
    }
    return ok;
}

with entry {
    print(verify_items_rc());
}
