import from typing { ParamSpec }

glob P = ParamSpec("P"),
     T = TypeVar("T");

def impl_patch_filename(
    file_loc: str
) -> Callable[([Callable[(P, T)]], Callable[(P, T)])] {
    import sys;
    image = sys.modules.get("jaclang.compiler.driver.image");
    if image is not None {
        file_loc = image.rebase_source_filename(file_loc);
    }
    def decorator(func: Callable[(P, T)]) -> Callable[(P, T)] {
        try {
            func.__code__ = func.__code__.replace(co_filename=file_loc);
        } except AttributeError {}
        return func;
    }
    return decorator;
}
