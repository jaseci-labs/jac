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
    tasks: list[tuple[(int, object)]] = [(TASK_VALUE, v)];
    while tasks {
        t = tasks.pop();
        kind = t[0];
        val = t[1];
        if kind == TASK_NODE and isinstance(val, CgNode) {
            nd: CgNode = val;
            w.emit_loc_needed(nd.l1, nd.c1, nd.l2, nd.c2);
            w.emit_node(nd.cls, nd.keys);
            continue;
        }
        if kind == TASK_LIST and isinstance(val, int) {
            n: int = val;
            w.emit_list(n);
            continue;
        }
        if val is None {
            w.emit_none();
        } elif isinstance(val, CgEllipsis) {
            w.emit_ellipsis();
        } elif isinstance(val, CgNode) {
            tasks.append((TASK_NODE, val));
            items = val.vals;
            i = len(items) - 1;
            while i >= 0 {
                tasks.append((TASK_VALUE, items[i]));
                i -= 1;
            }
        } elif isinstance(val, CgSplice) {
            w.emit_parse_splice(val.src, val.offset);
        } elif isinstance(val, CgWideInt) {
            w.emit_int_wide(val.negative, val.magnitude);
        } elif isinstance(val, bool) {
            if val {
                w.emit_true();
            } else {
                w.emit_false();
            }
        } elif isinstance(val, int) {
            w.emit_int(val);
        } elif isinstance(val, float) {
            w.emit_float(val);
        } elif isinstance(val, str) {
            w.emit_str(val);
        } elif isinstance(val, bytes) {
            w.emit_bytes(val);
        } elif isinstance(val, list) {
            tasks.append((TASK_LIST, len(val)));
            i = len(val) - 1;
            while i >= 0 {
                tasks.append((TASK_VALUE, val[i]));
                i -= 1;
            }
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
}

impl module_container_bytes(mod_path: str, root_node: CgNode) -> bytes {
    w = CodegenIrWriter();
    w.begin_module(mod_path);
    write_ir_value(w, root_node);
    w.end_module();
    return w.to_bytes();
}
