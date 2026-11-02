with entry {
    try {
        import from PIL.Image { Image as PILImageCls, open as open_image }
        HAS_PILLOW = True;
    } except ImportError {
        class PILImageCls {}

        def open_image(*args: object, **kwargs: object) -> object {
            require_optional("PIL", "llm");
        }
        HAS_PILLOW = False;
    }
}
