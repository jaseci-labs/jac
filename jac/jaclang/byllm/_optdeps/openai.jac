import types;
import from jaclang.byllm._optdeps._deferred {
    DeferredClassMeta,
    DeferredModule,
    is_installed
}

glob HAS_OPENAI: bool = is_installed("openai");

with entry {
    if HAS_OPENAI {
        openai: any = DeferredModule("openai");
    } else {
        class _OpenAIUnavailable(Exception) {}
        class _OpenAIAuthError(_OpenAIUnavailable) {}
        class _OpenAIRateLimit(_OpenAIUnavailable) {}
        class _OpenAINotFound(_OpenAIUnavailable) {}
        openai = types.SimpleNamespace(
            AuthenticationError=_OpenAIAuthError,
            RateLimitError=_OpenAIRateLimit,
            NotFoundError=_OpenAINotFound
        );
    }
}

class OpenAI(metaclass=DeferredClassMeta) {
    static has _deferred_module: str = "openai",
        _deferred_path: str = "OpenAI";
}

class AsyncOpenAI(metaclass=DeferredClassMeta) {
    static has _deferred_module: str = "openai",
        _deferred_path: str = "AsyncOpenAI";
}
