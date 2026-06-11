"""Regular (non-native) Jac keeps the int/Callable distinction: `= 0` is
not a valid default for a Callable field outside `.na.jac` modules."""

obj Op {
    has fn: Callable[[int], int] = 0;  # <-- Error
}
