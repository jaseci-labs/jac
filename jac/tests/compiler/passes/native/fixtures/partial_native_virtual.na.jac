# Workstream A4 (#6930): an un-lowerable *virtual* method is NOT demoted.
#
# `render` is virtual (Base defines it, Derived overrides it -> vtable slot).
# Native polymorphic dispatch cannot fall back to Python, so a virtual method
# the backend cannot lower must remain a hard error (E5090) instead of being
# demoted — which would leave a dangling vtable index / abort-stub slot.
obj Base {
    has raw: str;
    def render -> int { return len(self.raw); }      # native-eligible
}

obj Derived(Base) {
    def render -> int { return eval(self.raw); }      # virtual + un-lowerable
}

def use(s: str) -> int {
    items: list[Base] = [Derived(raw=s)];
    return items[0].render();
}

with entry { print(use("1")); }
