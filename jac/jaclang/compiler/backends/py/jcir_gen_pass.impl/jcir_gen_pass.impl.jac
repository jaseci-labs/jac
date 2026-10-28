impl CgNode.get(key: str) -> any {
    i = 0;
    while i < len(self.keys) {
        if self.keys[i] == key {
            return self.vals[i];
        }
        i += 1;
    }
    raise KeyError(f"CgNode {self.cls} has no field {key}");
}

impl CgNode.setf(key: str, value: any) -> None {
    i = 0;
    while i < len(self.keys) {
        if self.keys[i] == key {
            self.vals[i] = value;
            return;
        }
        i += 1;
    }
    self.keys.append(key);
    self.vals.append(value);
}

impl CgNode.hasf(key: str) -> bool {
    return key in self.keys;
}

impl CgNode.items(key: str) -> list[any] {
    value: list[any] = self.get(key);
    return value;
}

impl CgNode.push(key: str, item: any) {
    value = self.items(key);
    value.append(item);
    self.setf(key, value);
}

impl write_ir_value(w: CodegenIrWriter, v: object) {
    if v is None {
        w.emit_none();
    } elif isinstance(v, CgEllipsis) {
        w.emit_ellipsis();
    } elif isinstance(v, CgNode) {
        for item in v.vals {
            write_ir_value(w, item);
        }
        w.emit_loc_needed(v.l1, v.c1, v.l2, v.c2);
        w.emit_node(v.cls, v.keys);
    } elif isinstance(v, CgSplice) {
        w.emit_parse_splice(v.src, v.offset);
    } elif isinstance(v, CgWideInt) {
        w.emit_int_wide(v.negative, v.magnitude);
    } elif isinstance(v, bool) {
        if v {
            w.emit_true();
        } else {
            w.emit_false();
        }
    } elif isinstance(v, int) {
        w.emit_int(v);
    } elif isinstance(v, float) {
        w.emit_float(v);
    } elif isinstance(v, str) {
        w.emit_str(v);
    } elif isinstance(v, bytes) {
        w.emit_bytes(v);
    } elif isinstance(v, list) {
        for item in v {
            write_ir_value(w, item);
        }
        w.emit_list(len(v));
    } else {
        raise ValueError(
            "JCIR emitter produced a value outside the v1 constant domain. "
            "The whole domain is None, a CgEllipsis marker, a CgNode, a "
            "CgSplice, bool, int, float, str, bytes, and a list of those; a "
            "value of any other type reached a recipe slot, most often "
            "because a producer put a live Python object where an encodable "
            "one belongs."
        );
    }
}

impl module_container_bytes(mod_path: str, root_node: CgNode) -> bytes {
    w = CodegenIrWriter();
    w.begin_module(mod_path);
    write_ir_value(w, root_node);
    w.end_module();
    return w.to_bytes();
}
