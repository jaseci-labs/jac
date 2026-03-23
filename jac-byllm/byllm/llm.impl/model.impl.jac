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
    # Resolve api_key: constructor > instance config > global config > env vars (litellm fallback)
    self.api_key = (
        self.api_key
        or self.config.get("api_key", "")
        or _model_config.get("api_key", "")
    );
    # When model_name is 'mockllm', delegate to MockLLM behavior
    if self.model_name == MODEL_MOCK {
        self._mock_delegate = MockLLM(model_name=self.model_name, config=self.config);
    }
    if not self._mock_delegate {
        logging.getLogger("httpx").setLevel(logging.WARNING);
        if not _litellm_config.get("debug", False) {
            _disable_debugging();
        }
        litellm.drop_params = _litellm_config.get("drop_params", True);
    }
}

"""Invoke the LLM, delegating to MockLLM if applicable.

Wraps the full invocation with telemetry. Sets a unique invocation_id
on mt_run, then delegates all telemetry extraction to _emit_agent_telemetry.
"""
impl Model.invoke(mt_run: MTRuntime) -> object {
    import uuid;
    import time;

    mt_run._invocation_id = str(uuid.uuid4());
    _start = time.time();

    try {
        result = self._mock_delegate.invoke(mt_run)
            if self._mock_delegate
            else super.invoke(mt_run);

        _emit_agent_telemetry(
            mt_run,
            result,
            self.model_name,
            (time.time() - _start) * 1000,
            "success",
            None
        );
        return result;
    } except Exception as e {
        _emit_agent_telemetry(
            mt_run, None, self.model_name, (time.time() - _start) * 1000, "error", e
        );
        raise;
    }
}

"""Make a direct model call without streaming.

Uses OpenAI client if proxy mode is enabled, otherwise uses LiteLLM.
If _http_client is provided in config, uses direct HTTP requests.
"""
impl Model.model_call_no_stream(params: dict) -> dict {
    try {
        if self.http_client {
            response = self.model_call_http(
                url=self.api_base,
                token=self.api_key,
                payload=params,
                ca_bundle=self.config.get("ca_bundle", None),
            );
        } elif self.proxy {
            client = OpenAI(base_url=self.api_base, api_key=self.api_key or None);
            response = client.chat.completions.create(**params);
        } else {
            response = litellm.completion(api_key=self.api_key or None, **params);
        }
    } except litellm.exceptions.AuthenticationError as e {
        logger.error(f"LLM AuthenticationError: {e}");
        raise AuthenticationError(str(e));
    } except openai.AuthenticationError as e {
        logger.error(f"LLM AuthenticationError: {e}");
        raise AuthenticationError(str(e));
    } except litellm.exceptions.RateLimitError as e {
        logger.error(f"LLM RateLimitError: {e}");
        raise RateLimitError(str(e));
    } except openai.RateLimitError as e {
        logger.error(f"LLM RateLimitError: {e}");
        raise RateLimitError(str(e));
    } except litellm.exceptions.NotFoundError as e {
        logger.error(f"LLM ModelNotFoundError: {e}");
        raise ModelNotFoundError(str(e));
    } except openai.NotFoundError as e {
        logger.error(f"LLM ModelNotFoundError: {e}");
        raise ModelNotFoundError(str(e));
    } except Exception as e {
        logger.error(f"LLM call failed with {type(e).__name__}: {e}");
        raise;
    }
    return response;
}

"""Make a direct model call with streaming.

Uses OpenAI client if proxy mode is enabled, otherwise uses LiteLLM.
Returns a generator that yields response chunks.
"""
impl Model.model_call_with_stream(params: dict) {
    try {
        if self.proxy {
            client = OpenAI(base_url=self.api_base, api_key=self.api_key or None);
            response = client.chat.completions.create(stream=True, **params);
        } else {
            response = litellm.completion(
                stream=True, api_key=self.api_key or None, **params
            );
        }
    } except litellm.exceptions.AuthenticationError as e {
        raise AuthenticationError(str(e));
    } except openai.AuthenticationError as e {
        raise AuthenticationError(str(e));
    } except litellm.exceptions.RateLimitError as e {
        raise RateLimitError(str(e));
    } except openai.RateLimitError as e {
        raise RateLimitError(str(e));
    } except litellm.exceptions.NotFoundError as e {
        raise ModelNotFoundError(str(e));
    } except openai.NotFoundError as e {
        raise ModelNotFoundError(str(e));
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
