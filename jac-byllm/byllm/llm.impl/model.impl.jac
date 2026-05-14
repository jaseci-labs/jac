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
    # Resolve api_key: constructor > instance config > global config
    if not self.api_key {
        self.api_key = self.config.get("api_key", "")
        or _model_config.get("api_key", "");
    }
    # When model_name is 'mockllm', delegate to MockLLM behavior
    if self.model_name == MODEL_MOCK {
        self._mock_delegate = MockLLM(model_name=self.model_name, config=self.config);
    }
    # When model_name starts with 'local:', delegate to in-process llama.cpp.
    # LocalLLM lives alongside MockLLM in byllm.llm so both delegates share
    # the same module and avoid a circular import via local_runtime.jac.
    if self.model_name.startswith("local:") {
        # Forward ctx_window so user overrides on the outer Model reach the
        # compaction layer running inside the delegate.
        self._local_delegate = LocalLLM(
            model_name=self.model_name,
            ctx_window=self.ctx_window,
            config=self.config,
            call_params=self.call_params
        );
    }
    if not self._mock_delegate and not self._local_delegate {
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
    import types as _types_mod;

    # Capture parent invocation if we're inside a nested by llm() call
    _parent = _current_invocation_id.get(None);
    mt_run._parent_invocation_id = _parent;
    mt_run._invocation_id = str(uuid.uuid4());
    _ctx_token = _current_invocation_id.set(mt_run._invocation_id);
    _start = time.time();

    try {
        if self._mock_delegate {
            result = self._mock_delegate.invoke(mt_run);
        } elif self._local_delegate {
            result = self._local_delegate.invoke(mt_run);
        } else {
            result = super.invoke(mt_run);
        }

        # For streaming (generator) results, wrap so ContextVar stays active
        # during lazy iteration — tool calls inside the generator need the parent ID.
        if isinstance(result, _types_mod.GeneratorType) {
            def _wrap_generator(
                gen: object,
                mt: object,
                model_name: str,
                start: float,
                ctx_token: object
            ) -> object {
                _completed = False;
                try {
                    yield from gen;
                    _completed = True;
                } except Exception as inner_e {
                    _emit_agent_telemetry(
                        mt,
                        None,
                        model_name,
                        (time.time() - start) * 1000,
                        "error",
                        inner_e
                    );
                    raise;
                } finally {
                    if _completed {
                        _emit_agent_telemetry(
                            mt,
                            "[streaming]",
                            model_name,
                            (time.time() - start) * 1000,
                            "success",
                            None
                        );
                    }
                    _current_invocation_id.reset(ctx_token);
                }
            }
            return _wrap_generator(result, mt_run, self.model_name, _start, _ctx_token);
        }

        _emit_agent_telemetry(
            mt_run,
            result,
            self.model_name,
            (time.time() - _start) * 1000,
            "success",
            None
        );
        _current_invocation_id.reset(_ctx_token);
        return result;
    } except Exception as e {
        _emit_agent_telemetry(
            mt_run, None, self.model_name, (time.time() - _start) * 1000, "error", e
        );
        _current_invocation_id.reset(_ctx_token);
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
    # Ask the provider to include token usage in the final streamed chunk.
    params["stream_options"] = (params.get("stream_options") or {}) | {
        "include_usage": True
    };
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
