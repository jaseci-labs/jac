impl Model.init(model_name: str, **kwargs: object) -> None {
    super.init(model_name, **kwargs);
    self.proxy = kwargs.get("proxy", False);
    # When model_name is 'mockllm', delegate to MockLLM behavior
    self._mock_delegate = MockLLM(model_name=model_name, **kwargs)
    if model_name == MODEL_MOCK
    else None;
    if not self._mock_delegate {
        logging.getLogger("httpx").setLevel(logging.WARNING);
        _disable_debugging();
        litellm.drop_params = True;
    }
}

impl Model.invoke(mtir: MTRuntime) -> object {
    if self._mock_delegate {
        return self._mock_delegate.invoke(mtir);
    }
    return super.invoke(mtir);
}

impl Model.model_call_no_stream(params: dict) -> dict {
    if self.proxy {
        client = OpenAI(base_url=self.api_base);
        response = client.chat.completions.create(**params);
    } else {
        response = litellm.completion(**params);
    }
    return response;
}

impl Model.model_call_with_stream(params: dict) -> Generator[str, None, None] {
    if self.proxy {
        client = OpenAI(base_url=self.api_base, api_key=self.api_key,);
        response = client.chat.completions.create(stream=True, **params);
    } else {
        response = litellm.completion(stream=True, **params);
    }
    return response;
}
