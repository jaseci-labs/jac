impl DataError.__str__ -> str {
    return f"{self.path}: {self.problem}";
}

impl commit {
    JacRuntime.commit();
}

impl jobj(name: str) -> any {
    return JacRuntime.get_object(name);
}

impl allroots -> list[Root] {
    return list(JacRuntime.get_all_root());
}

impl grant(n: Node, level: AccessLevel = AccessLevel.READ) {
    JacRuntime.perm_grant(n, level);
}

impl remove(n: Node) {
    JacRuntime.destroy(n);
}
