"""Custom exception hierarchy for byLLM.

All exceptions raised by byLLM inherit from ByLLMError, allowing callers
to catch any library error with a single except clause.
"""

"""Base exception for all byLLM errors.

The `message` field is forwarded to Exception.__init__ via postinit so that
str(e) and e.args[0] work as expected for all subclasses.
"""
obj ByLLMError(Exception) {
    has message: str = "";

    def postinit -> None;
}

impl ByLLMError.postinit -> None {
    Exception.__init__(self, self.message);
}

"""Raised when the API key is missing, expired, or rejected."""
obj AuthenticationError(ByLLMError) {}

"""Raised when the API rate limit or quota is exceeded."""
obj RateLimitError(ByLLMError) {}

"""Raised when the requested model name does not exist or is unavailable."""
obj ModelNotFoundError(ByLLMError) {}

"""Raised when the LLM response cannot be parsed or converted to the declared return type.

The raw LLM output string is available via the `raw_output` attribute,
set on the instance at the raise site.
"""
obj OutputConversionError(ByLLMError) {}

"""Raised when the LLM calls a tool name that was not registered."""
obj UnknownToolError(ByLLMError) {}

"""Raised when finish_tool output fails validation against the declared return type."""
obj FinishToolError(ByLLMError) {}

"""Raised for invalid byLLM usage such as unsupported type annotations or mismatched stream settings."""
obj ConfigurationError(ByLLMError) {}
