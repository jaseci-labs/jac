def:pub effects(reads: list[str] = [], writes: list[str] = []) -> Callable {
    for dependency in reads + writes {
        if not isinstance(dependency, str) or not dependency {
            raise ValueError("Effect dependencies must be nonempty strings");
        }
    }
    def decorate(fn: Callable) -> Callable {
        setattr(fn, "__jac_effects__", {"reads": list(reads), "writes": list(writes)});
        return fn;
    }
    return decorate;
}
