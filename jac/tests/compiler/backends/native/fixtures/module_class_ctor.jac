"""Native lowering of `module.Class(...)` for a class-form archetype.

A class-form archetype named through a module alias is a class reference,
exactly like one named through an object-form archetype's module alias: the
call constructs it directly instead of going through the runtime
class-value constructor table.
"""
import module_class_ctor_lib as lib;

class Holder {
    has scope: lib.Scope,
        kind: lib.Kind;

    def init(self: Holder) {
        self.scope = lib.Scope();
        self.kind = lib.IntKind(8);
    }

    def total(self: Holder) -> int {
        return self.scope.count() + self.kind.width();
    }
}

def module_class_ctor_probe -> int {
    first: lib.Kind = lib.IntKind(16);
    second = lib.IntKind(32);
    holder = Holder();
    return first.width() + second.width() + holder.total();
}
