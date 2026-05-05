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

"""Pretty-print enum-typed schema property as `1=WORK, 2=PERSONAL, ...`.

Used when building prompt-side hints so small local models can pair
each grammar-allowed integer with its human-meaningful label. Pairs
up to the shorter of the two lists when they disagree (byllm's
schema-gen can emit a longer name list than enum values).
"""
def _format_enum_hint(values: list, names: list) -> str {
    if not values {
        return "";
    }
    pairs: list[str] = [];
    for (i, v) in enumerate(values) {
        if i < len(names) {
            pairs.append(f"{v}={names[i]}");
        } else {
            pairs.append(f"{v}");
        }
    }
    return ", ".join(pairs);
}

"""Recursively pull human-readable hints out of a JSON-Schema property.

Returns a list of bullet-style lines describing the constraint. Cloud
providers' server-side prompt builders effectively do this when given
`response_format`; llama-cpp-python doesn't, so we replicate it here.
"""
def _hints_from_schema(name: str, prop: dict) -> list[str] {
    out: list[str] = [];
    if not isinstance(prop, dict) {
        return out;
    }
    desc = prop.get("description");
    enum_vals = prop.get("enum");
    ty = prop.get("type", "");
    label = name or "value";
    if isinstance(enum_vals, list) and enum_vals {
        # If the description happens to also list names, weave them in.
        # byllm's enum schema description encodes member names as a Python
        # list (e.g. "the names are [WORK, PERSONAL, ...]") — pull them out.
        names: list[str] = [];
        if isinstance(desc, str) and "names are [" in desc {
            chunk = desc.split("names are [", 1)[1];
            chunk = chunk.split("]", 1)[0];
            names = [
                n.strip()
                for n in chunk.split(",")
                if n.strip()
            ];
        }
        hint = _format_enum_hint(enum_vals, names);
        if hint {
            out.append(f"- {label} must be one of: {hint}");
        } else {
            out.append(f"- {label} must be one of: {enum_vals}");
        }
    } elif ty {
        out.append(
            f"- {label} ({ty}){' — ' + desc if isinstance(desc, str) and desc else ''}"
        );
    }
    # Recurse into nested object properties.
    if prop.get("type") == "object" {
        nested = prop.get("properties");
        if isinstance(nested, dict) {
            for (sub, sub_prop) in nested.items() {
                if sub != name {
                    out.extend(_hints_from_schema(sub, sub_prop));
                }
            }
        }
    }
    return out;
}

"""Build a human-readable hint block from a normalised response_format.

Walks the schema's top-level properties and emits a few bullet lines
explaining what each field means. Returns "" when there's nothing
useful to say.
"""
def schema_to_hint_text(rf: dict | None) -> str {
    if not isinstance(rf, dict) {
        return "";
    }
    schema = rf.get("schema") if rf.get("type") == "json_object" else None;
    if not isinstance(schema, dict) {
        return "";
    }
    props = schema.get("properties");
    if not isinstance(props, dict) {
        return "";
    }
    lines: list[str] = [];
    for (name, prop) in props.items() {
        if isinstance(prop, dict) {
            lines.extend(_hints_from_schema(name, prop));
        }
    }
    if not lines {
        return "";
    }
    return "Schema requirements:\n" + "\n".join(lines);
}

"""Append a schema-derived hint to the last user message.

In-place rewrite of the messages list. We append rather than prepend
so the request itself stays the visual lead and the constraint reads
as a postscript — same flow cloud providers' server-side builders use.
"""
def attach_schema_hint(messages: list, rf: dict | None) -> list {
    hint: str = schema_to_hint_text(rf);
    if not hint or not messages {
        return messages;
    }
    last_user_idx: int = -1;
    for (i, m) in enumerate(messages) {
        if isinstance(m, dict) {
            mdict: dict = m;
            if mdict.get("role") == "user" {
                last_user_idx = i;
            }
        }
    }
    if last_user_idx < 0 {
        return messages;
    }
    out: list = list(messages);
    target_raw = out[last_user_idx];
    if not isinstance(target_raw, dict) {
        return messages;
    }
    target: dict = dict(target_raw);
    body = target.get("content", "");
    if isinstance(body, str) {
        body_str: str = body;
        target["content"] = body_str.rstrip() + "\n\n" + hint;
    } else {
        # If the message still has multimodal list-content, the
        # caller will have flattened it via normalize_messages first;
        # treat anything else as a no-op.
        return messages;
    }
    out[last_user_idx] = target;
    return out;
}

"""Subset of llama-cpp parameters byllm should forward.

LiteLLM passes a wide param surface; llama-cpp rejects unknown kwargs,
so filter to the intersection. Sentinel zeros (max_tokens=0) are
dropped so the model uses its own default. Messages are also
flattened from the OpenAI multimodal list shape.
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
        # Inject the schema's human-readable hints into the prompt itself.
        # llama-cpp's GBNF only constrains output structure, so without
        # this step a small local model never sees the enum names or
        # property descriptions cloud providers' server-side prompt
        # builders inject for free.
        if "messages" in out and isinstance(out["messages"], list) {
            out["messages"] = attach_schema_hint(
                out["messages"], out["response_format"]
            );
        }
    }
    return out;
}
