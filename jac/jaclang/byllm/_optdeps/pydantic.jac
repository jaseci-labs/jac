"""Guarded re-export for pydantic's TypeAdapter (capability: llm).

pydantic ships transitively with litellm. `TypeAdapter` is only invoked during
typed-output conversion inside a live model flow (after Model.postinit's
require_optional guard), so the raising placeholder is never reached when the
`llm` capability is absent.
"""

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
