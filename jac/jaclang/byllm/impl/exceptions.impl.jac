impl _adopt_provider_timeout(module: any) {
    provider_timeout = module.Timeout;
    if provider_timeout not in LLMTimeout.__bases__ {
        LLMTimeout.__bases__ = (ByLLMError, provider_timeout);
    }
}

impl ByLLMError.postinit -> None {
    Exception.__init__(self, self.message);
}

impl LLMTimeout.postinit -> None {
    Exception.__init__(self, self.message);
}

impl LLMTimeout.__str__ -> str {
    return self.message;
}
