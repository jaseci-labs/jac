"""`del obj.prop` runs the property's deleter, inline or impl-separated."""
obj Circle {
    has _radius: float = 1.0,
        _label: str = "c";

    has radius: float {
        getter -> float {
            return self._radius;
        }
        setter(value: float) {
            self._radius = value;
        }
        deleter {
            self._radius = 0.0;
        }
    }

    has label: str {
        getter -> str {
            return self._label;
        }
        deleter;
    }
}

impl Circle.label.deleter {
    self._label = "";
}

def reset(c: Circle) {
    del c.radius;
}

with entry {
    c = Circle();
    c.radius = 5.0;
    print(c.radius, repr(c.label));
    reset(c);
    del c.label;
    print(c.radius, repr(c.label));
}
