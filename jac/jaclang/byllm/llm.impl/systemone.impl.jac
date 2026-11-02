impl SystemOneModel.postinit -> None {
    (named_provider, named_model) = resolve_model_name(self.model_name);
    provider = self.provider or named_provider;
    cfg_provider = self.config.get("provider");
    if not self.provider and isinstance(cfg_provider, str) and cfg_provider {
        provider = cfg_provider;
    }
    self.provider = provider;

    base = caps_for(provider);
    caps = ProviderCaps(
        base_url=base.base_url,
        key_env=base.key_env,
        model=base.model,
        max_choice_options=int(
            self.config.get("max_choice_options", base.max_choice_options)
        ),
        max_state_chars=int(self.config.get("max_state_chars", base.max_state_chars)),
        supports_batch=base.supports_batch,
        route=base.route,
        key_env_aliases=list(base.key_env_aliases)
    );
    self._caps = caps;
    self._so1_model = named_model
        or str(self.config.get("model", "") or "")
        or caps.model;

    if not self.api_base {
        self.api_base = str(self.config.get("api_base", "") or "") or caps.base_url;
    }
    if not self.route {
        self.route = str(self.config.get("route", "") or "") or caps.route;
    }
    self.api_key = resolve_api_key(
        caps, self.api_key or str(self.config.get("api_key", "") or "")
    );

    fb = self.config.get("fallback");
    if self.fallback is None and fb is not None {
        self.fallback = fb if isinstance(fb, BaseLLM) else Model(model_name=str(fb));
    }
    mc = self.config.get("min_confidence");
    if mc is not None and not self.min_confidence {
        self.min_confidence = float(mc);
    }
}


impl SystemOneModel._endpoint -> str {
    return self.api_base.rstrip("/") + self.route;
}


impl SystemOneModel._headers -> dict[str, str] {
    headers = {"Content-Type": "application/json"};
    if self.api_key {
        headers["Authorization"] = f"Bearer {self.api_key}";
    }
    return headers;
}


impl SystemOneModel._request(payload: dict[str, any]) -> tuple[int, dict[str, any]] {
    import json;
    import ssl;
    import from urllib.error { HTTPError, URLError }
    import from urllib.request { Request, urlopen }

    req = Request(
        self._endpoint(),
        data=json.dumps(payload).encode("utf-8"),
        headers=self._headers(),
        method="POST"
    );
    ca = self.config.get("ca_bundle", None);
    ctx = ssl.create_default_context(cafile=ca) if isinstance(ca, str) and ca else None;
    status = 0;
    text = "";
    try {
        with urlopen(req, timeout=60.0, context=ctx) as resp {
            status = int(resp.status);
            text = resp.read().decode("utf-8", "replace");
        }
    } except HTTPError as e {
        status = int(e.code);
        try {
            text = e.read().decode("utf-8", "replace");
        } except Exception {
            text = str(e);
        }
    } except URLError as e {
        raise ByLLMError(
            f"System One endpoint unreachable at {self._endpoint()}: {e.reason}"
        );
    }
    body: dict[str, any] = {};
    try {
        parsed = json.loads(text) if text else {};
        body = parsed if isinstance(parsed, dict) else {"raw": parsed};
    } except Exception {
        body = {"raw": text};
    }
    return (status, body);
}


impl SystemOneModel._arequest(payload: dict[str, any]) -> tuple[int, dict[str, any]] {
    import asyncio;

    return await asyncio.to_thread(self._request, payload);
}


impl SystemOneModel._map_status(status: int, body: dict[str, any]) -> None {
    if 200 <= status < 300 {
        return;
    }
    msg = str(body.get("error") or body.get("detail") or body.get("raw") or body)[:400];
    if status == 401 {
        raise AuthenticationError(
            f"System One endpoint rejected the API key (401): {msg}"
        );
    }
    if status in (429, 529) {
        raise RateLimitError(
            f"System One endpoint is rate limited or overloaded ({status}): {msg}"
        );
    }
    if status == 422 {
        raise ConfigurationError(
            f"System One endpoint rejected the request (422): {msg}"
        );
    }
    raise ByLLMError(f"System One endpoint returned {status}: {msg}");
}


impl SystemOneModel._post(payload: dict[str, any]) -> dict[str, any] {
    import time;

    attempt = 0;
    while True {
        (status, body) = self._request(payload);
        if status in (429, 529) and attempt < self._max_retries {
            attempt += 1;
            time.sleep(0.5 * attempt);
            continue;
        }
        self._map_status(status, body);
        return body;
    }
}


impl SystemOneModel._apost(payload: dict[str, any]) -> dict[str, any] {
    import asyncio;

    attempt = 0;
    while True {
        (status, body) = await self._arequest(payload);
        if status in (429, 529) and attempt < self._max_retries {
            attempt += 1;
            await asyncio.sleep(0.5 * attempt);
            continue;
        }
        self._map_status(status, body);
        return body;
    }
}


