"""A def handed to C through different C-typed uses keeps one address."""
import from c {
    obj item;  obj item_vt {
        has drop: Callable[[ptr[item]], None] = 0,
            release: Callable[[ptr], None] = 0;
    }  def free(block: ptr);
}

def drop_item(it: ptr[item]);

impl drop_item(it: ptr[item]) {
    return;
}

import from c { glob:priv item_table: item_vt = item_vt(drop=drop_item); }

# A slot written in code holds the same address `ptr(f)` gives.
def:pub stored_slot_matches -> i64 {
    vt = ptr[item_vt](addressof(item_table));
    vt.view(1)[0].drop = drop_item;
    return 1 if int(vt.view(1)[0].drop) == int(ptr(drop_item)) else 0;
}

# A slot set by a C data initializer holds that address too.
def:pub table_slot_matches -> i64 {
    vt = ptr[item_vt](addressof(item_table));
    return 1 if int(vt.view(1)[0].drop) == int(ptr(drop_item)) else 0;
}

# A C function stored in a slot is the function itself, as C data holds it.
def:pub stored_c_function_matches -> i64 {
    vt = ptr[item_vt](addressof(item_table));
    vt.view(1)[0].release = free;
    return 1 if int(vt.view(1)[0].release) == int(ptr(free)) else 0;
}
