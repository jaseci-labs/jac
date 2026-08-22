# Workstream A4/W4 (#6930): an un-lowerable *virtual* method demotes to an
# abort-stub vtable slot.
#
# `render` is virtual (Base defines it, Derived overrides it -> vtable slot).
# The stub keeps the slot valid: native dispatch that reaches it aborts
# loudly instead of dispatching to garbage, the method is excluded from the
# exported native layout, and the rest of the class stays native.
obj Base {
    has raw: str;

    def render -> int {
        return len(self.raw);
    }  # native-eligible
}

obj Derived(Base) {
    def render -> int {
        return eval(self.raw);
    }  # virtual + un-lowerable
}

def use(s: str) -> int {
    items: list[Base] = [Derived(raw=s)];
    return items[0].render();
}

with entry {
    print(use("1"));
}
