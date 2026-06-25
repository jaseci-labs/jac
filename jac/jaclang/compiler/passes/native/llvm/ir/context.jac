import from jaclang.compiler.passes.native.llvm.ir { _utils }
import from jaclang.compiler.passes.native.llvm.ir { types }
class Context(object) {
    def init(self: Context) -> object {
        self.scope = _utils.NameScope();
        self.identified_types = {};
    }
    def get_identified_type(self: Context, name: Any, packed: Any = False) -> object {
        if (name not in self.identified_types) {
            self.scope.register(name);
            ty = types.IdentifiedStructType(self, name, packed);
            self.identified_types[name] = ty;
        } else {
            ty = self.identified_types[name];
        }
        return ty;
    }
}
with entry {
    global_context = Context();
}

