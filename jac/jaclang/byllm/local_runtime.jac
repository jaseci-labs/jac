import json;

glob LOCAL_MODELS: dict[str, dict] = {
         "gemma-4-e4b": {
             "repo": "unsloth/gemma-4-E4B-it-GGUF",
             "file": "gemma-4-E4B-it-Q4_K_M.gguf",
             "size_mb": 5000,
             "n_ctx": 8192,
             "description": "Google Gemma 4 E4B (instruction-tuned, Q4_K_M)"
         },
         "gemma-4-e2b": {
             "repo": "unsloth/gemma-4-E2B-it-GGUF",
             "file": "gemma-4-E2B-it-Q4_K_M.gguf",
             "size_mb": 2500,
             "n_ctx": 8192,
             "description": "Google Gemma 4 E2B (smaller, faster)"
         },
         "qwen3.5-4b": {
             "repo": "unsloth/Qwen3.5-4B-GGUF",
             "file": "Qwen3.5-4B-Q4_K_M.gguf",
             "size_mb": 2800,
             "n_ctx": 8192,
             "description": "Alibaba Qwen 3.5 4B (instruction-tuned, Q4_K_M)"
         }
     },
     LOCAL_PREFIX: str = "local:";

def parse_alias(model_name: str) -> str | None {
    if not model_name.startswith(LOCAL_PREFIX) {
        return None;
    }
    return model_name[len(LOCAL_PREFIX):].strip().lower();
}

def list_local_aliases -> list[str] {
    return sorted(list(LOCAL_MODELS.keys()));
}

def wrap_tool_call(tc: dict) -> object {
    import from types { SimpleNamespace }
    fn = tc.get("function", {});
    return SimpleNamespace(
        id=tc.get("id", ""),
        type=tc.get("type", "function"),
        function=SimpleNamespace(
            name=fn.get("name", ""), arguments=fn.get("arguments", "")
        )
    );
}

def _flatten_message_content(msg: dict) -> dict {
    content = msg.get("content");
    if not isinstance(content, list) {
        return msg;
    }
    text_chunks: list[str] = [];
    has_non_text = False;
    for part in content {
        if isinstance(part, dict) and part.get("type") == "text" {
            text_chunks.append(str(part.get("text", "")));
        } else {
            has_non_text = True;
        }
    }
    if has_non_text {
        return msg;
    }
    new_msg: dict = dict(msg);
    new_msg["content"] = "\n".join(text_chunks);
    return new_msg;
}

def _coerce_tool_calls(msg: dict) -> dict {
    tcs = msg.get("tool_calls");
    if not isinstance(tcs, list) or not tcs {
        return msg;
    }
    changed = False;
    coerced: list = [];
    for tc in tcs {
        if isinstance(tc, dict) {
            coerced.append(tc);
            continue;
        }
        fn = tc?.function;
        fn_args = getattr(fn, "arguments", "") or "";
        if not isinstance(fn_args, str) {
            fn_args = json.dumps(fn_args);
        }
        coerced.append(
            {
                "id": str(getattr(tc, "id", "") or ""),
                "type": "function",
                "function": {
                    "name": str(getattr(fn, "name", "") or ""),
                    "arguments": fn_args
                }
            }
        );
        changed = True;
    }
    if not changed {
        return msg;
    }
    new_msg: dict = dict(msg);
    new_msg["tool_calls"] = coerced;
    return new_msg;
}

def normalize_messages(messages: list) -> list {
    out: list = [];
    for m in messages {
        if isinstance(m, dict) {
            out.append(_coerce_tool_calls(_flatten_message_content(m)));
        } else {
            out.append(m);
        }
    }
    return out;
}

def normalize_response_format(rf: dict | None) -> dict | None {
    if not isinstance(rf, dict) {
        return rf;
    }
    if rf.get("type") == "json_schema" {
        js = rf.get("json_schema") or {};
        schema = js.get("schema") if isinstance(js, dict) else None;
        translated: dict = {"type": "json_object"};
        if isinstance(schema, dict) {
            translated["schema"] = schema;
        }
        return translated;
    }
    return rf;
}

def filter_params(params: dict) -> dict {
    accepted: set[str] = {
        "messages",
        "tools",
        "tool_choice",
        "response_format",
        "stop",
        "max_tokens",
        "temperature",
        "top_p",
        "top_k",
        "presence_penalty",
        "frequency_penalty",
        "repeat_penalty",
        "seed"
    };
    out: dict = {};
    for (k, v) in params.items() {
        if k in accepted and v is not None {
            out[k] = v;
        }
    }
    if "max_tokens" in out {
        mt = out["max_tokens"];
        if mt is None or mt == 0 {
            out.pop("max_tokens", None);
        }
    }
    if "messages" in out and isinstance(out["messages"], list) {
        out["messages"] = normalize_messages(out["messages"]);
    }
    if "response_format" in out {
        out["response_format"] = normalize_response_format(out["response_format"]);
    }
    return out;
}
