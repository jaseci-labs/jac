"""LLM Usage Limits Implementation for JAC-Scale."""
import logging;
import threading;
import time;
import functools;
import from datetime { datetime, UTC, timedelta }
import from typing { Any }
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jaclang.runtimelib.transport { TransportResponse, Meta }
import from jac_scale.jserver.jserver {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}
glob logger = logging.getLogger(__name__);

obj LLMUserLimits {
    """Per-user limit configuration."""
    has username: str = "",
        budget_limit: float = 0.0,
        budget_period: str = "monthly",
        budget_reset_at: str = "",
        rpm_limit: int = 0,
        tpm_limit: int = 0,
        allowed_models: list = [],
        enabled: bool = True,
        updated_at: str = "";

    def to_dict -> dict {
        return {
            "username": self.username,
            "budget_limit": self.budget_limit,
            "budget_period": self.budget_period,
            "budget_reset_at": self.budget_reset_at,
            "rpm_limit": self.rpm_limit,
            "tpm_limit": self.tpm_limit,
            "allowed_models": self.allowed_models,
            "enabled": self.enabled,
            "updated_at": self.updated_at
        };
    }
}


"""Compute the next budget reset timestamp for a given period."""
def _compute_next_reset(period: str, from_time: Any = None) -> str {
    now = from_time if from_time else datetime.now(UTC);
    if period == "daily" {
        # Next midnight UTC
        next_reset = (now + timedelta(days=1)).replace(
            hour=0, minute=0, second=0, microsecond=0
        );
    } elif period == "weekly" {
        # Next Monday midnight UTC
        days_until_monday = (7 - now.weekday()) % 7;
        if days_until_monday == 0 {
            days_until_monday = 7;
        }
        next_reset = (now + timedelta(days=days_until_monday)).replace(
            hour=0, minute=0, second=0, microsecond=0
        );
    } elif period == "monthly" {
        # 1st of next month midnight UTC
        if now.month == 12 {
            next_reset = now.replace(
                year=now.year + 1, month=1, day=1,
                hour=0, minute=0, second=0, microsecond=0
            );
        } else {
            next_reset = now.replace(
                month=now.month + 1, day=1,
                hour=0, minute=0, second=0, microsecond=0
            );
        }
    } else {
        # Default to monthly for unknown periods
        if now.month == 12 {
            next_reset = now.replace(
                year=now.year + 1, month=1, day=1,
                hour=0, minute=0, second=0, microsecond=0
            );
        } else {
            next_reset = now.replace(
                month=now.month + 1, day=1,
                hour=0, minute=0, second=0, microsecond=0
            );
        }
    }
    return next_reset.isoformat();
}


obj LLMUsageCounters {
    """Per-user usage tracking for the current period."""
    has username: str = "",
        period: str = "",
        total_cost: float = 0.0,
        total_tokens: int = 0,
        request_count_minute: int = 0,
        token_count_minute: int = 0,
        minute_window: int = 0,
        total_requests: int = 0,
        updated_at: str = "";

    def to_dict -> dict {
        return {
            "username": self.username,
            "period": self.period,
            "total_cost": round(self.total_cost, 6),
            "total_tokens": self.total_tokens,
            "total_requests": self.total_requests,
            "request_count_minute": self.request_count_minute,
            "token_count_minute": self.token_count_minute,
            "minute_window": self.minute_window,
            "updated_at": self.updated_at
        };
    }
}


glob ANONYMOUS_USER: str = "__anonymous__";


