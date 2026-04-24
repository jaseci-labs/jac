"""Tests for JacUserRateLimiter — unit (mock) + integration (testcontainers)."""
import time;
import unittest.mock;
import from datetime { datetime, timezone, timedelta }
import from testcontainers.redis { RedisContainer }
import from testcontainers.mongodb { MongoDbContainer }
import redis as redis_lib;
import from pymongo { MongoClient }
import from jac_scale.admin.llm_telemetry { JacUserRateLimiter }

# Shared containers — started once for all integration tests
glob _rc = RedisContainer("redis:7.2-alpine"),
     _mc = MongoDbContainer("mongo:7.0");

with entry {
    _rc.start();
    _mc.start();
}

glob REDIS_URI = f"redis://{_rc.get_container_host_ip()}:{_rc.get_exposed_port(6379)}/0",
     MONGO_URI = _mc.get_connection_url();

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def make_rl(rc: any = None, col: any = None, **cfg) -> JacUserRateLimiter {
    if rc is None {
        rc = unittest.mock.MagicMock();
        rc.get.return_value = None;
        rc.incr.return_value = 1;
        rc.pipeline.return_value = unittest.mock.MagicMock();
    }
    defaults = {'rpm': None, 'rpd': None, 'tpm': None, 'tpd': None, 'daily_budget_usd': None, 'monthly_budget_usd': None};
    defaults.update(cfg);
    return JacUserRateLimiter(
        rc=rc,
        col=col,
        rpm=defaults.get('rpm'),
        rpd=defaults.get('rpd'),
        tpm=defaults.get('tpm'),
        tpd=defaults.get('tpd'),
        daily_budget=defaults.get('daily_budget_usd'),
        monthly_budget=defaults.get('monthly_budget_usd')
    );
}

def fresh_rc -> any {
    rc = redis_lib.from_url(REDIS_URI);
    rc.flushdb();
    return rc;
}

def fresh_col(name: str) -> any {
    col = MongoClient(MONGO_URI)['test'][name];
    col.drop();
    return col;
}

# ---------------------------------------------------------------------------
# Unit tests (mock Redis/MongoDB)
# ---------------------------------------------------------------------------

test "RPM blocks when limit exceeded" {
    rl = make_rl(rpm=3);
    rl.rc.incr.return_value = 4;
    raised = False;
    try { rl.check_pre_call("alice"); } except Exception { raised = True; }
    assert raised;
}

test "TPM blocks when token count at limit" {
    rl = make_rl(tpm=1000);
    rl.rc.get.return_value = b"1000";
    raised = False;
    try { rl.check_pre_call("alice"); } except Exception as e {
        raised = True;
        assert "token-per-minute" in str(e).lower();
    }
    assert raised;
}

test "TPD blocks when token count at limit" {
    rl = make_rl(tpd=5000);
    rl.rc.get.return_value = b"5000";
    raised = False;
    try { rl.check_pre_call("alice"); } except Exception as e {
        raised = True;
        assert "token-per-day" in str(e).lower();
    }
    assert raised;
}

test "daily budget blocks when spent >= limit" {
    rl = make_rl(daily_budget_usd=5.0);
    rl.rc.get.return_value = b"5.00";
    raised = False;
    try { rl.check_pre_call("alice"); } except Exception as e {
        raised = True;
        assert "daily" in str(e).lower();
    }
    assert raised;
}

test "monthly budget blocks when spent >= limit" {
    rl = make_rl(monthly_budget_usd=50.0);
    rl.rc.get.return_value = b"55.00";
    raised = False;
    try { rl.check_pre_call("alice"); } except Exception as e {
        raised = True;
        assert "monthly" in str(e).lower();
    }
    assert raised;
}

test "no Redis raises when limits are configured" {
    rl = make_rl(rpm=1, tpm=1, tpd=1, daily_budget_usd=0.01, monthly_budget_usd=0.01);
    rl.rc = None;
    raised = False;
    try { rl.check_pre_call("alice"); } except Exception as e {
        raised = True;
        assert "redis" in str(e).lower();
    }
    assert raised;
}

test "no limits set means no-op even without Redis" {
    rl = make_rl();
    rl.rc = None;
    rl.check_pre_call("alice");  # must not raise
}

test "budget_spent returns cached Redis value without hitting MongoDB" {
    rl = make_rl(daily_budget_usd=5.0);
    rl.rc.get.return_value = b"3.50";
    col = unittest.mock.MagicMock();
    rl.col = col;
    spent = rl._get_budget_spent("alice", "day", "key", 60);
    assert abs(spent - 3.50) < 0.001;
    col.aggregate.assert_not_called();
}

test "budget_spent queries MongoDB on cache miss and caches result" {
    col = unittest.mock.MagicMock();
    col.aggregate.return_value = iter([{'_id': None, 'total': 2.00}]);
    rl = make_rl(daily_budget_usd=5.0, col=col);
    rl.rc.get.return_value = None;
    spent = rl._get_budget_spent("bob", "day", "key", 60);
    assert abs(spent - 2.00) < 0.001;
    rl.rc.set.assert_called_once();
}

test "record_success writes to MongoDB with correct fields" {
    col = unittest.mock.MagicMock();
    rl = make_rl(daily_budget_usd=5.0, col=col);
    rl.record_success("alice", 1500, 0.045, "gpt-4o");
    doc = col.insert_one.call_args[0][0];
    assert doc['username'] == "alice";
    assert doc['tokens'] == 1500;
    assert abs(doc['cost_usd'] - 0.045) < 0.0001;
    assert doc['model'] == "gpt-4o";
    assert doc['ts'] > 0;
}

