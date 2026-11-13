"""Regression: a property setter on a Python-style `class`.

A `class` method declares `self` explicitly, but a property accessor never
does: `setter(value: T)` names only the assigned value. The accessor still
receives the instance, so an assignment reaches the setter with both.
"""

class Gauge {
    def init(self: Gauge) {
        self._level = 1;
    }

    has level: int { getter; setter(value: int); }
    has inline: int {
        getter {
            return self._level * 10;
        }
        setter(value: int) {
            self._level = value // 10;
        }
    }
}

impl Gauge.level.getter -> int {
    return self._level;
}

impl Gauge.level.setter(value: int) {
    self._level = value;
}

with entry {
    gauge = Gauge();
    gauge.level = 5;
    assert gauge.level == 5;
    gauge.inline = 70;
    assert gauge.level == 7 and gauge.inline == 70;
    print("ok");
}
