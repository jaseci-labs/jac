with entry {
    try {
        import from PIL.Image { Image as PILImageCls, open as open_image }
        HAS_PILLOW = True;
    } except ImportError {
        class _PillowUnavailable {}
        PILImageCls = _PillowUnavailable;

        def open_image(*args: object, **kwargs: object) -> object {
            import from jaclang.project.capabilities { require_optional }
            require_optional("PIL", "llm");
        }
        HAS_PILLOW = False;
    }
}
