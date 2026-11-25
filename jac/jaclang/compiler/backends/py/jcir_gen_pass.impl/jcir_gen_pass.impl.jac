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

impl int_literal_magnitude(text: str) -> bytes {
    body = text.replace("_", "").lower();
    base = 10;
    if body.startswith("0x") {
        base = 16;
        body = body[2:];
    } elif body.startswith("0o") {
        base = 8;
        body = body[2:];
    } elif body.startswith("0b") {
        base = 2;
        body = body[2:];
    }
    digits = "0123456789abcdef";
    limbs: list[int] = [];
    for ch in body {
        carry = digits.find(ch);
        if carry < 0 or carry >= base {
            raise ValueError(f"invalid integer literal {text!r}");
        }
        at = 0;
        while at < len(limbs) {
            cur = limbs[at] * base + carry;
            limbs[at] = cur & 255;
            carry = cur >> 8;
            at += 1;
        }
        while carry > 0 {
            limbs.append(carry & 255);
            carry = carry >> 8;
        }
    }
    out = bytearray();
    for limb in limbs {
        out.append(limb);
    }
    return bytes(out);
}

impl splice_stmts(splice: CgSplice) -> list[ast.stmt] {
    tree = compile(
        splice.src, "<unknown>", "exec", flags=ast.PyCF_ONLY_AST, dont_inherit=True
    );
    if not isinstance(tree, ast.Module) {
        raise TypeError("a Python splice must parse to ast.Module");
    }
    return list(tree.body);
}

impl build_py_value(v: object) -> any {
    if v is None {
        return None;
    } elif isinstance(v, CgEllipsis) {
        return ...;
    } elif isinstance(v, CgNode) {
        cls = getattr(ast, v.cls, None);
        if cls is None {
            raise ValueError(f"the recipe names ast.{v.cls}, which this CPython lacks");
        }
        fields: dict[str, any] = {};
        for (key, item) in zip(v.keys, v.vals, strict=True) {
            if isinstance(item, CgSplice) {
                raise ValueError(
                    f"a splice reached field {key} of ast.{v.cls}; splices "
                    "belong only in statement lists"
                );
            }
            fields[key] = build_py_value(item);
        }
        built = cls(**fields);
        built.lineno = v.l1;
        built.col_offset = v.c1;
        built.end_lineno = v.l2;
        built.end_col_offset = v.c2;
        return built;
    } elif isinstance(v, CgWideInt) {
        magnitude = int.from_bytes(v.magnitude, "little");
        return -magnitude if v.negative else magnitude;
    } elif isinstance(v, bool) {
        return bool(v);
    } elif isinstance(v, int) {
        return int.__index__(v);
    } elif isinstance(v, float) {
        return float.__float__(v);
    } elif isinstance(v, str) {
        return str.__str__(v);
    } elif isinstance(v, bytes) {
        return bytes(v);
    } elif isinstance(v, list) {
        out: list[any] = [];
        for item in v {
            if isinstance(item, CgSplice) {
                out.extend(splice_stmts(item));
            } else {
                out.append(build_py_value(item));
            }
        }
        return out;
    }
    raise ValueError(
        "the Python emitter produced a value outside the recipe domain. "
        "The whole domain is None, a CgEllipsis marker, a CgNode, a "
        "CgSplice inside a list, a CgWideInt, bool, int, float, str, bytes, "
        "and a list of those; a value of any other type reached a recipe "
        "slot, most often because a producer put a live Python object where "
        "a recipe value belongs."
    );
}

impl build_py_module(root_node: CgNode) -> ast.Module {
    tree = build_py_value(root_node);
    if not isinstance(tree, ast.Module) {
        raise ValueError(
            f"the module recipe built ast.{type(tree).__name__}, not ast.Module"
        );
    }
    return tree;
}
