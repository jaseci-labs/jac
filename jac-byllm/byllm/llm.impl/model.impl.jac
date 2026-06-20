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
        # Some served models emit tool calls natively but cannot consume tool
        # *results*: their chat template has no `tool` role, so a `role:"tool"`
        # message is silently dropped and the model re-issues the same call
        # forever. Route them through byLLM's text tool protocol instead, where
        # results come back as readable `<tool_response>` text. An explicit
        # `config["native_tools"]` overrides the heuristic either way.
        native_override = self.config.get(
            "native_tools", _model_config.get("native_tools")
        );
        if native_override is not None {
            self.supports_native_tools = bool(native_override);
        } elif _model_lacks_tool_role(self.model_name) {
            self.supports_native_tools = False;
        }
    }
}


# Model families whose chat template has no `tool` role, so tool *results* must
# be fed back as ordinary text. Matched case-insensitively as a substring of the
# model name, so it covers every provider/tag (ollama/gemma4:31b, gemma-2-9b, ...).
glob _NO_TOOL_ROLE_FAMILIES: list[str] = ["gemma"];

"""Whether a model's chat template lacks a usable `tool` role for results."""
def _model_lacks_tool_role(model_name: str) -> bool {
    lowered = model_name.lower();
    for fam in _NO_TOOL_ROLE_FAMILIES {
        if fam in lowered {
            return True;
        }
    }
    return False;
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

        # Streaming: reset the Token now, in the Context that created it. The
        # wrapper carries its own Context, so it never resets a Token from a
        # foreign one — safe to iterate on jac-scale's SSE thread-pool worker.
        if isinstance(result, _types_mod.GeneratorType) {
            _current_invocation_id.reset(_ctx_token);
            return _stream_with_telemetry(result, mt_run, self.model_name, _start);
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

"""Stream a generator with the invocation_id pinned in its own Context.

Captures a copy_context, sets mt._invocation_id in it, and drives each step via
ctx.run(next, gen) — so nested by llm() calls still see the right parent and no
ContextVar Token is reset across Contexts. This keeps the stream safe to consume
from a foreign Context (e.g. jac-scale's SSE thread-pool worker).
"""
def _stream_with_telemetry(
    gen: object, mt: object, model_name: str, start: float
) -> object {
    import contextvars;
    import time;

    invocation_id = mt?._invocation_id;
    ctx = contextvars.copy_context();
    if invocation_id is not None {
        ctx.run(_current_invocation_id.set, invocation_id);
    }

    _completed = False;
    try {
        while True {
            try {
                item = ctx.run(next, gen);
            } except StopIteration {
                _completed = True;
                break;
            }
            yield item;
        }
    } except Exception as inner_e {
        _emit_agent_telemetry(
            mt, None, model_name, (time.time() - start) * 1000, "error", inner_e
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
    import httpx;
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {token}"};
    with httpx.Client(verify=ca_bundle or True, timeout=60.0) as client {
        response = client.post(url=url, headers=headers, json=payload);
    }
    return response.json();
}

"""Async non-streaming call: litellm.acompletion or AsyncOpenAI — never blocks the loop."""
impl Model.model_call_no_stream_async(params: dict) -> dict {
    try {
        if self.http_client {
            response = await self.model_call_http_async(
                url=self.api_base,
                token=self.api_key,
                payload=params,
                ca_bundle=self.config.get("ca_bundle", None),
            );
        } elif self.proxy {
            if not self._async_proxy_client {
                self._async_proxy_client = AsyncOpenAI(
                    base_url=self.api_base, api_key=self.api_key or None
                );
            }
            response = await self._async_proxy_client.chat.completions.create(**params);
        } else {
            response = await litellm.acompletion(
                api_key=self.api_key or None, **params
            );
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

"""Async streaming call: litellm.acompletion(stream=True), AsyncOpenAI, or custom endpoint."""
impl Model.model_call_with_stream_async(params: dict) {
    params["stream_options"] = (params.get("stream_options") or {}) | {
        "include_usage": True
    };
    try {
        if self.http_client {
            response = await self.model_call_http_async(
                url=self.api_base,
                token=self.api_key,
                payload=params | {"stream": True},
                ca_bundle=self.config.get("ca_bundle", None),
            );
        } elif self.proxy {
            if not self._async_proxy_client {
                self._async_proxy_client = AsyncOpenAI(
                    base_url=self.api_base, api_key=self.api_key or None
                );
            }
            response = await self._async_proxy_client.chat.completions.create(
                stream=True, **params
            );
        } else {
            response = await litellm.acompletion(
                stream=True, api_key=self.api_key or None, **params
            );
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

"""Async HTTP call to a custom LLM endpoint via httpx.AsyncClient."""
impl Model.model_call_http_async(
    url: str, token: str, payload: dict, ca_bundle: str
) -> object {
    import httpx;
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {token}"};
    async with httpx.AsyncClient(verify=ca_bundle or True, timeout=60.0) as client {
        response = await client.post(url=url, headers=headers, json=payload);
    }
    return response.json();
}
