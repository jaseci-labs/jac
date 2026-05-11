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
    return func.name;  # ok: name exists on all union members
}

def get_line(nd: object) -> int {
    func = cast((FuncDef | AsyncFuncDef), nd);
    return func.lineno;  # ok: lineno exists on all union members
}

def get_def_name(nd: object) -> str {
    defn = cast((FuncDef | AsyncFuncDef | ClassDef), nd);
    return defn.name;  # ok: name exists on all union members
}
