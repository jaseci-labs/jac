def outer() -> int:
    """outer doc"""
    x = 1
    x += 2

    def inner() -> int:
        """inner doc"""
        y = 3
        y += 4
        return y

    return x + inner()
