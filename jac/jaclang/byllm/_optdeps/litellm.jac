import types;

with entry {
    try {
        import litellm;
        import from litellm._logging { _disable_debugging }
        import from litellm.types.utils { Message as LiteLLMMessage }
        HAS_LITELLM = True;
    } except ImportError {
        class _LLMUnavailable(Exception) {}
        class _CtxWindowExceeded(_LLMUnavailable) {}
        class _AuthError(_LLMUnavailable) {}
        class _RateLimit(_LLMUnavailable) {}
        class _NotFound(_LLMUnavailable) {}
        class _APIConnection(_LLMUnavailable) {}
        class _InternalServer(_LLMUnavailable) {}
        class _ServiceUnavailable(_LLMUnavailable) {}
        class _Timeout(_LLMUnavailable) {}

        litellm = types.SimpleNamespace(
            exceptions=types.SimpleNamespace(
                AuthenticationError=_AuthError,
                RateLimitError=_RateLimit,
                NotFoundError=_NotFound,
                ContextWindowExceededError=_CtxWindowExceeded
            ),
            APIConnectionError=_APIConnection,
            InternalServerError=_InternalServer,
            ServiceUnavailableError=_ServiceUnavailable,
            Timeout=_Timeout
        );

        def _disable_debugging -> None {
            return None;
        }

        class LiteLLMMessage {}
        HAS_LITELLM = False;
    }
}
