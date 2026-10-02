with entry {
    try {
        import from PIL.Image { Image as PILImageCls, open as open_image }
        import from PIL.ImageOps { exif_transpose }
        HAS_PILLOW = True;
    } except ImportError {
        class PILImageCls {}

        def open_image(*args: object, **kwargs: object) -> object {
            import from jaclang.project.capabilities { require_optional }
            require_optional("PIL", "llm");
        }

        def exif_transpose(image: object) -> object {
            import from jaclang.project.capabilities { require_optional }
            require_optional("PIL", "llm");
        }
        HAS_PILLOW = False;
    }
}
