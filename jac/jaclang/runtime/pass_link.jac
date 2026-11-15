import types;

class GlobalCell {
    static has __slots__: tuple[str, ...] = ("namespace", "name");
    has namespace: dict[str, object],
        name: str;

    def init(self: GlobalCell, namespace: dict[str, object], name: str);

    has cell_contents: object {
        getter {
            if self.name not in self.namespace {
                raise NameError(f"name '{self.name}' is not defined");
            }
            return self.namespace[self.name];
        }
        setter(self: GlobalCell, value: object) {
            self.namespace[self.name] = value;
        }
        deleter {
            del self.namespace[self.name];
        }
    }
}

class PassLink {
    static has __slots__: tuple[str, ...] = ("cell", );
    has cell: (types.CellType | GlobalCell);

    def init(self: PassLink, cell: (types.CellType | GlobalCell));
    static def of_local(probe: types.FunctionType) -> PassLink;
    static def of_global(namespace: dict[str, object], name: str) -> PassLink;
    def put(self: PassLink, value: object) -> object;
    def detach(self: PassLink) -> None;
}
