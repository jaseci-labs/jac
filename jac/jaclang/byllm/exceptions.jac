import from jaclang.byllm._optdeps.litellm { when_litellm_loaded }

obj ByLLMError(Exception) {
    has message: str = "";

    def postinit -> None;
}

impl ByLLMError.postinit -> None {
    Exception.__init__(self, self.message);
}

obj AuthenticationError(ByLLMError) {}

obj RateLimitError(ByLLMError) {}

obj ModelNotFoundError(ByLLMError) {}

obj LLMTimeout(ByLLMError) {
    has model: str = "",
        llm_provider: str = "",
        num_retries: int | None = None,
        max_retries: int | None = None,
        status_code: int = 408;

    def postinit -> None;
    def __str__ -> str;
}

impl LLMTimeout.postinit -> None {
    Exception.__init__(self, self.message);
}

impl LLMTimeout.__str__ -> str {
    return self.message;
}

def _adopt_provider_timeout(module: any) {
    provider_timeout = module.Timeout;
    if provider_timeout not in LLMTimeout.__bases__ {
        LLMTimeout.__bases__ = (ByLLMError, provider_timeout);
    }
}

with entry {
    when_litellm_loaded(_adopt_provider_timeout);
}

obj OutputConversionError(ByLLMError) {}

obj FinishToolError(ByLLMError) {}

obj ConfigurationError(ByLLMError) {}

obj McpError(ByLLMError) {}

obj CompactionNotEffectiveError(ByLLMError) {}
