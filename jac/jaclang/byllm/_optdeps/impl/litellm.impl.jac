impl _disable_debugging {
    if HAS_LITELLM {
        importlib.import_module("litellm._logging")._disable_debugging();
    }
}

impl when_litellm_loaded(callback: any) {
    if HAS_LITELLM {
        when_loaded("litellm", callback);
    }
}
