impl _apply_litellm_debug_setting(module: any) {
    module.suppress_debug_info = not _litellm_config.get("debug", False);
}

impl _stream_chunk_builder_accepts_logging_obj -> bool {
    import inspect;
    try {
        builder: any = litellm.stream_chunk_builder;
        return "logging_obj" in inspect.signature(builder).parameters;
    } except Exception as e {
        logger.debug(
            f"could not inspect stream_chunk_builder, omitting logging_obj: {e}"
        );
        return False;
    }
}

impl _stream_builder_accepts_logging_obj -> bool {
    if _STREAM_CHUNK_BUILDER_ACCEPTS_LOGGING_OBJ is not None {
        return _STREAM_CHUNK_BUILDER_ACCEPTS_LOGGING_OBJ;
    }
    if "accepts" not in _stream_builder_probe_cache {
        _stream_builder_probe_cache["accepts"] = _stream_chunk_builder_accepts_logging_obj();
    }
    return _stream_builder_probe_cache["accepts"];
}