obj LLMLimitsStore {
    """Thread-safe limits store backed by MongoDB (with in-memory fallback)."""
    has _lock: Any = None,
        _limits: dict = {},
        _usage: dict = {},
        _db: Any = None,
        _log_buffer: list = [],
        _log_buffer_lock: Any = None,
        _limits_collection: str = "llm_user_limits",
        _usage_collection: str = "llm_user_usage",
        _log_collection: str = "llm_usage_log";

    def postinit -> None {
        self._lock = threading.Lock();
        self._log_buffer_lock = threading.Lock();
        self._limits = {};
        self._usage = {};
        self._log_buffer = [];
        # Try to connect to MongoDB
        try {
            import from jac_scale.config_loader { get_scale_config }
            db_config = get_scale_config().get_database_config();
            mongo_uri = db_config.get('mongodb_uri');
            if mongo_uri {
                import from pymongo { MongoClient }
                client = MongoClient(mongo_uri);
                self._db = client.get_default_database();
                # Create indexes
                self._db[self._limits_collection].create_index("username", unique=True);
                self._db[self._usage_collection].create_index(
                    [("username", 1), ("period", 1)], unique=True
                );
                self._db[self._log_collection].create_index("timestamp");
                self._db[self._log_collection].create_index("username");
                self._db[self._log_collection].create_index(
                    [("username", 1), ("timestamp", -1)]
                );
                logger.info("LLM limits: MongoDB storage initialized");
            } else {
                logger.warning(
                    "LLM limits: NO MongoDB configured — usage data will NOT persist across restarts. "
                    "Configure [plugins.scale.database.mongodb_uri] for production use."
                );
            }
        } except Exception as e {
            logger.warning(f"LLM limits: MongoDB init failed, usage will NOT persist: {e}");
            self._db = None;
        }
    }

    # ── Limits CRUD ──────────────────────────────────────────────────────

    """Get limits for a user, falling back to __default__ if none set."""
    def get_user_limits(username: str) -> dict | None {
        now_str = datetime.now(UTC).isoformat();
        if self._db {
            doc = self._db[self._limits_collection].find_one({"username": username});
            if not doc {
                doc = self._db[self._limits_collection].find_one(
                    {"username": "__default__"}
                );
            }
            if doc {
                doc.pop("_id", None);
                return doc;
            }
            return None;
        }
        with self._lock {
            if username in self._limits {
                return self._limits[username].to_dict();
            }
            if "__default__" in self._limits {
                return self._limits["__default__"].to_dict();
            }
            return None;
        }
    }

    """Set or update limits for a specific user."""
    def set_user_limits(username: str, limits: dict) -> dict {
        now_str = datetime.now(UTC).isoformat();
        budget_period = limits.get("budget_period", "monthly") or "monthly";
        # Compute reset timestamp if not explicitly provided
        budget_reset_at = limits.get("budget_reset_at", "");
        if not budget_reset_at {
            budget_reset_at = _compute_next_reset(budget_period);
        }
        # Support legacy budget_limit_monthly field
        budget_val = limits.get("budget_limit", 0) or limits.get("budget_limit_monthly", 0);
        doc = {
            "username": username,
            "budget_limit": float(budget_val or 0),
            "budget_period": budget_period,
            "budget_reset_at": budget_reset_at,
            "rpm_limit": int(limits.get("rpm_limit", 0)),
            "tpm_limit": int(limits.get("tpm_limit", 0)),
            "allowed_models": limits.get("allowed_models", []),
            "enabled": limits.get("enabled", True),
            "updated_at": now_str
        };
        if self._db {
            self._db[self._limits_collection].update_one(
                {"username": username},
                {"$set": doc},
                upsert=True
            );
        }
        with self._lock {
            self._limits[username] = LLMUserLimits(
                username=doc["username"],
                budget_limit=doc["budget_limit"],
                budget_period=doc["budget_period"],
                budget_reset_at=doc["budget_reset_at"],
                rpm_limit=doc["rpm_limit"],
                tpm_limit=doc["tpm_limit"],
                allowed_models=doc["allowed_models"],
                enabled=doc["enabled"],
                updated_at=now_str
            );
        }
        return doc;
    }

    """Set the default limits applied to users without specific limits."""
    def set_default_limits(limits: dict) -> dict {
        return self.set_user_limits("__default__", limits);
    }

    """Get the default limits."""
    def get_default_limits -> dict | None {
        if self._db {
            doc = self._db[self._limits_collection].find_one(
                {"username": "__default__"}
            );
            if doc {
                doc.pop("_id", None);
                return doc;
            }
            return None;
        }
        with self._lock {
            if "__default__" in self._limits {
                return self._limits["__default__"].to_dict();
            }
            return None;
        }
    }

    """Delete user-specific limits (they'll fall back to defaults)."""
    def delete_user_limits(username: str) -> bool {
        if self._db {
            result = self._db[self._limits_collection].delete_one(
                {"username": username}
            );
            with self._lock {
                self._limits.pop(username, None);
            }
            return result.deleted_count > 0;
        }
        with self._lock {
            return self._limits.pop(username, None) is not None;
        }
    }

    """List all user limits with pagination."""
    def list_all_limits(limit: int = 50, offset: int = 0) -> dict {
        if self._db {
            cursor = self._db[self._limits_collection].find(
                {"username": {"$ne": "__default__"}}
            ).skip(offset).limit(limit);
            items = [];
            for doc in cursor {
                doc.pop("_id", None);
                items.append(doc);
            }
            total = self._db[self._limits_collection].count_documents(
                {"username": {"$ne": "__default__"}}
            );
            return {"items": items, "total": total, "has_more": (offset + limit) < total};
        }
        with self._lock {
            all_items = [
                v.to_dict()
                for (k, v) in self._limits.items()
                if k != "__default__"
            ];
            total = len(all_items);
            page = all_items[offset:offset + limit];
            return {"items": page, "total": total, "has_more": (offset + limit) < total};
        }
    }

    # ── Usage tracking ───────────────────────────────────────────────────

    """Get current monthly period string (YYYY-MM)."""
    def _current_period -> str {
        return datetime.now(UTC).strftime("%Y-%m");
    }

    """Get current minute window as unix timestamp floored to 60s."""
    def _current_minute_window -> int {
        return int(time.time()) // 60;
    }

    """Get current usage counters for a user."""
    def get_usage(username: str) -> dict {
        period = self._current_period();
        if self._db {
            doc = self._db[self._usage_collection].find_one(
                {"username": username, "period": period}
            );
            if doc {
                doc.pop("_id", None);
                return doc;
            }
            return {
                "username": username,
                "period": period,
                "total_cost": 0.0,
                "total_tokens": 0,
                "total_requests": 0,
                "request_count_minute": 0,
                "token_count_minute": 0
            };
        }
        with self._lock {
            key = f"{username}:{period}";
            if key in self._usage {
                return self._usage[key].to_dict();
            }
            return {
                "username": username,
                "period": period,
                "total_cost": 0.0,
                "total_tokens": 0,
                "total_requests": 0,
                "request_count_minute": 0,
                "token_count_minute": 0
            };
        }
    }

    """Get usage summary for all users in the current period."""
    def get_all_usage(limit: int = 50, offset: int = 0) -> dict {
        period = self._current_period();
        if self._db {
            cursor = self._db[self._usage_collection].find(
                {"period": period}
            ).skip(offset).limit(limit);
            items = [];
            for doc in cursor {
                doc.pop("_id", None);
                items.append(doc);
            }
            total = self._db[self._usage_collection].count_documents(
                {"period": period}
            );
            return {"items": items, "total": total, "has_more": (offset + limit) < total};
        }
        with self._lock {
            all_items = [
                v.to_dict()
                for (k, v) in self._usage.items()
                if k.endswith(f":{period}")
            ];
            total = len(all_items);
            page = all_items[offset:offset + limit];
            return {"items": page, "total": total, "has_more": (offset + limit) < total};
        }
    }

    """Record usage after a successful LLM call (called from post-call hook)."""
    def record_usage(username: str, cost: float, tokens: int) -> None {
        period = self._current_period();
        now_str = datetime.now(UTC).isoformat();
        current_window = self._current_minute_window();
        if self._db {
            # Atomic increment in MongoDB
            self._db[self._usage_collection].update_one(
                {"username": username, "period": period},
                {
                    "$inc": {
                        "total_cost": cost,
                        "total_tokens": tokens,
                        "total_requests": 1
                    },
                    "$set": {"updated_at": now_str},
                    "$setOnInsert": {
                        "username": username,
                        "period": period,
                        "request_count_minute": 0,
                        "token_count_minute": 0,
                        "minute_window": current_window
                    }
                },
                upsert=True
            );
            return;
        }
        with self._lock {
            key = f"{username}:{period}";
            if key not in self._usage {
                self._usage[key] = LLMUsageCounters(
                    username=username,
                    period=period,
                    minute_window=current_window
                );
            }
            counters = self._usage[key];
            counters.total_cost += cost;
            counters.total_tokens += tokens;
            counters.total_requests += 1;
            counters.updated_at = now_str;
        }
    }

    """Increment the per-minute request counter (called pre-call)."""
    def increment_rpm(username: str) -> None {
        period = self._current_period();
        current_window = self._current_minute_window();
        now_str = datetime.now(UTC).isoformat();
        if self._db {
            # Check if minute window rolled over; if so, reset counters
            self._db[self._usage_collection].update_one(
                {"username": username, "period": period, "minute_window": {"$ne": current_window}},
                {"$set": {
                    "request_count_minute": 0,
                    "token_count_minute": 0,
                    "minute_window": current_window
                }}
            );
            # Atomically increment
            self._db[self._usage_collection].update_one(
                {"username": username, "period": period},
                {
                    "$inc": {"request_count_minute": 1},
                    "$set": {"updated_at": now_str},
                    "$setOnInsert": {
                        "username": username,
                        "period": period,
                        "total_cost": 0.0,
                        "total_tokens": 0,
                        "total_requests": 0,
                        "token_count_minute": 0,
                        "minute_window": current_window
                    }
                },
                upsert=True
            );
            return;
        }
        with self._lock {
            key = f"{username}:{period}";
            if key not in self._usage {
                self._usage[key] = LLMUsageCounters(
                    username=username,
                    period=period,
                    minute_window=current_window
                );
            }
            counters = self._usage[key];
            # Reset if minute rolled over
            if counters.minute_window != current_window {
                counters.request_count_minute = 0;
                counters.token_count_minute = 0;
                counters.minute_window = current_window;
            }
            counters.request_count_minute += 1;
            counters.updated_at = now_str;
        }
    }

    # ── Enforcement ──────────────────────────────────────────────────────

    """Pre-call check. Returns allowed or blocked with reason. Auto-resets budget on period rollover."""
    def check_limits(username: str, model: str = "") -> dict {
        limits = self.get_user_limits(username);
        if not limits or not limits.get("enabled", True) {
            return {"allowed": True, "reason": ""};
        }
        # Model access check
        allowed_models = limits.get("allowed_models", []);
        if allowed_models and model and model not in allowed_models {
            return {
                "allowed": False,
                "reason": f"Model '{model}' is not in your allowed models: {allowed_models}"
            };
        }
        # Budget check with auto-reset on period rollover
        budget_limit = limits.get("budget_limit", 0) or limits.get("budget_limit_monthly", 0);
        if budget_limit > 0 {
            budget_period = limits.get("budget_period", "monthly");
            budget_reset_at = limits.get("budget_reset_at", "");
            # Check if the budget period has expired → auto-reset
            if budget_reset_at {
                try {
                    reset_dt = datetime.fromisoformat(budget_reset_at);
                    now = datetime.now(UTC);
                    if now >= reset_dt {
                        # Period expired — reset usage and compute next reset
                        self.reset_usage(username);
                        new_reset = _compute_next_reset(budget_period, now);
                        # Update the reset timestamp in the limits
                        if self._db {
                            self._db[self._limits_collection].update_one(
                                {"username": username},
                                {"$set": {"budget_reset_at": new_reset}}
                            );
                        }
                        with self._lock {
                            if username in self._limits {
                                self._limits[username].budget_reset_at = new_reset;
                            }
                        }
                        # After reset, usage is 0 — no need to block
                        logger.info(
                            f"LLM limits: budget period reset for {username} ({budget_period}), next reset: {new_reset}"
                        );
                    }
                } except Exception {
                    # If parsing fails, skip auto-reset
                    ;
                }
            }
            # Now check current spend against budget
            usage = self.get_usage(username);
            current_cost = usage.get("total_cost", 0);
            if current_cost >= budget_limit {
                # Include when the budget resets in the message
                reset_msg = "";
                reset_at = limits.get("budget_reset_at", "");
                if reset_at {
                    try {
                        reset_dt = datetime.fromisoformat(reset_at);
                        reset_msg = f" Resets at {reset_dt.strftime('%Y-%m-%d %H:%M UTC')}";
                    } except Exception {
                        ;
                    }
                }
                return {
                    "allowed": False,
                    "reason": f"Budget limit exceeded (${current_cost:.2f} / ${budget_limit:.2f} {budget_period}).{reset_msg}"
                };
            }
        }
        # RPM check
        rpm_limit = limits.get("rpm_limit", 0);
        if rpm_limit > 0 {
            usage = self.get_usage(username);
            current_window = self._current_minute_window();
            rpm_count = usage.get("request_count_minute", 0);
            usage_window = usage.get("minute_window", 0);
            if usage_window == current_window and rpm_count >= rpm_limit {
                return {
                    "allowed": False,
                    "reason": f"Rate limit exceeded ({rpm_count}/{rpm_limit} requests per minute)"
                };
            }
        }
        # TPM check
        tpm_limit = limits.get("tpm_limit", 0);
        if tpm_limit > 0 {
            usage = self.get_usage(username);
            current_window = self._current_minute_window();
            tpm_count = usage.get("token_count_minute", 0);
            usage_window = usage.get("minute_window", 0);
            if usage_window == current_window and tpm_count >= tpm_limit {
                return {
                    "allowed": False,
                    "reason": f"Token rate limit exceeded ({tpm_count}/{tpm_limit} tokens per minute)"
                };
            }
        }
        return {"allowed": True, "reason": ""};
    }

    """Reset usage counters for a user (admin action)."""
    def reset_usage(username: str) -> bool {
        period = self._current_period();
        if self._db {
            result = self._db[self._usage_collection].delete_one(
                {"username": username, "period": period}
            );
            return result.deleted_count > 0;
        }
        with self._lock {
            key = f"{username}:{period}";
            return self._usage.pop(key, None) is not None;
        }
    }

    # ── Audit Log ────────────────────────────────────────────────────────

    """Persist an audit log entry for every LLM call (or blocked attempt)."""
    def log_llm_call(
        username: str,
        model: str,
        status: str,
        cost: float = 0.0,
        tokens: int = 0,
        prompt_tokens: int = 0,
        completion_tokens: int = 0,
        latency_ms: float = 0.0,
        blocked: bool = False,
        block_reason: str = "",
        call_metadata: dict = {}
    ) -> None {
        now = datetime.now(UTC);
        entry = {
            "timestamp": now.isoformat(),
            "ts_epoch": now.timestamp(),
            "username": username,
            "model": model,
            "status": status,
            "cost": round(cost, 8),
            "total_tokens": tokens,
            "prompt_tokens": prompt_tokens,
            "completion_tokens": completion_tokens,
            "latency_ms": round(latency_ms, 2),
            "blocked": blocked,
            "block_reason": block_reason,
            "period": self._current_period(),
            "invocation_id": call_metadata.get("jac_invocation_id", ""),
            "caller_name": call_metadata.get("jac_caller_name", "")
        };
        if self._db {
            try {
                self._db[self._log_collection].insert_one(entry);
            } except Exception as log_err {
                logger.debug(f"LLM limits: audit log write failed: {log_err}");
            }
        } else {
            # Buffer in memory — capped to prevent unbounded growth
            with self._log_buffer_lock {
                self._log_buffer.append(entry);
                if len(self._log_buffer) > 10000 {
                    self._log_buffer = self._log_buffer[-5000:];
                }
            }
        }
    }

    """Query the audit log with optional filters."""
    def get_usage_logs(
        filter_username: str = "",
        limit: int = 100,
        offset: int = 0,
        blocked_only: bool = False
    ) -> dict {
        if self._db {
            query: dict = {};
            if filter_username {
                query["username"] = filter_username;
            }
            if blocked_only {
                query["blocked"] = True;
            }
            cursor = self._db[self._log_collection].find(query).sort(
                "ts_epoch", -1
            ).skip(offset).limit(limit);
            items: list = [];
            for doc in cursor {
                doc.pop("_id", None);
                items.append(doc);
            }
            total = self._db[self._log_collection].count_documents(query);
            return {"items": items, "total": total, "has_more": (offset + limit) < total};
        }
        # In-memory fallback
        with self._log_buffer_lock {
            filtered = list(self._log_buffer);
            if filter_username {
                filtered = [e for e in filtered if e["username"] == filter_username];
            }
            if blocked_only {
                filtered = [e for e in filtered if e.get("blocked")];
            }
            # Newest first
            filtered = list(reversed(filtered));
            total = len(filtered);
            page = filtered[offset:offset + limit];
            return {"items": page, "total": total, "has_more": (offset + limit) < total};
        }
    }
}


