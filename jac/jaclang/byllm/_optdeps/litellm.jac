import importlib;
import types;
import from jaclang.byllm._optdeps._deferred {
    DeferredClassMeta,
    DeferredModule,
    is_installed,
    when_loaded
}

glob HAS_LITELLM: bool = is_installed("litellm");

with entry {
    if HAS_LITELLM {
        litellm: any = DeferredModule("litellm");
    } else {
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
    }
}

class LiteLLMMessage(metaclass=DeferredClassMeta) {
    static has _deferred_module: str = "litellm",
        _deferred_path: str = "types.utils.Message";
}

def _disable_debugging {
    if HAS_LITELLM {
        importlib.import_module("litellm._logging")._disable_debugging();
    }
}

def when_litellm_loaded(callback: any) {
    if HAS_LITELLM {
        when_loaded("litellm", callback);
    }
}
