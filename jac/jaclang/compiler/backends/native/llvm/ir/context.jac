import jaclang.compiler.backends.native.llvm.ir._utils as _utils;
import jaclang.compiler.backends.native.llvm.ir.types as types;

class Context {
    has scope: _utils.NameScope,
        identified_types: dict[str, types.IdentifiedStructType];

    def init(self: Context) {
        self.scope = _utils.NameScope();
        self.identified_types = {};
    }

    def get_identified_type(
        self: Context, name: str, packed: bool = False
    ) -> types.IdentifiedStructType {
        ty = self.identified_types.get(name);
        if ty is None {
            self.scope.register(name);
            ty = types.IdentifiedStructType(self, name, packed);
            self.identified_types[name] = ty;
        }
        return ty;
    }
}

glob global_context: Context = Context();
