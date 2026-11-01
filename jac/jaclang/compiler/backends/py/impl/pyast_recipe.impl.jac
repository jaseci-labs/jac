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
