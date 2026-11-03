"""The Python code generator's recipe.

`PyastGenPass` builds each module as a recipe: nodes named by their `ast`
class, fields as ordered keys and values, and source spans. `pyast_build`
lowers a finished recipe into JacPython's AST inside the kernel."""
obj CgItem {}

obj CgNode(CgItem) {
    has cls: str,
        keys: list[str],
        vals: list[any],
        l1: int = 0,
        c1: int = 0,
        l2: int = 0,
        c2: int = 0,
        jac_src: (UniNode | None) = None;

    def get(key: str) -> any;
    def setf(key: str, value: any) -> None;
    def hasf(key: str) -> bool;
    def items(key: str) -> list[any];
    def push(key: str, item: any);
}

obj CgSplice(CgItem) {
    has src: str,
        bound_names: list[str] = [];
}

obj CgEllipsis(CgItem) {}

obj CgWideInt(CgItem) {
    has negative: bool,
        magnitude: bytes;
}

def int_literal_magnitude(text: str) -> bytes;
