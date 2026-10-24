obj ByLLMError(Exception) {
    has message: str = "";

    def postinit -> None;
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

def _adopt_provider_timeout(module: any);

with entry {
    when_litellm_loaded(_adopt_provider_timeout);
}

obj OutputConversionError(ByLLMError) {}

obj FinishToolError(ByLLMError) {}

obj ConfigurationError(ByLLMError) {}

obj McpError(ByLLMError) {}

obj CompactionNotEffectiveError(ByLLMError) {}

obj OutputTruncatedError(ByLLMError) {}
