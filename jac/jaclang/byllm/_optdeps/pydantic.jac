with entry {
    try {
        import from pydantic { TypeAdapter }
        import from pydantic_core { from_json }
        HAS_PYDANTIC = True;
    } except ImportError {
        def TypeAdapter(*args: object, **kwargs: object) -> object {
            require_optional("pydantic", "llm");
        }
        def from_json(*args: object, **kwargs: object) -> object {
            require_optional("pydantic", "llm");
        }
        HAS_PYDANTIC = False;
    }
}
