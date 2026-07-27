with entry {
    try {
        import from pydantic { TypeAdapter }
        HAS_PYDANTIC = True;
    } except ImportError {
        def TypeAdapter(*args: object, **kwargs: object) -> object {
            import from jaclang.project.capabilities { require_optional }
            require_optional("pydantic", "llm");
        }
        HAS_PYDANTIC = False;
    }
}
