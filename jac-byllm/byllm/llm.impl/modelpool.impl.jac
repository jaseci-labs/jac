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
    for (i, model) in enumerate(self.models) {
        name = (
            ("pool-primary" if i == 0 else f"pool-fallback-{i}")
                if is_fallback
                else "pool-model"
        );
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
    return self._router.completion(stream=True, **params);  # type: ignore

}
