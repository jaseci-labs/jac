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

obj OutputConversionError(ByLLMError) {}

obj FinishToolError(ByLLMError) {}

obj ConfigurationError(ByLLMError) {}

obj McpError(ByLLMError) {}

obj CompactionNotEffectiveError(ByLLMError) {}
