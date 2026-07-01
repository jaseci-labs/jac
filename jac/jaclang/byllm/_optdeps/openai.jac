"""Guarded re-exports for the openai SDK (capability: llm).

openai ships transitively with litellm, so it belongs to the `llm` capability.
The client classes are used only on the proxy code path (guarded by
require_optional before construction); the exception classes appear in `except`
clauses on shared code paths, so when openai is absent we expose private
Exception subclasses that never match a real error.
"""

with entry {
    try {
        import openai;
        import from openai { OpenAI, AsyncOpenAI }
        HAS_OPENAI = True;
    } except ImportError {
        class _OpenAIUnavailable(Exception) {}
        class _OpenAIAuthError(_OpenAIUnavailable) {}
        class _OpenAIRateLimit(_OpenAIUnavailable) {}
        class _OpenAINotFound(_OpenAIUnavailable) {}

        import types;
        openai = types.SimpleNamespace(
            AuthenticationError=_OpenAIAuthError,
            RateLimitError=_OpenAIRateLimit,
            NotFoundError=_OpenAINotFound
        );
        OpenAI = None;
        AsyncOpenAI = None;
        HAS_OPENAI = False;
    }
}
