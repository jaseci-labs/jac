import from typing { cast }

obj FuncDef {
    has name: str = "",
        lineno: int = 0;
}

obj AsyncFuncDef {
    has name: str = "",
        lineno: int = 0;
}

obj ClassDef {
    has name: str = "",
        lineno: int = 0;
}

def get_func_name(nd: object) -> str {
    func = cast((FuncDef | AsyncFuncDef), nd);
    return func.name;  # name exists on both members
}

def get_line(nd: object) -> int {
    func = cast((FuncDef | AsyncFuncDef), nd);
    return func.lineno;  # lineno exists on both members
}

def get_def_name(nd: object) -> str {
    defn = cast((FuncDef | AsyncFuncDef | ClassDef), nd);
    return defn.name;  # name exists on all three members
}
