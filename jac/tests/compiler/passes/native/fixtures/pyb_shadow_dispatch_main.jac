"""Native subclasses over a self-dispatching Python-side base.

`Overrider` overrides `hook`, so calling the base's `dispatches` through the
shadow would run the base's `hook` instead -- the shadow class is built as
`type(name, (base,), {})` and carries none of `Overrider`'s bodies. That call
must refuse.

`Bystander` overrides nothing the base dispatches to, so the shadow's answer
and the native answer are the same body. Its calls must keep lowering, and so
must `Overrider`'s calls to base methods that reach nothing on `self`: the
refusal is about a specific divergence, not about having a Python-side base.
"""
import from pyb_shadow_dispatch_lib { DispatchBase }

obj Overrider(DispatchBase) {
    has seen: int = 0;

    """The override the shadow does not carry."""
    def hook(n: int) -> int {
        return n + 100;
    }
}


obj Bystander(DispatchBase) {
    has seen: int = 0;

    """An override of a name the base never dispatches to."""
    def unrelated(n: int) -> int {
        return n + 7;
    }
}


"""The defect: the base's `dispatches` would run the base's `hook`."""
def overridden_dispatch -> int {
    k = Overrider(seed=3);
    return k.dispatches(2);
}


"""The same hazard reached through a longer base body."""
def overridden_dispatch_twice -> int {
    k = Overrider(seed=3);
    return k.dispatches_twice(2);
}


"""Control: the base method reaches nothing on `self`."""
def overrider_calls_plain -> int {
    k = Overrider(seed=3);
    return k.plain(4);
}


"""Control: the base method reaches a module function, not `self`."""
def overrider_calls_free -> int {
    k = Overrider(seed=3);
    return k.calls_free(4);
}


"""Control: this subclass overrides nothing the base dispatches to."""
def bystander_dispatch -> int {
    k = Bystander(seed=3);
    return k.dispatches(2);
}


with entry {
    print(overridden_dispatch());
    print(overridden_dispatch_twice());
    print(overrider_calls_plain());
    print(overrider_calls_free());
    print(bystander_dispatch());
}
