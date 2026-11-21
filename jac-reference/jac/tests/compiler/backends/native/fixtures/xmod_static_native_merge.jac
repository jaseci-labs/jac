"""The control: the same merge surface with no Python-side base.

Nothing here blocks the native import walk, so `Merger` gets a struct type in
the importing unit and the class-qualified call lowers to a direct call.
"""
import from xmod_static_types { Item }

obj Merger {
    static def merge(a: Item, b: Item) -> int {
        return a.value + b.value;
    }
}
