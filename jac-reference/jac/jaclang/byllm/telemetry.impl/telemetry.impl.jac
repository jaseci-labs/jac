impl register_agent_callback(callback: Callable[[dict[str, any]], None]) -> None {
    if callback not in _agent_callbacks {
        _agent_callbacks.append(callback);
    }
}

impl register_llm_call_hook(hook: Callable[[dict[str, any]], None]) -> None {
    if hook not in _llm_call_hooks {
        _llm_call_hooks.append(hook);
    }
}

impl unregister_llm_call_hook(hook: Callable[[dict[str, any]], None]) -> None {
    if hook in _llm_call_hooks {
        _llm_call_hooks.remove(hook);
    }
}

def _plain_message(msg: any) -> dict[str, any];

impl _notify_llm_call(mt_run: MTRuntime) -> None {
    if not _llm_call_hooks or not mt_run.messages {
        return;
    }
    sent = list(mt_run.messages[mt_run._llm_hook_cursor:-1]);

    if mt_run._llm_hook_cursor == 0 and sent and mt_run._sent_system is not None {
        sent[0] = mt_run._sent_system;
    }
    mt_run._llm_hook_cursor = len(mt_run.messages);
    caller = mt_run.mtir.caller if mt_run.mtir else None;
    usage = dict(mt_run._usage_history[-1]) if mt_run._usage_history else {};
    record: dict[str, any] = {
        "invocation_id": mt_run._invocation_id,
        "parent_invocation_id": mt_run._parent_invocation_id,
        "caller": caller?.__name__,
        "call_kind": usage.get("call_kind") or mt_run._call_kind,
        "new_messages": [_plain_message(m) for m in sent],
        "reply": _plain_message(mt_run.messages[-1]),
        "usage": usage,
        "after_compaction": mt_run._llm_hook_compacted
    };
    mt_run._llm_hook_compacted = False;
    for hook in list(_llm_call_hooks) {
        try {
            hook(record);
        } except Exception as e {
            logger.warning(f"byLLM llm call hook {hook!r} raised: {e}");
        }
    }
}

impl _aggregate_usage(usage_history: list[dict[str, any]]) -> dict[str, object] {
    totals: dict[str, any] = {};
    by_kind: dict[str, any] = {};
    for u in usage_history {
        kind = u.get("call_kind", "react_iteration");
        if kind not in by_kind {
            by_kind[kind] = {};
        }
        for (k, v) in u.items() {
            if isinstance(v, (int, float)) {
                totals[k] = totals.get(k, 0) + v;
                by_kind[kind][k] = by_kind[kind].get(k, 0) + v;
            }
        }
    }
    return {
        "total": totals,
        "by_kind": by_kind,
        "per_call": list(usage_history),
        "requests": len(usage_history)
    };
}

impl _emit_agent_telemetry(
    mt_run: MTRuntime,
    result: object,
    model_name: str,
    latency_ms: float,
    status: str,
    error: Exception | None
) -> None {
    import types as _types_mod;

    user_prompt = "";
    try {
        messages = getattr(mt_run, "messages");
        user_prompt = str(messages[1].content[0].text)[:2000];
    } except Exception as e {
        logger.debug(f"user_prompt extraction failed: {e}");
    }

    caller_args: dict[str, any] = {};
    try {
        mtir = getattr(mt_run, "mtir");
        if mtir and mtir.args {
            for k in mtir.args {
                caller_args[str(k)] = str(mtir.args[k])[:500];
            }
        }
    } except Exception as e {
        logger.debug(f"caller_args extraction failed: {e}");
    }

    conv_history: list[any] = [];
    try {
        conv_history = getattr(mt_run, "get_msg_list")();
    } except Exception as e {
        logger.debug(f"conv_history extraction failed: {e}");
    }

    agent_response = "";
    if result is not None {
        if isinstance(result, _types_mod.GeneratorType) {
            agent_response = "[streaming]";
        } else {
            agent_response = str(result)[:2000];
        }
    }

    tokens: dict[str, any] = {
        "total": {},
        "by_kind": {},
        "per_call": [],
        "requests": 0
    };
    try {
        history = mt_run._usage_history;
        tokens = _aggregate_usage(history);
    } except Exception as e {
        logger.debug(f"tokens aggregation failed: {e}");
    }

    record_mtir = mt_run.mtir;
    record = {
        "invocation_id": mt_run._invocation_id,
        "parent_invocation_id": mt_run._parent_invocation_id,
        "caller_name": record_mtir.caller.__name__ if record_mtir else "unknown",
        "caller_args": caller_args,
        "user_prompt": user_prompt,
        "agent_response": agent_response,
        "conversation_history": conv_history,
        "model": model_name,
        "latency_ms": latency_ms,
        "status": status,
        "error": str(error)[:1000] if error else None,
        "tokens": tokens,
        "compactions": list(mt_run._compactions)
    };

    for callback in _agent_callbacks {
        try {
            callback(record);
        } except Exception as e {
            logger.debug(f"Agent telemetry callback error: {e}");
        }
    }
}

impl _plain_message(msg: any) -> dict[str, any] {
    if isinstance(msg, dict) {
        return dict(msg);
    }
    to_dict = msg?.to_dict;
    if callable(to_dict) {
        return to_dict();
    }
    dump = msg?.model_dump;
    return dump(exclude_none=True) if callable(dump) else {"raw": str(msg)};
}