impl SystemOneModel._record(
    mt_run: MTRuntime, body: dict[str, any], confidence: float, probs: dict[str, any]
) -> None {
    raw_usage = body.get("usage");
    usage: dict[str, any] = raw_usage if isinstance(raw_usage, dict) else {};
    tin = int(usage.get("input_tokens", 0) or 0);
    tout = int(usage.get("output_tokens", 0) or 0);
    mt_run._usage_history.append(
        {
            "prompt_tokens": tin,
            "completion_tokens": tout,
            "total_tokens": tin + tout,
            "call_kind": "systemone",
            "model": body.get("model", self._so1_model),
            "systemone": {
                "provider": self.provider,
                "confidence": confidence,
                "probabilities": probs
            }
        }
    );
    setattr(mt_run, "_so1_confidence", confidence);
    setattr(mt_run, "_so1_probabilities", probs);
}


impl SystemOneModel._finish(
    mt_run: MTRuntime, spec: SystemOneSpec, body: dict[str, any]
) -> tuple[object, bool] {
    answers = body.get("answers");
    if not isinstance(answers, dict) {
        raise OutputConversionError("System One response carried no answers");
    }
    (value, confidence) = assemble(spec, answers);
    probs = distribution(spec, answers);
    self._record(mt_run, body, confidence, probs);
    escalate = (
        self.min_confidence > 0.0
        and confidence < self.min_confidence
        and self.fallback is not None
    );
    return (wrap_result(spec, value, confidence, probs), escalate);
}


impl SystemOneModel._no_fallback(reason: str) -> ConfigurationError {
    return ConfigurationError(
        f"SystemOneModel cannot serve this call ({reason}) and no fallback model "
        "is configured; pass fallback=Model(...) to route it to a chat model"
    );
}


impl SystemOneModel._unwrap_for_fallback(mt_run: MTRuntime) -> (type | None) {
    original: (type | None) = mt_run.resp_type;
    probe: object = original;
    if isinstance(probe, type) and issubclass(probe, Decision) {
        mt_run.resp_type = probe?._jac_inner;
    }
    return original;
}


impl SystemOneModel._rewrap(
    original: (type | None), value: object, confidence: float
) -> object {
    if not (isinstance(original, type) and issubclass(original, Decision)) {
        return value;
    }
    if isinstance(value, Decision) {
        return value;
    }
    return Decision(
        value=value, confidence=confidence, probabilities={}, answered_by="fallback"
    );
}


impl SystemOneModel._via_fallback(
    fb: BaseLLM, mt_run: MTRuntime, confidence: float
) -> any {
    original = self._unwrap_for_fallback(mt_run);
    try {
        value = fb.invoke(mt_run);
    } finally {
        mt_run.resp_type = original;
    }
    return self._rewrap(original, value, confidence);
}


impl SystemOneModel._avia_fallback(
    fb: BaseLLM, mt_run: MTRuntime, confidence: float
) -> any {
    original = self._unwrap_for_fallback(mt_run);
    try {
        value = await fb.ainvoke(mt_run);
    } finally {
        mt_run.resp_type = original;
    }
    return self._rewrap(original, value, confidence);
}


impl SystemOneModel.invoke(mt_run: MTRuntime) -> any {
    fb = self.fallback;
    spec = lower(mt_run, self._caps);
    if spec is None {
        if fb is None {
            raise self._no_fallback("the return type or call shape is not closed-set");
        }
        return self._via_fallback(fb, mt_run, 0.0);
    }
    body: dict[str, any] = {};
    try {
        body = self._post(spec.to_payload(self._so1_model));
    } except AuthenticationError {
        raise;
    } except ByLLMError {
        if fb is None {
            raise;
        }
        return self._via_fallback(fb, mt_run, 0.0);
    }
    (value, escalate) = self._finish(mt_run, spec, body);
    if escalate and fb is not None {
        return self._via_fallback(
            fb, mt_run, float(getattr(mt_run, "_so1_confidence", 0.0))
        );
    }
    return value;
}


impl SystemOneModel.ainvoke(mt_run: MTRuntime) -> any {
    fb = self.fallback;
    spec = lower(mt_run, self._caps);
    if spec is None {
        if fb is None {
            raise self._no_fallback("the return type or call shape is not closed-set");
        }
        return await self._avia_fallback(fb, mt_run, 0.0);
    }
    body: dict[str, any] = {};
    try {
        body = await self._apost(spec.to_payload(self._so1_model));
    } except AuthenticationError {
        raise;
    } except ByLLMError {
        if fb is None {
            raise;
        }
        return await self._avia_fallback(fb, mt_run, 0.0);
    }
    (value, escalate) = self._finish(mt_run, spec, body);
    if escalate and fb is not None {
        return await self._avia_fallback(
            fb, mt_run, float(getattr(mt_run, "_so1_confidence", 0.0))
        );
    }
    return value;
}


impl MockSystemOne._request(payload: dict[str, any]) -> tuple[int, dict[str, any]] {
    self.seen.append(payload);
    if not self.answers {
        raise ByLLMError("MockSystemOne has no scripted answer left for this request");
    }
    reply = self.answers.pop(0);
    if isinstance(reply, tuple) {
        (status, body) = reply;
        return (int(status), dict(body));
    }
    return (
        200,
        {
            "model": self._so1_model,
            "answers": reply,
            "usage": {"input_tokens": 0, "output_tokens": 0}
        }
    );
}


impl MockSystemOne.exhausted -> bool {
    return not self.answers;
}
