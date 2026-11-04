import from .base_mod { Counter }

obj Middle(Counter) {
    has extra: int = 1;

    def total -> int {
        return self.doubled + self.extra;
    }
}
