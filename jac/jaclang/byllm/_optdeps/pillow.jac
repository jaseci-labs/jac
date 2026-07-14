"""Guarded re-exports for Pillow / PIL (capability: llm).

`PILImageCls` is used in `isinstance(...)` checks in media handling, so when
Pillow is absent we substitute a private sentinel class: isinstance against it is
always False (a real PIL image cannot exist without Pillow installed). `open_image`
raises the actionable capability error if actually called without the dependency.
"""

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
