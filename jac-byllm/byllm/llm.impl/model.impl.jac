"""Post-initialization hook for Model.

Sets up proxy mode and mock delegation based on config.
Configures logging when using real LLM backends.
"""
impl Model.postinit -> None {
    # Check instance config first, then fall back to global config
    self.proxy = bool(self.config.get("proxy", _model_config.get("proxy", False)));
    self.http_client = bool(
        self.config.get("http_client", _model_config.get("http_client", False))
    );
    # When model_name is 'mockllm', delegate to MockLLM behavior
    if self.model_name == MODEL_MOCK {
        self._mock_delegate = MockLLM(model_name=self.model_name, config=self.config);
    }
    if not self._mock_delegate {
        logging.getLogger("httpx").setLevel(logging.WARNING);
        _disable_debugging();
        # Use drop_params from config
        litellm.drop_params = _litellm_config.get("drop_params", True);
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
If _http_client is provided in config, uses direct HTTP requests.
"""
impl Model.model_call_no_stream(params: dict) -> dict {
    if self.http_client {
        response = self.model_call_http(
            url=self.api_base,
            token=self.api_key,
            payload=params,
            ca_bundle=self.config.get("ca_bundle", None),
        );
    } elif self.proxy {
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
impl Model.model_call_with_stream(params: dict) {
    if self.proxy {
        client = OpenAI(base_url=self.api_base, api_key=self.api_key,);
        response = client.chat.completions.create(stream=True, **params);
    } else {
        response = litellm.completion(stream=True, **params);
    }
    return response;
}

"""Make a direct HTTP request to LLM endpoint.

Useful for custom endpoints with specific SSL/mTLS requirements.
"""
impl Model.model_call_http(
    url: str, token: str, payload: dict, ca_bundle: str
) -> object {
    import requests;
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {token}"};
    response = requests.post(
        url=url, headers=headers, json=payload, timeout=60, verify=ca_bundle or True,
    );
    return response.json();
}
