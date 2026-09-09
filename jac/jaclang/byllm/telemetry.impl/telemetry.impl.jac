impl register_agent_callback(callback: Callable) -> None {
    if callback not in _agent_callbacks {
        _agent_callbacks.append(callback);
    }
}

impl _aggregate_usage(usage_history: list[dict]) -> dict[str, object] {
    totals: dict = {};
    by_kind: dict = {};
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
    mt_run: object,
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

    caller_args: dict = {};
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

    conv_history: list = [];
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

    tokens: dict = {"total": {}, "by_kind": {}, "per_call": [], "requests": 0};
    try {
        history: any = mt_run._usage_history or [];
        tokens = _aggregate_usage(history);
    } except Exception as e {
        logger.debug(f"tokens aggregation failed: {e}");
    }

    record_mtir = mt_run?.mtir;
    record = {
        "invocation_id": getattr(mt_run, "_invocation_id"),
        "parent_invocation_id": mt_run?._parent_invocation_id,
        "caller_name": record_mtir.caller.__name__ if record_mtir else "unknown",
        "caller_args": caller_args,
        "user_prompt": user_prompt,
        "agent_response": agent_response,
        "conversation_history": conv_history,
        "model": model_name,
        "latency_ms": latency_ms,
        "status": status,
        "error": str(error)[:1000] if error else None,
        "tokens": tokens
    };

    for callback in _agent_callbacks {
        try {
            callback(record);
        } except Exception as e {
            logger.debug(f"Agent telemetry callback error: {e}");
        }
    }
}
