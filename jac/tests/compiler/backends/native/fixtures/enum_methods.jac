import from enum_methods_lib { ForeignPriority }

enum Binding {
    VALUE = 'value',
    TYPE = 'type',
    BOTH = 'both',
    with entry {
        def denotes_value(self: Binding) -> bool {
            return self != Binding.TYPE;
        }
        def score(self: Binding, offset: int = 7) -> int {
            if self.denotes_value() {
                return len(self.value) + offset;
            }
            return offset;
        }
    }
}

enum Priority: int {
    LOW = 3,
    HIGH = 11,
    with entry {
        def scaled(self: Priority, scale: int) -> int {
            return self.value * scale;
        }
    }
}

def:pub binding_score(which: int) -> int {
    value = Binding.TYPE if which == 0 else Binding.BOTH;
    return value.score();
}

def:pub priority_score(which: int) -> int {
    value = Priority.LOW if which == 0 else Priority.HIGH;
    return value.scaled(2);
}


def:pub foreign_priority_score(which: int) -> int {
    value = ForeignPriority.LOW if which == 0 else ForeignPriority.HIGH;
    return value.scaled();
}