# ---------------------------------------------------------------------------
# Integration tests (real Redis)
# ---------------------------------------------------------------------------

test "integration: RPM enforced and per-user isolated" {
    rc = fresh_rc();
    rl = make_rl(rc=rc, rpm=2);
    rl.check_pre_call("alice");
    rl.check_pre_call("alice");
    raised = False;
    try { rl.check_pre_call("alice"); } except Exception { raised = True; }
    assert raised , "alice blocked after rpm=2";
    rl.check_pre_call("bob");  # bob unaffected
}

test "integration: TPM accumulates and blocks correctly" {
    rc = fresh_rc();
    rl = make_rl(rc=rc, tpm=500);
    rl.record_success("alice", 400, 0.0, "gpt-4o");
    rl.check_pre_call("alice");  # 400 < 500, passes
    rl.record_success("alice", 100, 0.0, "gpt-4o");  # now at 500
    raised = False;
    try { rl.check_pre_call("alice"); } except Exception { raised = True; }
    assert raised , "alice blocked after 500 TPM";
}

test "integration: RPD resets on day key expiry" {
    rc = fresh_rc();
    rl = make_rl(rc=rc, rpd=3);
    for _ in range(3) { rl.check_pre_call("alice"); }
    raised = False;
    try { rl.check_pre_call("alice"); } except Exception { raised = True; }
    assert raised;
    rc.delete(f"llm:rpd:alice:{int(time.time()) // 86400}");  # simulate day rollover
    rl.check_pre_call("alice");  # passes after reset
}

# ---------------------------------------------------------------------------
# Persistence tests (real Redis + MongoDB)
# ---------------------------------------------------------------------------

test "integration: daily budget rebuilds from MongoDB after Redis flush" {
    rc = fresh_rc();
    col = fresh_col("daily_rebuild");
    rl = make_rl(rc=rc, col=col, daily_budget_usd=1.00);

    rl.record_success("alice", 1000, 0.80, "gpt-4o");
    rl.check_pre_call("alice");  # $0.80 < $1.00, passes

    rc.flushdb();  # simulate restart
    rl.check_pre_call("alice");  # rebuilds from Mongo — still $0.80, passes

    rl.record_success("alice", 500, 0.30, "gpt-4o");
    rc.flushdb();

    raised = False;
    try { rl.check_pre_call("alice"); } except Exception as e {
        raised = True;
        assert "daily" in str(e).lower();
    }
    assert raised , "must block after $1.10 even after Redis flush";
}

test "integration: monthly budget spans multiple days" {
    rc = fresh_rc();
    col = fresh_col("monthly_span");
    rl = make_rl(rc=rc, col=col, monthly_budget_usd=5.00);

    now = datetime.now(timezone.utc);
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0);
    for i in range(4) {
        col.insert_one({'username': "alice", 'ts': (month_start + timedelta(days=i)).timestamp(), 'model': "gpt-4o", 'tokens': 1000, 'cost_usd': 1.20});
    }
    # $4.80 spent
    rl.check_pre_call("alice");  # passes

    col.insert_one({'username': "alice", 'ts': now.timestamp(), 'model': "gpt-4o", 'tokens': 500, 'cost_usd': 0.30});
    rc.flushdb();

    raised = False;
    try { rl.check_pre_call("alice"); } except Exception as e {
        raised = True;
        assert "monthly" in str(e).lower();
    }
    assert raised , "must block after $5.10 monthly";
}

test "unauthenticated calls pool under __anonymous__ and are rate limited" {
    rc = fresh_rc();
    rl = make_rl(rc=rc, rpm=2);
    rl.check_pre_call('__anonymous__');
    rl.check_pre_call('__anonymous__');  # second passes (limit=2)
    raised = False;
    try { rl.check_pre_call('__anonymous__'); } except Exception { raised = True; }
    assert raised , "__anonymous__ must be blocked after rpm=2";
    rl.check_pre_call("alice");  # authenticated user unaffected
}

# ---------------------------------------------------------------------------
# Hook integration test (real byllm Model.invoke path)
# ---------------------------------------------------------------------------

test "integration: byllm pre-invoke hook blocks call when RPM exceeded" {
    import from byllm.lib { Model }
    import from byllm.mtir { MTRuntime }
    import from byllm.llm { register_pre_invoke_hook, _pre_invoke_hooks }
    import from jac_scale.admin.llm_telemetry { LLMRateLimitExceeded }

    rc = fresh_rc();
    rl = make_rl(rc=rc, rpm=1);

    # Register a hook that checks rate limits for a fixed test user
    def _hook(_model_name: any, _mt_run: any) {
        rl.check_pre_call("alice");
    }
    hooks_before = list(_pre_invoke_hooks);
    register_pre_invoke_hook(_hook);

    model = Model(model_name="mockllm", config={"outputs": ["hello", "hello"]});
    mt = MTRuntime(
        messages=[
            {"role": "system", "content": "You are a test assistant."},
            {"role": "user", "content": "test"}
        ],
        resp_type=str,
        stream=False,
        tools=[],
        call_params={},
        mtir=None
    );

    try {
        model.invoke(mt);  # first call passes (rpm=1)

        raised = False;
        try {
            model.invoke(mt);  # second call blocked
        } except LLMRateLimitExceeded as e {
            raised = True;
            assert "rate limit" in str(e).lower();
        }
        assert raised , "second call must be blocked by RPM hook";
    } finally {
        # Restore hooks to avoid polluting other tests
        _pre_invoke_hooks.clear();
        _pre_invoke_hooks.extend(hooks_before);
    }
}