# Global store instance
glob _llm_limits_store: LLMLimitsStore | None = None;

# Per-provider API keys — hot-swappable at runtime via admin endpoints.
# Keys are provider names as returned by litellm.get_llm_provider(), e.g.
# {"openai": "sk-...", "anthropic": "sk-ant-...", "gemini": "AIza..."}
# When a provider key is present it overrides jac.toml / env vars for that provider.
glob _active_provider_keys: dict = {};

"""Get the global limits store instance (None if not initialized)."""
def get_llm_limits_store -> LLMLimitsStore | None {
    return _llm_limits_store;
}


"""Register LLM limits endpoints and install the litellm enforcement wrapper."""
impl JacAPIServerLLMLimits.register_llm_limits_endpoints -> None {
    global _llm_limits_store;

    import from jac_scale.config_loader { get_scale_config }
    limits_cfg = get_scale_config().get_llm_limits_config();

    if not limits_cfg.get('enabled', True) {
        logger.info("LLM limits: disabled via configuration");
        return;
    }

    # Initialize the store.
    # Typed as Any so the type checker doesn't block method calls
    # from inside @functools.wraps-decorated Python closures below.
    _llm_limits_store = LLMLimitsStore();
    store: Any = _llm_limits_store;

    # Set default limits from config if none exist
    if not store.get_default_limits() {
        store.set_default_limits({
            "budget_limit": limits_cfg.get('default_budget_limit', 0),
            "budget_period": limits_cfg.get('default_budget_period', 'monthly'),
            "rpm_limit": limits_cfg.get('default_rpm', 0),
            "tpm_limit": limits_cfg.get('default_tpm', 0),
            "allowed_models": limits_cfg.get('default_allowed_models', []),
            "enabled": True
        });
        logger.info("LLM limits: default limits initialized from config");
    }

