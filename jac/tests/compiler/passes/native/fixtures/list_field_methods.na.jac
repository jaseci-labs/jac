# List methods on object-field / complex targets (not just simple locals).
# Regression for `self.field.pop()` being a no-op natively (only append was
# dispatched on complex targets) — the bug that left the lexer's mode_stack
# un-popped and broke native f-string lexing. Also covers enum-typed returns.

enum Mode { A = "a", B = "b", C = "c" }

obj ModeStack {
    has st: list[Mode] = [];
    def push(m: Mode) { self.st.append(m); }
    def pop_top -> Mode | None {
        if len(self.st) > 0 {
            return self.st.pop();
        }
        return None;
    }
    def depth -> int { return len(self.st); }
}

# pop() on a field list must shrink it (returns 21: depth 2 then 1).
def field_pop_shrinks -> int {
    s = ModeStack();
    s.push(Mode.A);
    s.push(Mode.B);
    d1 = s.depth();
    s.pop_top();
    return d1 * 10 + s.depth();
}

# Enum-typed function return marshals back to the enum (ordinal 1 == Mode.B).
def returns_enum -> Mode {
    return Mode.B;
}
