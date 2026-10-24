impl GlobalCell.init(self: GlobalCell, namespace: dict[str, object], name: str) {
    self.namespace = namespace;
    self.name = name;
}

impl PassLink.init(self: PassLink, cell: (types.CellType | GlobalCell)) {
    self.cell = cell;
}

impl PassLink.of_local(probe: types.FunctionType) -> PassLink {
    closure = probe.__closure__;
    assert closure , "a pass link probe reads exactly one enclosing local";
    return PassLink(closure[0]);
}

impl PassLink.of_global(namespace: dict[str, object], name: str) -> PassLink {
    return PassLink(GlobalCell(namespace, name));
}

impl PassLink.put(self: PassLink, value: object) -> object {
    self.cell.cell_contents = value;
    return value;
}

impl PassLink.detach(self: PassLink) -> None {
    try {
        value = self.cell.cell_contents;
    } except (ValueError, NameError) {
        self.cell = types.CellType();
        return;
    }
    self.cell = types.CellType(value);
}
