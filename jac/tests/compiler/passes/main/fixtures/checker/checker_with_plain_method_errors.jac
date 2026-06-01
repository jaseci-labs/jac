"""Fixture: a plain (non-context-manager) method used in `with`.

Expected: E1091 + E1092. Generic decorator-application must not silence
errors for methods that are not context managers.
"""

obj NotCM {
    def get -> None;
}

impl NotCM.get -> None { }

def use_it {
    x = NotCM();
    with x.get() {
        print("fail");
    }
}
