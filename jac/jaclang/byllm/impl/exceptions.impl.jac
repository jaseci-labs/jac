impl _adopt_provider_timeout(module: any) {
    provider_timeout = module.Timeout;
    if provider_timeout not in LLMTimeout.__bases__ {
        LLMTimeout.__bases__ = (ByLLMError, provider_timeout);
    }
}

impl ByLLMError.init(message: str = "") -> None {
    self.message = message;
    Exception.__init__(self, message);
}

impl LLMTimeout.init(
    message: str = "",
    model: str = "",
    llm_provider: str = "",
    num_retries: int | None = None,
    max_retries: int | None = None,
    status_code: int = 408
) -> None {
    self.message = message;
    self.model = model;
    self.llm_provider = llm_provider;
    self.num_retries = num_retries;
    self.max_retries = max_retries;
    self.status_code = status_code;
    Exception.__init__(self, message);
}

impl LLMTimeout.__str__ -> str {
    return self.message;
}
