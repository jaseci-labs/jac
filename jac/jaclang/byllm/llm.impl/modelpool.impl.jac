import concurrent.futures;
import asyncio;
import copy;
import itertools;

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
    model_list: list[dict[str, any]] = [];
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
        litellm_params: dict[str, any] = {
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
        for key in _MODEL_SETTINGS {
            value = model.call_params.get(key, _call_params_config.get(key));
            if value is not None {
                litellm_params[key] = value;
            }
        }
        model_list.append(
            {
                "model_name": name,
                "litellm_params": litellm_params,
                "model_info": {"id": f"pool-model-id-{i}"},

            }
        );
    }
    if is_fallback {
        self._router = Router(
            model_list=model_list, num_retries=self.num_retries, timeout=self.timeout,
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

impl ModelPool.invoke(mt_run: MTRuntime) -> any {
    if self._run is not mt_run {
        serving = copy.copy(self);
        serving._run = mt_run;
        if self._run is None {
            serving._turn = {};
        }
        return serving.invoke(mt_run);
    }
    return super.invoke(mt_run);
}

impl ModelPool.ainvoke(mt_run: MTRuntime) -> any {
    if self._run is not mt_run {
        serving = copy.copy(self);
        serving._run = mt_run;
        if self._run is None {
            serving._turn = {};
        }
        return await serving.ainvoke(mt_run);
    }
    return await super.ainvoke(mt_run);
}

impl ModelPool.make_model_params(mt_run: MTRuntime) -> dict[str, any] {
    params = super.make_model_params(mt_run);
    for key in _MODEL_SETTINGS {
        if key not in self.call_params {
            params.pop(key, None);
        }
    }
    return params;
}

impl ModelPool._get_ctx_window(call_params: dict[str, any]) -> int {
    `override = int(
        call_params.get("ctx_window")
            or self.ctx_window
            or get_byllm_config().get_compaction_config().get("ctx_window", 0)
            or 0
    );
    if `override > 0 {
        return `override;
    }
    windows: list[int] = [];
    for m in self.models {
        w = m._get_ctx_window({});
        if w > 0 {
            windows.append(w);
        }
    }
    return min(windows) if windows else 0;
}


impl ModelPool._resolve_timeout(mt_run: MTRuntime) -> float | None {
    return None;
}


impl ModelPool._fallback(params: dict[str, any], stream: bool) -> any {
    router: any = self._router;
    request = {
        key: value
        for (key, value) in params.items()
        if key != "model"
    };
    count = len(self.models);
    order = [(self._turn.get("start", 0) + step) % count for step in range(count)];
    for (pos, idx) in enumerate(order) {
        name = self._fallback_model_names[idx];
        try {
            if stream {
                chunks = iter(
                    router._completion(model=name, stream=True, fallbacks=[], **request)
                );
                first = next(chunks, None);
                result = chunks if first is None else itertools.chain([first], chunks);
            } else {
                result = router.completion(
                    model=name, disable_fallbacks=True, **request
                );
            }
        } except Exception as e {
            if pos == count - 1 {
                raise;
            }
            fallback = {
                "from": self.models[idx].model_name,
                "to": self.models[order[pos + 1]].model_name,
                "error": type(e).__name__
            };
            logger.warning(
                f"ModelPool fallback: {fallback['from']} failed ({e}); "
                    + f"trying {fallback['to']}"
            );
            if self._run is not None {
                self._run._fallbacks.append(fallback);
            }
            continue;
        }
        if self.sticky {
            self._turn["start"] = idx;
        }
        return result;
    }
}


impl ModelPool.model_call_no_stream(params: dict[str, any]) -> dict[str, any] {
    assert self._router is not None;
    if self.strategy == "cost-based-routing" {
        coro = self._router.acompletion(**params);
        response: object;
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool {
            response = pool.submit(asyncio.run, coro).result();
        }
    } elif self.strategy == "fallback" {
        response = self._fallback(params, False);
    } else {
        response = self._router.completion(**params);
    }
    return response_dict(response);
}

impl ModelPool.model_call_with_stream(params: dict[str, any]) -> Iterable[object] {
    assert self._router is not None;
    if self.strategy == "cost-based-routing" {
        async def _collect_stream -> list[any] {
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
        return self._fallback(params, True);
    }
    return self._router.completion(stream=True, **params);
}
