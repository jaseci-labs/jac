class DuplicatedNameError(NameError) {}

class NameScope {
    has _useset: set[str],
        _basenamemap: dict[str, int];

    def init(self: NameScope) {
        self._useset = {''};
        self._basenamemap = {};
    }

    def is_used(self: NameScope, name: str) -> bool {
        return (name in self._useset);
    }

    def register(self: NameScope, name: str, deduplicate: bool = False) -> str {
        if deduplicate {
            name = self.deduplicate(name);
        } elif self.is_used(name) {
            raise DuplicatedNameError(name);
        }
        self._useset.add(name);
        return name;
    }

    def deduplicate(self: NameScope, name: str) -> str {
        basename = name;
        while self.is_used(name) {
            ident = self._basenamemap.get(basename, 0) + 1;
            self._basenamemap[basename] = ident;
            name = f"{basename}.{ident}";
        }
        return name;
    }
}
