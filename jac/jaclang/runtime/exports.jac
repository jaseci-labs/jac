import from functools { lru_cache }

@lru_cache(maxsize=None)
def runtime_function(name: str) -> Callable[..., any] {
    def invoke(*args: any, **kwargs: any) -> any {
        import from jaclang.runtime.runtime { JacRuntimeInterface }
        return getattr(JacRuntimeInterface, name)(*args, **kwargs);
    }
    invoke.__name__ = name;
    invoke.__qualname__ = f"JacRuntimeInterface.{name}";
    return invoke;
}
