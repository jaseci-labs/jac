"""Agent-level telemetry callback implementations."""

impl register_agent_callback(callback: Callable) -> None {
    if callback not in _agent_callbacks {
        _agent_callbacks.append(callback);
    }
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

    # --- Extract user_prompt from mt_run messages ---
    user_prompt = "";
    try {
        user_prompt = str(mt_run.messages[1].content[0].text)[:2000];
    } except Exception as e {
        logger.debug(f"user_prompt extraction failed: {e}");
    }

    # --- Extract caller_args from mt_run.mtir ---
    caller_args: dict = {};
    try {
        if mt_run.mtir and mt_run.mtir.args {
            for k in mt_run.mtir.args {
                caller_args[str(k)] = str(mt_run.mtir.args[k])[:500];
            }
        }
    } except Exception as e {
        logger.debug(f"caller_args extraction failed: {e}");
    }

    # --- Extract conversation history ---
    conv_history: list = [];
    try {
        conv_history = mt_run.get_msg_list();
    } except Exception as e {
        logger.debug(f"conv_history extraction failed: {e}");
    }

    # --- Extract agent response ---
    agent_response = "";
    if result is not None {
        if isinstance(result, _types_mod.GeneratorType) {
            agent_response = "[streaming]";
        } else {
            agent_response = str(result)[:2000];
        }
    }

    # --- Build the telemetry record ---
    record = {
        "invocation_id": mt_run._invocation_id,
        "parent_invocation_id": getattr(mt_run, '_parent_invocation_id', None),
        "caller_name": mt_run.mtir.caller.__name__ if mt_run.mtir else "unknown",
        "caller_args": caller_args,
        "user_prompt": user_prompt,
        "agent_response": agent_response,
        "conversation_history": conv_history,
        "model": model_name,
        "latency_ms": latency_ms,
        "status": status,
        "error": str(error)[:1000] if error else None
    };

    # --- Emit to all registered callbacks ---
    for callback in _agent_callbacks {
        try {
            callback(record);
        } except Exception as e {
            logger.debug(f"Agent telemetry callback error: {e}");
        }
    }
}
