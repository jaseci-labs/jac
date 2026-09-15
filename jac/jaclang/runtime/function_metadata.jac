import from typing { ParamSpec }

glob P = ParamSpec("P"),
     T = TypeVar("T");

def impl_patch_filename(
    file_loc: str
) -> Callable[([Callable[(P, T)]], Callable[(P, T)])] {
    import sys;
    image = sys.modules.get("jaclang.image");
    if image is not None {
        file_loc = image.rebase_source_filename(file_loc);
    }
    def decorator(func: Callable[(P, T)]) -> Callable[(P, T)] {
        try {
            code = func.__code__;
            prepared = sys.modules.get("jaclang.runtime.prepared");
            lookup = prepared.__dict__.get("application_for")
                if prepared is not None
                else None;
            application = lookup(code.co_filename, func.__module__ or '')
                if lookup is not None
                else None;
            if application is not None {
                import from jaclang.extensions { is_jac }
                if is_jac(application.origins.get(code.co_filename, '')) {
                    return func;
                }
            }
            func.__code__ = code.replace(co_filename=file_loc);
        } except AttributeError {}
        return func;
    }
    return decorator;
}
