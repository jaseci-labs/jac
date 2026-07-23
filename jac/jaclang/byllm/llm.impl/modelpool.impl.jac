import from typing { Generator }
import concurrent.futures;
import asyncio;

impl ModelPool.postinit -> None {
    import from litellm { Router }
    if not self.models {
        raise ValueError("ModelPool requires at least one model.");
    }

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


impl ModelPool.model_call_no_stream(params: dict) -> dict {
    if self.strategy == "cost-based-routing" {
        coro = self._router.acompletion(**params);
        response: dict;
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool {
            response = pool.submit(asyncio.run, coro).result();
        }
        return response;
    }
    return self._router.completion(**params);
}

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
            return pool.submit(asyncio.run, _collect_stream()).result();
        }
    }

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

                    if yielded or idx >= len(model_names) - 1 {
                        raise;
                    }
                }
            }
        }
        return _fallback_gen();
    }
    return self._router.completion(stream=True, **params);
}
