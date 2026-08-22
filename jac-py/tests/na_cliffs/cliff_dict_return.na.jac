# na cliff: dict-return ICE. jac-py core site: Objects exec_module() returns
# dict[str, PyObj]; PyDict.items. Memory: rust-ffi M6.2 / na-container-capabilities.
def exec_module -> dict[str, int] {
    g: dict[str, int] = {};
    g["y"] = 43;
    return g;
}

def use -> int {
    return exec_module()["y"];
}

with entry {
    print(use());
}
