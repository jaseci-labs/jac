"""Self-typed return values resolve via the receiver class for chained
and indirected access (issue #5688).
"""

import from typing { Self }
import from datetime { datetime, timezone }


def case_stdlib_chained -> str {
    return datetime.now(timezone.utc).isoformat();  # ok

}


def case_stdlib_indirected -> str {
    f = datetime.now;
    return f(timezone.utc).isoformat();  # ok

}


class Box {
    has count: int = 0;

    @classmethod
    def make(cls: type[Self]) -> Self {
        return cls();
    }

    def kick -> int {
        return self.count + 1;
    }
}


def case_user_classmethod -> int {
    return Box.make().kick();  # ok

}


class Builder {
    has value: int = 0;

    def again -> Self {
        return self;
    }

    def total -> int {
        return self.value;
    }
}


def case_instance_fluent -> int {
    return Builder().again().total();  # ok

}
