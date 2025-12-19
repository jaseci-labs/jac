"""Post-initialization hook for Model.

Sets up proxy mode and mock delegation based on config.
Configures logging when using real LLM backends.
"""
impl Model.postinit -> None {
    self.proxy = bool(self.config.get("proxy", False));
    # When model_name is 'mockllm', delegate to MockLLM behavior
    if self.model_name == MODEL_MOCK {
        self._mock_delegate = MockLLM(model_name=self.model_name, config=self.config);
    }
    if not self._mock_delegate {
        logging.getLogger("httpx").setLevel(logging.WARNING);
        _disable_debugging();
        litellm.drop_params = True;
    }
}

"""Invoke the LLM, delegating to MockLLM if applicable."""
impl Model.invoke(mtir: MTRuntime) -> object {
    if self._mock_delegate {
        return self._mock_delegate.invoke(mtir);
    }
    return super.invoke(mtir);
}

"""Make a direct model call without streaming.

Uses OpenAI client if proxy mode is enabled, otherwise uses LiteLLM.
"""
impl Model.model_call_no_stream(params: dict) -> dict {
    if self.proxy {
        client = OpenAI(base_url=self.api_base);
        response = client.chat.completions.create(**params);
    } else {
        response = litellm.completion(**params);
    }
    return response;
}

"""Make a direct model call with streaming.

Uses OpenAI client if proxy mode is enabled, otherwise uses LiteLLM.
Returns a generator that yields response chunks.
"""
impl Model.model_call_with_stream(params: dict) -> Generator[str, None, None] {
    if self.proxy {
        client = OpenAI(base_url=self.api_base, api_key=self.api_key,);
        response = client.chat.completions.create(stream=True, **params);
    } else {
        response = litellm.completion(stream=True, **params);
    }
    return response;
}
