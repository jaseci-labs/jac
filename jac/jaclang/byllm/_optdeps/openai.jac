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
        class _OpenAITimeout(_OpenAIUnavailable) {}

        import types;
        openai = types.SimpleNamespace(
            AuthenticationError=_OpenAIAuthError,
            RateLimitError=_OpenAIRateLimit,
            NotFoundError=_OpenAINotFound,
            APITimeoutError=_OpenAITimeout
        );
        OpenAI = None;
        AsyncOpenAI = None;
        HAS_OPENAI = False;
    }
}
