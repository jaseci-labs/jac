"""Guarded re-exports for litellm (capability: llm).

Keeps `import jaclang.byllm.llm` / `import jaclang.byllm.types` cheap: litellm is
only imported here, lazily, so the byllm public API stays importable without the
`llm` capability installed. Actual API calls are gated by `require_optional` at
the call sites (Model.model_call_*), which raise the actionable capability error.

When litellm is absent we still expose a stand-in object whose `.exceptions.*`
and transient-error classes are private Exception subclasses that never match a
real error. This lets the mock backend run the shared ReAct loop (whose `except
litellm.exceptions.*` clauses would otherwise dereference None) without the `llm`
capability; real backends are guarded before any litellm call is reached.
"""

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

        # Sentinel so `Message | LiteLLMMessage` annotations and isinstance checks
        # stay safe; a real LiteLLMMessage is only constructed inside a live model
        # flow, where litellm is present.
        class LiteLLMMessage {}
        HAS_LITELLM = False;
    }
}
