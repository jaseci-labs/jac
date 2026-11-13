import importlib;
import types;

glob HAS_LITELLM: bool = is_installed("litellm");

class _LLMUnavailable(Exception) {}
class _CtxWindowExceeded(_LLMUnavailable) {}
class _AuthError(_LLMUnavailable) {}
class _RateLimit(_LLMUnavailable) {}
class _NotFound(_LLMUnavailable) {}
class _APIConnection(_LLMUnavailable) {}
class _InternalServer(_LLMUnavailable) {}
class _ServiceUnavailable(_LLMUnavailable) {}
class _Timeout(_LLMUnavailable) {}

class _LiteLLMShim {
    def __getattr__(self: any, attr: str) -> any;
    def __setattr__(self: any, attr: str, value: any);
    def __delattr__(self: any, attr: str);
    def __dir__(self: any) -> list[str];
    def __repr__(self: any) -> str;
}

glob _FALLBACK: any = types.SimpleNamespace(
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
     ),
     litellm: any = _LiteLLMShim();

class LiteLLMMessage(metaclass=DeferredClassMeta) {
    static has _deferred_module: str = "litellm",
        _deferred_path: str = "types.utils.Message";
}

def _disable_debugging;

def when_litellm_loaded(callback: any);
