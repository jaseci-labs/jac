with entry {
    try {
        import from pydantic { TypeAdapter }
        HAS_PYDANTIC = True;
    } except ImportError {
        def TypeAdapter(*args: object, **kwargs: object) -> object {
            require_optional("pydantic", "llm");
        }
        HAS_PYDANTIC = False;
    }
}
