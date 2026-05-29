"""Fixture: a plain method (no @contextmanager) used in a with statement.

Expected: E1091 + E1092 — the return type is NoneType which has no
__enter__ or __exit__. This guards against our fix accidentally silencing
legitimate errors on non-context-manager types.
"""

obj NotAContextManager {
    def get -> None;
}

impl NotAContextManager.get -> None { }

def use_it {
    obj_ = NotAContextManager();
    with obj_.get() {
        :> "should fail";
    }
}
