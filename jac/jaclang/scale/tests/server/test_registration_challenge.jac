import from unittest.mock { patch, MagicMock }
import from datetime { datetime, UTC, timedelta }
import from concurrent.futures { ThreadPoolExecutor }
import from jaclang.server.endpoints.auth { register_auth_endpoints }
import from jaclang.server.identity.auth_models { RegisterRequest }
import from jaclang.server.settings { AuthSettings }
import from jaclang.scale.sso.oauth_session { complete_identity }
import from jaclang.scale.sso.provider { SSOUserInfo }
import from jaclang.server.identity.auth_tokens { AuthTokenStore }
import from jaclang.server.identity.registration_challenge {
    issue_challenge,
    consume_challenge
}

def memory_store -> AuthTokenStore {
    with patch('jaclang.server.shared_store.shared_store', return_value=None) {
        return AuthTokenStore();
    }
}

test "challenge expires and cannot be replayed or forged" {
    store = memory_store();
    with patch.object(AuthTokenStore, 'instance', return_value=store), patch(
        issue_challenge.__module__ + '.secrets.randbelow', return_value=7
    ) {
        issued = issue_challenge();
        proof = {'token': issued['token'], 'number': 7};
        assert not consume_challenge(None);
        assert not consume_challenge({'token': issued['token'], 'number': 8});
        assert not consume_challenge({'token': issued['token'], 'number': True});
        assert consume_challenge(proof);
        assert not consume_challenge(proof);
        expired = issue_challenge();
        record = store._in_memory[AuthTokenStore.hash_token(expired['token'])];
        record['expires_at'] = datetime.now(UTC) - timedelta(seconds=1);
        assert not consume_challenge({'token': expired['token'], 'number': 7});
    }
}

test "only one concurrent registration can redeem a proof" {
    store = memory_store();
    with patch.object(AuthTokenStore, 'instance', return_value=store), patch(
        issue_challenge.__module__ + '.secrets.randbelow', return_value=7
    ) {
        issued = issue_challenge();
        proof = {'token': issued['token'], 'number': 7};
        with ThreadPoolExecutor(max_workers=8) as pool {
            outcomes = list(pool.map(consume_challenge, [proof] * 8));
        }
        assert sum(outcomes) == 1;
    }
}

test "registration endpoint enforces challenge before creating account" {
    server = MagicMock();
    users = server.identity.return_value;
    users.create_user_with_identities.return_value = {'user_id': 'new-user'};
    users.create_jwt_token.return_value = 'session';
    register_auth_endpoints(server);
    handler: any = None;
    for call in server.add_endpoint.call_args_list {
        endpoint = call.args[0];
        if endpoint.path == '/user/register' {
            handler = endpoint.callback;
        }
    }
    request = RegisterRequest.from_dict(
        {
            'identities': [{'type': 'username', 'value': 'alice'}],
            'credential': {'type': 'password', 'password': 'secret123'}
        }
    );
    with patch(
        register_auth_endpoints.__module__ + '.auth_settings',
        return_value=AuthSettings(registration_challenge=True)
    ), patch(
        register_auth_endpoints.__module__ + '.consume_challenge', return_value=False
    ) {
        assert not handler(request, MagicMock(client_host="127.0.0.1")).ok;
        users.create_user_with_identities.assert_not_called();
    }
    with patch(
        register_auth_endpoints.__module__ + '.auth_settings',
        return_value=AuthSettings(registration_challenge=True)
    ), patch(
        register_auth_endpoints.__module__ + '.consume_challenge', return_value=True
    ) {
        assert handler(request, MagicMock(client_host="127.0.0.1")).ok;
        users.create_user_with_identities.assert_called_once();
    }
}

test "registration challenge is opt in for other projects" {
    assert not AuthSettings().registration_challenge;
}

test "verified GitHub identity can create an account without registration proof" {
    manager = MagicMock();
    manager.get_user_by_sso.return_value = None;
    manager.create_user.return_value = {'user_id': 'github-user'};
    manager.link_sso_account.return_value = {};
    manager.get_user.return_value = {
        'status': 'active',
        'role': 'user',
        'identities': []
    };
    manager.create_jwt_token.return_value = 'github-session';
    with patch(register_auth_endpoints.__module__ + '.consume_challenge') as verify {
        result = complete_identity(
            manager,
            SSOUserInfo(email='', external_id='123', username='github_alice'),
            'github'
        );
        assert result.ok;
        assert result.token == 'github-session';
        manager.create_user.assert_called_once();
        verify.assert_not_called();
    }
}
