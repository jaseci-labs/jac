"""ModelPool implementation — in-process LiteLLM Router for fallback and load-balancing."""
import from typing { Generator }
import concurrent.futures;
import asyncio;

"""Initialize the ModelPool by building a LiteLLM Router in-process."""
impl ModelPool.postinit -> None {
    import from litellm { Router }
    if not self.models {
        raise ValueError("ModelPool requires at least one model.");
    }
    # Apply jac.toml [plugins.byllm.fallback] defaults for any field the user did not set.
    # None sentinels in the has-fields distinguish "user supplied" from "config default".
    _fallback_cfg = _byllm_config.get_fallback_config();
    if self.strategy is None {
        self.strategy = _fallback_cfg.get('strategy', 'fallback');
    }
    if self.num_retries is None {
        self.num_retries = _fallback_cfg.get('num_retries', 1);
    }
    if self.timeout is None {
        self.timeout = _fallback_cfg.get('timeout', 60.0);
    }
    is_fallback = self.strategy == "fallback";
    model_list: list = [];
    fallback_names: list = [];
    self._fallback_model_names = [];
    for (i, model) in enumerate(self.models) {
        name = (
            ("pool-primary" if i == 0 else f"pool-fallback-{i}")
                if is_fallback
                else "pool-model"
        );
        if is_fallback {
            self._fallback_model_names.append(name);
        }
        litellm_params: dict = {
            "model": model.model_name,
            "api_key": model.api_key or model.config.get("api_key", "") or None,

        };
        base_url = (
            model.config.get("base_url")
            or model.config.get("host")
            or model.config.get("api_base")
        );
        if base_url {
            litellm_params["api_base"] = base_url;
        }
        model_list.append(
            {
                "model_name": name,
                "litellm_params": litellm_params,
                "model_info": {"id": f"pool-model-id-{i}"},

            }
        );
        if is_fallback and i > 0 {
            fallback_names.append(name);
        }
    }
    if is_fallback {
        self._router = Router(
            model_list=model_list,
            fallbacks=[{"pool-primary": fallback_names}],
            num_retries=self.num_retries,
            timeout=self.timeout,
        );
        self.model_name = "pool-primary";
    } else {
        self._router = Router(
            model_list=model_list,
            routing_strategy=self.strategy,
            num_retries=self.num_retries,
            timeout=self.timeout,
        );
        self.model_name = "pool-model";
    }
    if any(m.config.get("verbose", False) for m in self.models) {
        self.config["verbose"] = True;
    }
    logger.info(
        f"ModelPool initialized with {len(self.models)} models, strategy='{self.strategy}'"
    );
}

"""Resolve ctx_window for a ModelPool.

Explicit overrides (call_params > self.ctx_window > config) take priority.
When none are set, takes the minimum across pool members so we never
over-fill the most constrained model in the pool.
"""
impl ModelPool._get_ctx_window(call_params: dict) -> int {
    override = int(
        call_params.get("ctx_window")
        or self.ctx_window
        or get_byllm_config().get_compaction_config().get("ctx_window", 0)
        or 0
    );
    if override > 0 {
        return override;
    }
    windows: list = [];
    for m in self.models {
        w = m._get_ctx_window({});
        if w > 0 {
            windows.append(w);
        }
    }
    return min(windows) if windows else 0;
}


"""Make a direct model call without streaming via the LiteLLM Router.

For most strategies, router.completion() works synchronously. For
cost-based-routing, LiteLLM's sync get_available_deployment() has no handler
for that strategy — deployment selection only exists on the async path via
lowestcost_logger.async_get_available_deployments(). We run acompletion()
in a ThreadPoolExecutor so it is safe inside frameworks with an existing
event loop (FastAPI, Jupyter) — asyncio.run() always gets a fresh loop in
a dedicated thread.
"""
impl ModelPool.model_call_no_stream(params: dict) -> dict {
    if self.strategy == "cost-based-routing" {
        coro = self._router.acompletion(**params);  # type: ignore
        response: dict;
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool {
            response = pool.submit(asyncio.run, coro).result();  # type: ignore
        }
        return response;
    }
    return self._router.completion(**params);  # type: ignore

}

"""Make a streaming model call via the LiteLLM Router.

cost-based-routing uses acompletion() via ThreadPoolExecutor for the same
reason as model_call_no_stream. All other strategies use router.completion().

For fallback strategy, we call Router._completion() per model with
fallbacks=[] to work around a recursive infinite loop in the Router's
stream_with_fallbacks().
"""
impl ModelPool.model_call_with_stream(params: dict) -> Generator[str, None, None] {
    if self.strategy == "cost-based-routing" {
        async def _collect_stream -> list {
            result = await self._router.acompletion(stream=True, **params);
            chunks = [];
            async for chunk in result {
                chunks.append(chunk);
            }
            return chunks;
        }
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool {
            return pool.submit(asyncio.run, _collect_stream()).result();  # type: ignore

        }
    }
    # Fallback strategy: call Router._completion() per model with fallbacks=[]
    # to prevent the recursive stream_with_fallbacks infinite loop.
    if self.strategy == "fallback" {
        model_names: list = self._fallback_model_names;
        router = self._router;
        def _fallback_gen -> Generator {
            for (idx, name) in enumerate(model_names) {
                yielded: bool = False;
                try {
                    call_params: dict = dict(params);
                    call_params.pop("model", None);
                    messages: list = call_params.pop("messages", []);
                    response = router._completion(
                        model=name,
                        messages=messages,
                        stream=True,
                        fallbacks=[],
                        **call_params
                    );
                    for chunk in response {
                        yielded = True;
                        yield chunk;
                    }
                    return;
                } except Exception as exc {
                    logger.warning(
                        f"ModelPool streaming fallback: {name} failed — {exc}"
                    );
                    # If any chunks were already sent to the caller, re-raise.
                    # Falling back now would concatenate a partial response from
                    # this model with a full response from the next — corrupted output.
                    if yielded or idx >= len(model_names) - 1 {
                        raise;
                    }
                }
            }
        }
        return _fallback_gen();
    }
    return self._router.completion(stream=True, **params);  # type: ignore

}
