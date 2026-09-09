import from unittest.mock { patch, MagicMock }
import from concurrent.futures { ThreadPoolExecutor }
import from tempfile { mkdtemp }
import from jaclang.data.pgembed { PgRuntime }
import from jaclang.data.store { PgStore }
import from jaclang.server.identity.rate_limit { consume_limit }
import from jaclang.server.endpoints.auth { register_auth_endpoints }
import from jaclang.server.identity.auth_models { RegisterRequest }
import from jaclang.server.settings { AuthSettings }
import from jaclang.server.serving.datatypes { Request }
import from jaclang.server.serving.app { transport_to_response }

test "database quotas are atomic isolated and reset only at expiration" {
    runtime = PgRuntime(data_dir=mkdtemp(prefix='jaclimits_') + '/data');
    store = PgStore(conninfo=runtime.ensure());
    store.ensure_schema({});
    stores = [PgStore(conninfo=runtime.ensure()) for i in range(8)];
    import threading;
    local = threading.local();
    with patch(
        consume_limit.__module__ + '.shared_store', side_effect=lambda { local.store; }
    ) {
        local.store = store;
        def attempt(n: int) -> int {
            local.store = stores[n % 8];
            return consume_limit('signup', 'a', 5, 3600);
        }
        with ThreadPoolExecutor(max_workers=8) as pool {
            results = list(pool.map(attempt, range(20)));
        }
        assert results.count(0) == 5 , str(results);
        assert all(
            r > 0
            for r in results
            if r != 0
        );
        assert consume_limit('signup', 'b', 5, 3600) == 0;
        assert consume_limit('challenge', 'a', 5, 3600) == 0;
        before = store.rows(
            'SELECT key, value, expires_at FROM kv_state ORDER BY key', {}
        );
        assert consume_limit('signup', 'a', 5, 3600) > 0;
        assert before
            == store.rows(
                'SELECT key, value, expires_at FROM kv_state ORDER BY key', {}
            );
        store.rows("UPDATE kv_state SET expires_at = now() - interval '1 second'", {});
        assert consume_limit('signup', 'a', 5, 3600) == 0;
    }
}

test "enabled quotas fail closed when storage is unavailable" {
    with patch(consume_limit.__module__ + '.shared_store', return_value=None) {
        assert consume_limit('signup', 'a', 5, 3600) == -1;
        assert consume_limit('signup', 'a', 0, 3600) == 0;
    }
}

test "registration limits precede verification and account creation" {
    server = MagicMock();
    register_auth_endpoints(server);
    callbacks: dict[str, any] = {
        c.args[0].path: c.args[0].callback for c in server.add_endpoint.call_args_list
    };
    body = RegisterRequest.from_dict(
        {
            'identities': [{'type': 'username', 'value': 'alice'}],
            'credential': {'type': 'password', 'password': 'secret123'}
        }
    );
    request = Request(client_host='192.0.2.1');
    request.headers.set('X-Forwarded-For', 'spoofed');
    with patch(
        register_auth_endpoints.__module__ + '.auth_settings',
        return_value=AuthSettings(
            registration_challenge=True,
            registration_attempts_per_hour=5,
            registration_challenges_per_10_minutes=20
        )
    ), patch(
        register_auth_endpoints.__module__ + '.consume_limit', return_value=42
    ) as quota, patch(
        register_auth_endpoints.__module__ + '.consume_challenge'
    ) as verify, patch(
        register_auth_endpoints.__module__ + '.issue_challenge'
    ) as issue {
        response = callbacks['/user/register'](body, request);
        assert response.error.code == 'RATE_LIMITED';
        http = transport_to_response(response);
        assert http.status_code == 429;
        assert http.headers.get('Retry-After') == '42';
        quota.assert_called_with('registration-attempt', '192.0.2.1', 5, 3600);
        assert not callbacks['/user/register/challenge'](request).ok;
        quota.assert_called_with('registration-challenge', '192.0.2.1', 20, 600);
        verify.assert_not_called();
        issue.assert_not_called();
        server.identity.return_value.create_user_with_identities.assert_not_called();
    }
}
