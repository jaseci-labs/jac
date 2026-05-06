"""Implementation for NativeStructView and NativeListView."""

import ctypes;
import from typing { Any }

impl NativeStructView.postinit -> None {
    # from_address: NO copy -- creates view over C memory
    self._native = self.ct_cls.from_address(self.addr);
    # Build field metadata lookup (name -> NativeFieldInfo)
    if (self.layout and hasattr(self.layout, "structs")) {
        sl = self.layout.structs.get(self.struct_name);
        if sl {
            for f in sl.fields {
                self._field_meta[f.name] = f;
            }
        }
    }
}

impl NativeStructView.__getattr__(name: str) -> Any {
    native = self._native;
    try {
        raw = getattr(native, name);
    } except AttributeError {
        raise AttributeError(f"'{self.struct_name}' has no field '{name}'");
    }
    return self._resolve(name, raw);
}

impl NativeStructView._resolve(name: str, raw: Any) -> Any {
    finfo = self._field_meta.get(name);
    if finfo is None {
        return raw;
    }
    lt = finfo.llvm_type;
    # Function pointer: wrap raw address as callable ctypes function
    if finfo.is_func_ptr {
        if (raw is None or raw == 0) {
            return None;
        }
        fn_type = _build_cfunctype(finfo);
        return fn_type(raw);
    }
    # String: decode from raw pointer on demand
    if lt == "i8*" {
        if (raw is None or raw == 0) {
            return "";
        }
        return ctypes.string_at(raw).decode("utf-8", errors="replace");
    }
    # Enum field: ordinal -> enum value
    if (lt in ("i64", "i32") and finfo.enum_type) {
        val = int(raw);
        emap = self.enum_maps.get(finfo.enum_type);
        if (emap and 0 <= val < len(emap) and emap[val] is not None) {
            return emap[val];
        }
        return val;
    }
    # Nested struct pointer
    if (lt.endswith("*") and not lt.startswith("List.") and lt != "i8*") {
        sname = lt[:-1];
        if (raw and raw != 0) {
            ct_cls = self.ctypes_classes.get(sname);
            if ct_cls {
                return NativeStructView(
                    raw, ct_cls, sname, self.layout, self.ctypes_classes, self.enum_maps
                );
            }
        }
        return None;
    }
    # List pointer
    if (lt.startswith("List.") and lt.endswith("*")) {
        if (raw and raw != 0) {
            elem_key = lt[5:-1];
            return NativeListView(
                raw, elem_key, self.ctypes_classes, self.enum_maps, self.layout
            );
        }
        return NativeListView.empty();
    }
    return raw;
}

impl NativeStructView.__getitem__(key: str) -> Any {
    return getattr(self, key);
}

impl NativeStructView.__contains__(key: str) -> bool {
    return key in self._field_meta;
}

impl NativeStructView.keys -> Any {
    return self._field_meta.keys();
}

impl NativeStructView.items -> Any {
    return ((k, self[k]) for k in self.keys());
}

impl NativeStructView.__repr__ -> str {
    return f"<NativeStructView {self.struct_name}>";
}

impl NativeListView.postinit -> None {
    if (self.list_ptr == 0) {
        self._count = 0;
        self._arr = None;
        self._ct_cls = None;
        self._struct_name = None;
        return;
    }
    nl = NativeList.from_address(self.list_ptr);
    self._count = nl.len if (nl.len > 0 and nl.data) else 0;

    # Resolve struct class for ptr elements
    self._struct_name = self.struct_hint;
    if (self.elem_key == "ptr" and self._struct_name) {
        self._ct_cls = self.ctypes_classes.get(self._struct_name);
    }

    # Create array view over data -- zero-copy via from_address
    if self._count > 0 {
        if self.elem_key == "i64" {
            self._arr = (ctypes.c_int64 * self._count).from_address(nl.data);
        } elif self.elem_key == "f64" {
            self._arr = (ctypes.c_double * self._count).from_address(nl.data);
        } else {
            # 'ptr' and others
            self._arr = (ctypes.c_void_p * self._count).from_address(nl.data);
        }
    }
}

impl NativeListView.__len__ -> int {
    return self._count;
}

impl NativeListView.__getitem__(index: Any) -> Any {
    if isinstance(index, slice) {
        return [self[i] for i in range(*index.indices(self._count))];
    }
    if index < 0 {
        index += self._count;
    }
    if (index < 0 or index >= self._count) {
        raise IndexError(f"list index {index} out of range");
    }
    raw = self._arr[index];
    if self.elem_key == "i64" {
        return int(raw);
    }
    if self.elem_key == "f64" {
        return float(raw);
    }
    # Struct pointer element
    if (self._ct_cls and raw and raw != 0) {
        return NativeStructView(
            raw,
            self._ct_cls,
            self._struct_name,
            self.layout,
            self.ctypes_classes,
            self.enum_maps
        );
    }
    return raw;
}

impl NativeListView.__iter__ -> Any {
    for i in range(len(self)) {
        yield self[i];
    }
}

impl NativeListView.__eq__(other: Any) -> Any {
    if isinstance(other, list) {
        return (len(self) == len(other) and all(a == b for (a, b) in zip(self, other)));
    }
    return NotImplemented;
}

impl NativeListView.__repr__ -> str {
    return f"<NativeListView len={len(self)}>";
}
