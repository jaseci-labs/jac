impl _LiteLLMShim.__getattr__(self: any, attr: str) -> any {
    if is_installed("litellm") {
        return getattr(importlib.import_module("litellm"), attr);
    }
    return getattr(_FALLBACK, attr);
}

impl _LiteLLMShim.__setattr__(self: any, attr: str, value: any) {
    if is_installed("litellm") {
        setattr(importlib.import_module("litellm"), attr, value);
    } else {
        object.__setattr__(self, attr, value);
    }
}

impl _LiteLLMShim.__delattr__(self: any, attr: str) {
    if is_installed("litellm") {
        delattr(importlib.import_module("litellm"), attr);
    } else {
        object.__delattr__(self, attr);
    }
}

impl _LiteLLMShim.__dir__(self: any) -> list[str] {
    if is_installed("litellm") {
        return dir(importlib.import_module("litellm"));
    }
    return dir(_FALLBACK);
}

impl _LiteLLMShim.__repr__(self: any) -> str {
    return "<litellm ("
        + ("installed" if is_installed("litellm") else "not installed")
        + ")>";
}

impl _disable_debugging {
    if is_installed("litellm") {
        importlib.import_module("litellm._logging")._disable_debugging();
    }
}

impl when_litellm_loaded(callback: any) {
    when_loaded("litellm", callback);
}
