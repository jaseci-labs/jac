"""Standalone top-level constructs in a .impl.jac annex.

These constructs have no matching decl in the primary file; they are
defined entirely here. The resolver in DeclImplMatchPass must still
bind Load-context reads in their bodies, or type inference for locals
breaks and static analysis produces spurious `may be undefined` warnings.
"""

def greet(name: str) -> str {
    msg = "hello " + name;
    return msg;
}

obj Box {
    has label: str;

    def describe -> str {
        local_label = self.label;
        return local_label;
    }
}

node Counter {
    has value: int = 0;

    def bumped -> int {
        v = self.value;
        return v + 1;
    }
}

walker Visitor {
    has seen: int = 0;

    def count -> int {
        n = self.seen;
        return n;
    }
}
