def keep_path(rel: str) -> str {
    return rel;
}

def shout(rel: str) -> str {
    return rel.upper();
}

obj Catalog {
    has path_mapper: Callable[[str], str] | None = None,
        mapper: Callable[[str], str] postinit;

    def postinit {
        self.mapper = self.path_mapper if self.path_mapper is not None else keep_path;
    }

    def map(rel: str) -> str {
        return self.mapper(rel);
    }
}

def pick(loud: bool) -> Callable[[str], str] {
    chosen: Callable[[str], str] = shout if loud else keep_path;
    return chosen;
}

def:pub ternary_default_function -> int {
    return 1 if Catalog().map("abc") == "abc" else 0;
}

def:pub ternary_given_function -> int {
    return 1 if Catalog(path_mapper=shout).map("abc") == "ABC" else 0;
}

def:pub ternary_between_functions -> int {
    return (1 if pick(True)("q") == "Q" else 0) + (2 if pick(False)("q") == "q" else 0);
}
