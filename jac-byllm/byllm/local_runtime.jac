"""Bundled local-model registry + parsing helpers.

Pure data + helpers — no Python class definitions live here so that
`byllm.llm` can stay the single source of truth for LLM connector
classes (and avoid a circular import with `obj LocalLLM(BaseLLM)`).

The runtime side of `local:<alias>` lives in `llm.jac::LocalLLM`
and `llm.impl/local.impl.jac`.
"""

import logging;
import from typing { Any }

glob _logger: logging.Logger = logging.getLogger("byllm.local_runtime"),
     # Bundled local model registry. Each entry maps an alias the user types
     # (`local:<alias>`) to a HuggingFace GGUF artifact + sensible defaults.
     # Gemma 4 (released 2026-04-02) is the default — E4B is the on-device
     # instruction-tuned variant, ~5 GB at Q4_K_M, and benchmarks at 100%
     # on the mini_todo categorize fixture (see jac/examples/mini_todo/
     # bench_local.jac).
     #
     # `chat_format` is intentionally omitted: every modern instruction-tuned
     # GGUF ships its own Jinja chat template inside the file metadata, and
     # llama-cpp-python uses it when no explicit format is given. Hard-coding
     # `chat_format="gemma"` etc. forces an older template that breaks the
     # newer Qwen 3.5 and Gemma 4 variants.
     LOCAL_MODELS: dict[str, dict] = {
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
     DEFAULT_LOCAL_MODEL: str = "gemma-4-e4b",
     LOCAL_PREFIX: str = "local:";

"""Strip the `local:` prefix and return the bare alias.

Returns None when `model_name` is not a local alias.
"""
def parse_alias(model_name: str) -> str | None {
    if not model_name.startswith(LOCAL_PREFIX) {
        return None;
    }
    return model_name[len(LOCAL_PREFIX):].strip().lower();
}

"""Look up a `local:<alias>` model name in the registry.

Returns the spec dict or None when the alias is unknown.
"""
def resolve_local_alias(model_name: str) -> dict | None {
    alias = parse_alias(model_name);
    if alias is None {
        return None;
    }
    return LOCAL_MODELS.get(alias);
}

"""All registered local-model aliases (without the `local:` prefix)."""
def list_local_aliases -> list[str] {
    return sorted(list(LOCAL_MODELS.keys()));
}

"""Wrap a tool_call dict from llama-cpp so it exposes attribute access.

byllm's BaseLLM.dispatch_no_streaming reads `tool_call.function.name`
and `tool_call.function.arguments` (LiteLLM/OpenAI pydantic shape),
but llama-cpp returns plain dicts. SimpleNamespace bridges the two.
"""
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

"""Flatten OpenAI multimodal content blocks back to a plain string.

byllm builds messages with `content=[{"type": "text", "text": "..."}, ...]`
to leave room for image parts. llama-cpp's stock chat formatters
(gemma, chatml, llama-2, ...) do not understand that list shape and
end up emitting an empty user turn, so the model replies with
generic "Hello! How can I help you today?" filler. We coalesce the
text parts here; non-text parts (images) are passed through verbatim
so multimodal-aware llama-cpp builds still work.
"""
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

"""Normalize a list of LiteLLM messages for llama-cpp consumption."""
def normalize_messages(messages: list) -> list {
    out: list = [];
    for m in messages {
        if isinstance(m, dict) {
            out.append(_flatten_message_content(m));
        } else {
            out.append(m);
        }
    }
    return out;
}

"""Translate OpenAI's structured-output shape into llama-cpp's.

llama-cpp-python's `_grammar_for_response_format` only enforces a
GBNF grammar when `type == "json_object"` (with optional `schema`).
byllm emits OpenAI's `{"type": "json_schema", "json_schema": {...}}`,
which llama-cpp silently ignores — the model then generates free-form
text and downstream JSON parsing fails.

We rewrite the shape so the schema-constrained grammar kicks in.
Anything we don't recognise is passed through verbatim.
"""
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

"""Subset of llama-cpp parameters byllm should forward.

LiteLLM passes a wide param surface; llama-cpp rejects unknown kwargs,
so filter to the intersection. Sentinel zeros (max_tokens=0) are
dropped so the model uses its own default. Messages are flattened
from the OpenAI multimodal list shape (llama.cpp's chat templates
don't understand it). The schema-derived prompt-side hint that small
local models need is injected by `BaseLLM.make_model_params`
(via `byllm.schema.inject_schema_hint`) for *every* backend, not
just this one, so it does not need to be re-applied here.
"""
def filter_params(params: dict) -> dict {
    accepted: set[str] = {"messages","tools","tool_choice","response_format","stop","max_tokens","temperature","top_p","top_k","presence_penalty","frequency_penalty","repeat_penalty","seed"};
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