    enforcement_mode = limits_cfg.get('enforcement_mode', 'strict');

    # ── Install litellm enforcement wrapper ──────────────────────────────
    try {
        import litellm;

        _original_completion = litellm.completion;
        _original_acompletion = litellm.acompletion;

        @functools.wraps(_original_completion)
        def _guarded_completion(*args: Any, **kwargs: Any) -> Any {
            # Read username from Jac's per-request ExecutionContext
            try {
                import from jaclang { JacRuntime as _Jac }
                username = _Jac.get_context().user_name or ANONYMOUS_USER;
            } except Exception {
                username = ANONYMOUS_USER;
            }
            model = kwargs.get('model', '') or (args[0] if args else '');
            call_meta = kwargs.get('metadata', {}) or {};

            # Pre-call: check limits
            check = store.check_limits(username, model);
            if not check["allowed"] {
                # Log the blocked attempt
                store.log_llm_call(
                    username=username, model=model, status="blocked",
                    blocked=True, block_reason=check["reason"],
                    call_metadata=call_meta
                );
                if enforcement_mode == 'strict' {
                    raise Exception(
                        f"LLM request blocked: {check['reason']}"
                    );
                } else {
                    logger.warning(
                        f"LLM limits warning for {username}: {check['reason']}"
                    );
                }
            }

            # Increment RPM counter before the call
            store.increment_rpm(username);
            # Inject username into metadata for post-call tracking
            call_meta['jac_username'] = username;
            kwargs['metadata'] = call_meta;
            # Inject per-provider API key if admin has configured one
            if _active_provider_keys and 'api_key' not in kwargs {
                try {
                    provider_key = kwargs.get('model', '') or (args[0] if args else '');
                    provider = litellm.get_llm_provider(provider_key)[1];
                    if provider and provider in _active_provider_keys {
                        kwargs['api_key'] = _active_provider_keys[provider];
                    }
                } except Exception {
                    ;
                }
            }

            start_ts = time.time();
            result = _original_completion(*args, **kwargs);
            elapsed_ms = (time.time() - start_ts) * 1000;

            # Post-call: record usage + audit log
            try {
                r_usage = getattr(result, 'usage', None);
                p_tok = getattr(r_usage, 'prompt_tokens', 0) or 0 if r_usage else 0;
                c_tok = getattr(r_usage, 'completion_tokens', 0) or 0 if r_usage else 0;
                t_tok = getattr(r_usage, 'total_tokens', 0) or 0 if r_usage else 0;
                cost = 0.0;
                if hasattr(result, '_hidden_params') {
                    cost = result._hidden_params.get('response_cost', 0) or 0.0;
                }
                store.record_usage(username, float(cost), int(t_tok));
                store.log_llm_call(
                    username=username, model=model, status="success",
                    cost=float(cost), tokens=int(t_tok),
                    prompt_tokens=int(p_tok), completion_tokens=int(c_tok),
                    latency_ms=elapsed_ms, call_metadata=call_meta
                );
            } except Exception as rec_err {
                logger.debug(f"LLM limits: post-call recording error: {rec_err}");
            }
            return result;
        }

        @functools.wraps(_original_acompletion)
        async def _guarded_acompletion(*args: Any, **kwargs: Any) -> Any {
            # Read username from Jac's per-request ExecutionContext
            try {
                import from jaclang { JacRuntime as _Jac }
                username = _Jac.get_context().user_name or ANONYMOUS_USER;
            } except Exception {
                username = ANONYMOUS_USER;
            }
            model = kwargs.get('model', '') or (args[0] if args else '');
            call_meta = kwargs.get('metadata', {}) or {};

            # Pre-call: check limits
            check = store.check_limits(username, model);
            if not check["allowed"] {
                store.log_llm_call(
                    username=username, model=model, status="blocked",
                    blocked=True, block_reason=check["reason"],
                    call_metadata=call_meta
                );
                if enforcement_mode == 'strict' {
                    raise Exception(
                        f"LLM request blocked: {check['reason']}"
                    );
                } else {
                    logger.warning(
                        f"LLM limits warning for {username}: {check['reason']}"
                    );
                }
            }

            store.increment_rpm(username);
            call_meta['jac_username'] = username;
            kwargs['metadata'] = call_meta;
            # Inject per-provider API key if admin has configured one
            if _active_provider_keys and 'api_key' not in kwargs {
                try {
                    provider_key = kwargs.get('model', '') or (args[0] if args else '');
                    provider = litellm.get_llm_provider(provider_key)[1];
                    if provider and provider in _active_provider_keys {
                        kwargs['api_key'] = _active_provider_keys[provider];
                    }
                } except Exception {
                    ;
                }
            }

            start_ts = time.time();
            result = await _original_acompletion(*args, **kwargs);
            elapsed_ms = (time.time() - start_ts) * 1000;

            # Post-call: record usage + audit log
            try {
                r_usage = getattr(result, 'usage', None);
                p_tok = getattr(r_usage, 'prompt_tokens', 0) or 0 if r_usage else 0;
                c_tok = getattr(r_usage, 'completion_tokens', 0) or 0 if r_usage else 0;
                t_tok = getattr(r_usage, 'total_tokens', 0) or 0 if r_usage else 0;
                cost = 0.0;
                if hasattr(result, '_hidden_params') {
                    cost = result._hidden_params.get('response_cost', 0) or 0.0;
                }
                store.record_usage(username, float(cost), int(t_tok));
                store.log_llm_call(
                    username=username, model=model, status="success",
                    cost=float(cost), tokens=int(t_tok),
                    prompt_tokens=int(p_tok), completion_tokens=int(c_tok),
                    latency_ms=elapsed_ms, call_metadata=call_meta
                );
            } except Exception as rec_err {
                logger.debug(f"LLM limits: async post-call recording error: {rec_err}");
            }
            return result;
        }

        litellm.completion = _guarded_completion;
        litellm.acompletion = _guarded_acompletion;
        logger.info(
            f"LLM limits: litellm enforcement wrapper installed (mode={enforcement_mode})"
        );
    } except ImportError {
        logger.info("LLM limits: litellm not available, skipping enforcement wrapper");
    } except Exception as e {
        logger.warning(f"LLM limits: failed to install enforcement wrapper: {e}");
    }

