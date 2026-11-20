# A representative of the subscript `del` sites in the tree. Each one peeks
# the location once, destroys whatever graph objects it held (nothing, here),
# and then runs the Python statement verbatim.
def evict(cache: dict[str, int], key: str) {
    del cache[key];
}

def evict_many(keys: list[str], cache: dict[str, int]) {
    for key in keys {
        del cache[key];
    }
}

def trim(items: list[int]) {
    del items[0];
    del items[1:3];
}
