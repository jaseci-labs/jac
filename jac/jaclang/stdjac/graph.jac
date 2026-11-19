"""The kept graph, by id, and writing it: neojac's stdjac.graph on jac's runtime.

`commit()` writes what changed in the graph since it was last written, now. A server
writes the graph when each call returns; a call that runs long, or a stream, calls
this where its work so far should be kept.
"""

obj DataError(Exception) {
    has path: str = "",
        problem: str = "";

    def __str__ -> str {
        return f"{self.path}: {self.problem}";
    }
}

def commit -> None {
    JacRuntime.commit();
}

def jobj(name: str) -> any {
    return JacRuntime.get_object(name);
}

def allroots -> list[Root] {
    return list(JacRuntime.get_all_root());
}

def grant(n: Node, level: AccessLevel = AccessLevel.READ) -> None {
    JacRuntime.perm_grant(n, level);
}

def remove(n: Node) -> None {
    JacRuntime.destroy(n);
}