    # ── REST Endpoints ───────────────────────────────────────────────────

    # GET /admin/llm/limits/default
    async def get_default_handler(request: Request) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get('http_status', 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        data = store.get_default_limits();
        return JSONResponse(content={"ok": True, "data": data or {}});
    }

    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/llm/limits/default",
            callback=get_default_handler,
            parameters=[],
            response_model=None,
            tags=["LLM Limits"],
            summary="Get Default LLM Limits",
            description="Get the default limits applied to users without specific overrides."
        )
    );

    # PUT /admin/llm/limits/default
    async def set_default_handler(request: Request) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get('http_status', 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        body = await request.json();
        data = store.set_default_limits(body);
        return JSONResponse(content={"ok": True, "data": data});
    }

    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.PUT,
            path="/admin/llm/limits/default",
            callback=set_default_handler,
            parameters=[],
            response_model=None,
            tags=["LLM Limits"],
            summary="Set Default LLM Limits",
            description="Set the default limits for all users."
        )
    );

    # GET /admin/llm/limits
    async def list_limits_handler(request: Request) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get('http_status', 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        qp = request.query_params;
        try {
            limit = int(qp.get("limit", "50"));
        } except (ValueError, TypeError) {
            limit = 50;
        }
        try {
            offset = int(qp.get("offset", "0"));
        } except (ValueError, TypeError) {
            offset = 0;
        }
        data = store.list_all_limits(limit=limit, offset=offset);
        return JSONResponse(content={"ok": True, "data": data});
    }

    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/llm/limits",
            callback=list_limits_handler,
            parameters=[],
            response_model=None,
            tags=["LLM Limits"],
            summary="List User LLM Limits",
            description="List all per-user limit configurations."
        )
    );

    # GET /admin/llm/limits/{username}
    async def get_user_limits_handler(
        request: Request, username: str
    ) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get('http_status', 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        data = store.get_user_limits(username);
        if data is None {
            return JSONResponse(
                status_code=404,
                content={"ok": False, "error": {"message": "No limits found"}}
            );
        }
        return JSONResponse(content={"ok": True, "data": data});
    }

    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/llm/limits/{username}",
            callback=get_user_limits_handler,
            parameters=[
                APIParameter(
                    name="username",
                    data_type="string",
                    required=True,
                    default=None,
                    description="Username to get limits for",
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=["LLM Limits"],
            summary="Get User LLM Limits",
            description="Get limits for a specific user."
        )
    );

    # PUT /admin/llm/limits/{username}
    async def set_user_limits_handler(
        request: Request, username: str
    ) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get('http_status', 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        body = await request.json();
        data = store.set_user_limits(username, body);
        return JSONResponse(content={"ok": True, "data": data});
    }

    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.PUT,
            path="/admin/llm/limits/{username}",
            callback=set_user_limits_handler,
            parameters=[
                APIParameter(
                    name="username",
                    data_type="string",
                    required=True,
                    default=None,
                    description="Username to set limits for",
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=["LLM Limits"],
            summary="Set User LLM Limits",
            description="Set or update limits for a specific user."
        )
    );

    # DELETE /admin/llm/limits/{username}
    async def delete_user_limits_handler(
        request: Request, username: str
    ) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get('http_status', 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        deleted = store.delete_user_limits(username);
        if not deleted {
            return JSONResponse(
                status_code=404,
                content={"ok": False, "error": {"message": "No user-specific limits found"}}
            );
        }
        return JSONResponse(
            content={"ok": True, "data": {"message": f"Limits for {username} removed"}}
        );
    }

    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.DELETE,
            path="/admin/llm/limits/{username}",
            callback=delete_user_limits_handler,
            parameters=[
                APIParameter(
                    name="username",
                    data_type="string",
                    required=True,
                    default=None,
                    description="Username to delete limits for",
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=["LLM Limits"],
            summary="Delete User LLM Limits",
            description="Delete user-specific limits (falls back to defaults)."
        )
    );

    # GET /admin/llm/usage/{username}
    async def get_user_usage_handler(
        request: Request, username: str
    ) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get('http_status', 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        data = store.get_usage(username);
        return JSONResponse(content={"ok": True, "data": data});
    }

    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/llm/usage/{username}",
            callback=get_user_usage_handler,
            parameters=[
                APIParameter(
                    name="username",
                    data_type="string",
                    required=True,
                    default=None,
                    description="Username to get usage for",
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=["LLM Limits"],
            summary="Get User LLM Usage",
            description="Get current period usage for a specific user."
        )
    );

    # GET /admin/llm/usage
    async def get_all_usage_handler(request: Request) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get('http_status', 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        qp = request.query_params;
        try {
            limit = int(qp.get("limit", "50"));
        } except (ValueError, TypeError) {
            limit = 50;
        }
        try {
            offset = int(qp.get("offset", "0"));
        } except (ValueError, TypeError) {
            offset = 0;
        }
        data = store.get_all_usage(limit=limit, offset=offset);
        return JSONResponse(content={"ok": True, "data": data});
    }

    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/llm/usage",
            callback=get_all_usage_handler,
            parameters=[],
            response_model=None,
            tags=["LLM Limits"],
            summary="Get All LLM Usage",
            description="Get usage summary for all users in the current period."
        )
    );

    # POST /admin/llm/usage/{username}/reset
    async def reset_usage_handler(
        request: Request, username: str
    ) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get('http_status', 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        store.reset_usage(username);
        return JSONResponse(
            content={"ok": True, "data": {"message": f"Usage reset for {username}"}}
        );
    }

    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path="/admin/llm/usage/{username}/reset",
            callback=reset_usage_handler,
            parameters=[
                APIParameter(
                    name="username",
                    data_type="string",
                    required=True,
                    default=None,
                    description="Username to reset usage for",
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=["LLM Limits"],
            summary="Reset User LLM Usage",
            description="Reset usage counters for a specific user."
        )
    );

    # ── Per-Provider API Key Management ───────────────────────────────────
    # Keys stored as {"_id": "provider_keys", "keys": {"openai": "sk-...", ...}}

    # Load persisted provider keys from MongoDB on startup
    global _active_provider_keys;
    if store._db {
        keys_doc = store._db["llm_config"].find_one({"_id": "provider_keys"});
        if keys_doc and keys_doc.get("keys") {
            _active_provider_keys = dict(keys_doc["keys"]);
            logger.info(
                f"LLM limits: provider keys loaded for: {list(_active_provider_keys.keys())}"
            );
        }
    }

    def _mask_key(key: str) -> str {
        return "****" + key[-4:] if len(key) >= 4 else "****";
    }

    def _persist_provider_keys -> None {
        if store._db {
            store._db["llm_config"].update_one(
                {"_id": "provider_keys"},
                {"$set": {"keys": _active_provider_keys}},
                upsert=True
            );
        }
    }

    # GET /admin/llm/config/provider-keys
    # Returns all configured providers with masked keys
    async def get_provider_keys_handler(request: Request) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get('http_status', 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        result: dict = {};
        for provider in _active_provider_keys {
            key = _active_provider_keys[provider];
            if key {
                result[provider] = {"has_key": True, "masked_key": _mask_key(key)};
            }
        }
        return JSONResponse(content={"ok": True, "data": result});
    }

    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/llm/config/provider-keys",
            callback=get_provider_keys_handler,
            parameters=[],
            response_model=None,
            tags=["LLM Config"],
            summary="Get Provider API Keys",
            description="List all configured provider API keys (masked)."
        )
    );

    # PUT /admin/llm/config/provider-keys/{provider}
    # Body: {"api_key": "sk-..."}
    async def set_provider_key_handler(request: Request, provider: str) -> JSONResponse {
        global _active_provider_keys;
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get('http_status', 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        provider = provider.strip().lower();
        if not provider {
            return JSONResponse(
                status_code=400,
                content={"ok": False, "error": {"message": "Provider name required"}}
            );
        }
        body = await request.json();
        new_key = str(body.get("api_key", "")).strip();
        if not new_key {
            return JSONResponse(
                status_code=400,
                content={"ok": False, "error": {"message": "api_key is required"}}
            );
        }
        _active_provider_keys[provider] = new_key;
        _persist_provider_keys();
        logger.info(f"LLM limits: API key set for provider '{provider}' ({_mask_key(new_key)})");
        return JSONResponse(content={
            "ok": True,
            "data": {"provider": provider, "masked_key": _mask_key(new_key)}
        });
    }

    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.PUT,
            path="/admin/llm/config/provider-keys/{provider}",
            callback=set_provider_key_handler,
            parameters=[
                APIParameter(
                    name="provider",
                    required=True,
                    default=None,
                    description="Provider name, e.g. openai, anthropic, gemini",
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=["LLM Config"],
            summary="Set Provider API Key",
            description="Set or update the runtime API key for a specific LLM provider."
        )
    );

    # DELETE /admin/llm/config/provider-keys/{provider}
    async def delete_provider_key_handler(request: Request, provider: str) -> JSONResponse {
        global _active_provider_keys;
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get('http_status', 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        provider = provider.strip().lower();
        if provider not in _active_provider_keys {
            return JSONResponse(
                status_code=404,
                content={"ok": False, "error": {"message": f"No key configured for '{provider}'"}}
            );
        }
        _active_provider_keys.pop(provider);
        _persist_provider_keys();
        logger.info(f"LLM limits: API key cleared for provider '{provider}'");
        return JSONResponse(content={
            "ok": True,
            "data": {"message": f"Key cleared for '{provider}' — falling back to jac.toml / env vars"}
        });
    }

    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.DELETE,
            path="/admin/llm/config/provider-keys/{provider}",
            callback=delete_provider_key_handler,
            parameters=[
                APIParameter(
                    name="provider",
                    required=True,
                    default=None,
                    description="Provider name to remove key for",
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=["LLM Config"],
            summary="Delete Provider API Key",
            description="Remove the runtime API key for a specific LLM provider."
        )
    );

    logger.info(
        "LLM limits endpoints registered: /admin/llm/{limits,usage,config/provider-keys}"
    );
}
