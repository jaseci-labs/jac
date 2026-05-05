"""LocalLLM impl — runs `local:<alias>` models in-process via llama.cpp.

Mirrors the OpenAI/LiteLLM response shape so the rest of byllm's
ReAct loop (BaseLLM.dispatch_no_streaming) doesn't care that the
inference is local.
"""

import from byllm.local_runtime {
    LOCAL_MODELS,
    parse_alias,
    list_local_aliases,
    wrap_tool_call,
    filter_params
}
import from byllm.model_cache { ensure_model }

impl LocalLLM.postinit -> None {
    a = parse_alias(self.model_name);
    if a is None {
        raise ValueError(
            f"LocalLLM expects a 'local:<alias>' model name, got {self.model_name!r}"
        );
    }
    self.alias = a;
    s = LOCAL_MODELS.get(a);
    if s is None {
        raise ValueError(
            f"Unknown local model alias '{a}'. " f"Available: {list_local_aliases()}"
        );
    }
    self.spec = s;
}

"""Build (or return cached) underlying llama.cpp instance."""
impl LocalLLM._ensure_llama -> object {
    if self._llama is not None {
        return self._llama;
    }
    try {
        import from llama_cpp { Llama }
    } except ImportError {
        raise ImportError(
            "llama-cpp-python is required for `local:` models. "
            "Install with: pip install 'byllm[local]'  "
            "(use --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cpu "
            "to skip the source build). For most local-inference use cases, "
            "consider Ollama instead: `default_model = \"ollama/<model>\"`."
        );
    }
    auto_dl = bool(self.config.get("auto_download", False));
    model_path = ensure_model(self.alias, self.spec, auto_download=auto_dl);
    n_ctx = int(self.config.get("n_ctx", 0)) or int(self.spec.get("n_ctx", 4096));
    n_gpu_layers = int(self.config.get("n_gpu_layers", 0));
    chat_format = self.config.get("chat_format") or self.spec.get("chat_format");
    verbose = bool(self.config.get("verbose", False));
    n_threads_cfg = int(self.config.get("n_threads", 0));
    kwargs: dict = {
        "model_path": model_path,
        "n_ctx": n_ctx,
        "n_gpu_layers": n_gpu_layers,
        "verbose": verbose,

    };
    if chat_format {
        kwargs["chat_format"] = chat_format;
    }
    if n_threads_cfg > 0 {
        kwargs["n_threads"] = n_threads_cfg;
    }
    self._llama = Llama(**kwargs);
    return self._llama;
}

impl LocalLLM.model_call_no_stream(params: dict) -> dict {
    engine = self._ensure_llama();
    call_params = filter_params(params);
    resp = engine.create_chat_completion(**call_params);
    # llama-cpp returns OpenAI-shaped dict; coerce tool_calls so attribute
    # access on `.function.name` works downstream (see BaseLLM dispatch).
    if isinstance(resp, dict) {
        choices = resp.get("choices", []);
        for choice in choices {
            if isinstance(choice, dict) {
                msg = choice.get("message");
                if isinstance(msg, dict) {
                    tcs = msg.get("tool_calls");
                    if isinstance(tcs, list) and tcs {
                        msg["tool_calls"] = [wrap_tool_call(tc) for tc in tcs];
                    }
                }
            }
        }
        if "model" not in resp {
            resp["model"] = self.model_name;
        }
    }
    return resp;
}

impl LocalLLM.model_call_with_stream(params: dict) -> Generator[object, None, None] {
    engine = self._ensure_llama();
    call_params = filter_params(params);
    call_params["stream"] = True;
    for chunk in engine.create_chat_completion(**call_params) {
        yield chunk;
    }
}

impl LocalLLM._get_ctx_window(call_params: dict) -> int {
    return int(self.spec.get("n_ctx", 4096));
}
