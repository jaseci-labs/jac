import os;
import shutil;
import asyncio;
import json;
import unittest.mock;
import from tempfile { mkdtemp }
import from jaclang.server.serving.datatypes { Request }

import from jaclang.scale.config.config_loader { reset_scale_config }
import from jaclang.scale.shared.enums { Platforms, Operations }
import from jaclang.server.identity.user_manager { UserManager }
import from jaclang.scale.sso.provider { SSOUserInfo }
import from jaclang.scale.server.sso_ext { SSOExtension }
import from jaclang.scale.sso.sso_auth { SSOAuth }
import from jaclang.scale.tests.support { RecordingHost }
import from jaclang.scale._optdeps.firebase_auth {
    firebase_admin as _real_firebase_admin
}
import from jaclang.scale.tests.scale_test_client { make_client, extract_data }
import from jaclang.server.transport { TransportResponse }


def _as_any(value: any) -> any {
    return value;
}


def mock_sso_config_with_firebase -> dict {
    return {
        'host': 'http://localhost:8000',
        'google': {'client_id': '', 'client_secret': ''},
        'apple': {'client_id': '', 'client_secret': ''},
        'github': {'client_id': '', 'client_secret': ''},
        'firebase': {'project_id': 'test-firebase-project'}
    };
}


def mock_sso_config_without_firebase -> dict {
    return {
        'host': 'http://localhost:8000',
        'google': {'client_id': '', 'client_secret': ''},
        'apple': {'client_id': '', 'client_secret': ''},
        'github': {'client_id': '', 'client_secret': ''},
        'firebase': {'project_id': ''}
    };
}


obj MockScaleConfig {
    has sso_config: dict;

    def get_sso_config -> dict {
        return self.sso_config;
    }

    def get_jwt_config -> dict {
        return {'secret': 'test_secret', 'algorithm': 'HS256', 'exp_delta_days': 1};
    }

    def get_database_config -> dict {
        return {'redis_url': None, 'shelf_db_path': '.jac/data/anchor_store.db'};
    }

    def get_monitoring_config -> dict {
        return {'enabled': False, 'port': 9090};
    }
}


def _setup_user_manager(sso_config: dict) -> tuple[str, SSOAuth] {
    test_dir = mkdtemp();
    reset_scale_config();
    mock_config = MockScaleConfig(sso_config);
    user_manager = UserManager(base_path=test_dir);
    with unittest.mock.patch(
        'jaclang.scale.sso.sso_auth.get_scale_config', return_value=mock_config
    ) {
        sso = SSOAuth(users=user_manager);
    }
    return (test_dir, sso);
}


def _sso_of(server: any) -> SSOAuth {
    for ext in (server.extensions or []) {
        if isinstance(ext, SSOExtension) and ext.sso is not None {
            return ext.sso;
        }
    }
    raise RuntimeError('SSO extension not registered on this server');
}


obj MockFirebaseSSO {
    has user_info: SSOUserInfo;

    async def handle_id_token(id_token: str) -> SSOUserInfo {
        if not id_token {
            raise ValueError("Missing 'id_token'.");
        }
        return self.user_info;
    }
}


def _create_existing_user(user_manager: UserManager, email: str) -> str {
    result = user_manager.create_user_with_identities(
        identities=[{'type': 'email', 'value': email, 'verified': True}],
        credential={'type': 'password', 'password': 'existing_pass'}
    );
    return result.get('user_id', '');
}


def _teardown_user_manager(test_dir: str) {
    if os.path.exists(test_dir) {
        shutil.rmtree(test_dir);
    }
}


def _make_request(body: dict) -> Request {
    mock_request: any = unittest.mock.Mock(spec=Request);
    mock_request.body = _as_any(json.dumps(body).encode('utf-8'));
    return mock_request;
}


def _mock_firebase_admin -> unittest.mock.MagicMock {
    mock = unittest.mock.MagicMock();
    mock.get_app.side_effect = ValueError('no app');
    mock.initialize_app.return_value = unittest.mock.Mock();
    return mock;
}


test 'platforms enum includes firebase' {
    assert Platforms.FIREBASE.value == 'firebase';
}


test 'supported platforms includes firebase when configured' {
    reset_scale_config();
    mock_config = MockScaleConfig(mock_sso_config_with_firebase());
    with unittest.mock.patch(
        'jaclang.scale.sso.sso_auth.get_scale_config', return_value=mock_config
    ) {
        user_manager = SSOAuth(users=unittest.mock.Mock());
        assert 'firebase' in user_manager.platforms;
        assert user_manager.platforms['firebase']['project_id']
            == 'test-firebase-project';
    }
}


test 'supported platforms excludes firebase when not configured' {
    reset_scale_config();
    mock_config = MockScaleConfig(mock_sso_config_without_firebase());
    with unittest.mock.patch(
        'jaclang.scale.sso.sso_auth.get_scale_config', return_value=mock_config
    ) {
        user_manager = SSOAuth(users=unittest.mock.Mock());
        assert 'firebase' not in user_manager.platforms;
    }
}


test 'get sso with firebase platform' {
    (test_dir, auth) = _setup_user_manager(mock_sso_config_with_firebase());
    user_manager = auth.users;
    try {
        mock_fb = _mock_firebase_admin();
        with unittest.mock.patch(
            'jaclang.scale._optdeps.firebase_auth.HAS_FIREBASE_ADMIN', True
        ), unittest.mock.patch(
            'jaclang.scale._optdeps.firebase_auth.firebase_admin', mock_fb
        ), unittest.mock.patch(
            'jaclang.scale._optdeps.firebase_auth.credentials', mock_fb.credentials
        ), unittest.mock.patch('jaclang.scale.sso.firebase.firebase_admin', mock_fb), unittest.mock.patch(
            'jaclang.scale.sso.firebase.credentials', mock_fb.credentials
        ) {
            sso = auth.get_sso(Platforms.FIREBASE.value);
            assert sso is not None;
            assert sso.project_id == 'test-firebase-project';
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}


test 'firebase sso initiate returns helpful error' {
    (test_dir, auth) = _setup_user_manager(mock_sso_config_with_firebase());
    user_manager = auth.users;
    try {
        coro: any = auth.sso_initiate(Platforms.FIREBASE.value, Operations.LOGIN.value);
        result: any = asyncio.run(coro);
        assert isinstance(result, TransportResponse);
        assert not result.ok;
        assert result.error is not None;
        assert 'POST /sso/firebase/token' in result.error.message;
    } finally {
        _teardown_user_manager(test_dir);
    }
}


test 'firebase token auth login existing user' {
    (test_dir, auth) = _setup_user_manager(mock_sso_config_with_firebase());
    user_manager = auth.users;
    try {
        user_id = _create_existing_user(user_manager, 'user@example.com');
        user_manager.link_sso_account(user_id, 'firebase', 'firebase-uid-123');
        mock_sso = MockFirebaseSSO(
            SSOUserInfo(
                email='user@example.com',
                external_id='firebase-uid-123',
                display_name='Test User',
                picture='https://example.com/picture.jpg'
            )
        );
        with unittest.mock.patch.object(auth, 'get_sso', return_value=mock_sso) {
            coro: any = auth.firebase_token_auth_with_id_token('firebase-token');
            result: any = asyncio.run(coro);
            assert result.ok;
            assert result.data['message'] == 'Login successful';
            assert result.data['platform'] == 'firebase';
            assert result.data['user_id'] == user_id;
            token = result.data['token'];
            assert token;
            assert user_manager.validate_jwt_token(token) == user_id;
            accounts = user_manager.get_sso_accounts(user_id);
            assert len(accounts) == 1;
            assert accounts[0]['platform'] == 'firebase';
            assert accounts[0]['external_id'] == 'firebase-uid-123';
            stored = user_manager.get_user(user_id);
            firebase_sso = stored['profile']['sso']['firebase'];
            assert firebase_sso['display_name'] == 'Test User';
            assert firebase_sso['picture'] == 'https://example.com/picture.jpg';
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}


test 'firebase token auth auto register new user' {
    (test_dir, auth) = _setup_user_manager(mock_sso_config_with_firebase());
    user_manager = auth.users;
    try {
        assert user_manager.find_user_by_identity('newuser@example.com') is None;
        mock_sso = MockFirebaseSSO(
            SSOUserInfo(
                email='newuser@example.com',
                external_id='firebase-uid-999',
                display_name='New User'
            )
        );
        with unittest.mock.patch.object(auth, 'get_sso', return_value=mock_sso) {
            coro: any = auth.firebase_token_auth_with_id_token('firebase-token');
            result: any = asyncio.run(coro);
            assert result.ok;
            user_id = result.data['user_id'];
            assert user_id;
            token = result.data['token'];
            assert token;
            assert user_manager.validate_jwt_token(token) == user_id;
            assert user_manager.find_user_by_identity('newuser@example.com') is None;
            created = user_manager.get_user(user_id);
            assert created is not None;
            assert created['user_id'] == user_id;
            assert created['profile']['sso']['firebase']['display_name'] == 'New User';
            accounts = user_manager.get_sso_accounts(user_id);
            assert len(accounts) == 1;
            assert accounts[0]['platform'] == 'firebase';
            assert accounts[0]['external_id'] == 'firebase-uid-999';
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}


test 'firebase token auth not configured' {
    (test_dir, auth) = _setup_user_manager(mock_sso_config_without_firebase());
    user_manager = auth.users;
    try {
        coro: any = auth.firebase_token_auth_with_id_token('firebase-token');
        result: any = asyncio.run(coro);
        assert not result.ok;
        assert 'not configured' in result.error.message.lower();
    } finally {
        _teardown_user_manager(test_dir);
    }
}


test 'firebase provider missing id token fails' {
    mock_fb = _mock_firebase_admin();
    with unittest.mock.patch(
        'jaclang.scale._optdeps.firebase_auth.HAS_FIREBASE_ADMIN', True
    ), unittest.mock.patch(
        'jaclang.scale._optdeps.firebase_auth.firebase_admin', mock_fb
    ), unittest.mock.patch(
        'jaclang.scale._optdeps.firebase_auth.credentials', mock_fb.credentials
    ), unittest.mock.patch('jaclang.scale._optdeps.firebase_auth.auth', mock_fb.auth), unittest.mock.patch(
        'jaclang.scale.sso.firebase.firebase_admin', mock_fb
    ), unittest.mock.patch(
        'jaclang.scale.sso.firebase.credentials', mock_fb.credentials
    ), unittest.mock.patch('jaclang.scale.sso.firebase.auth', mock_fb.auth) {
        import from jaclang.scale.sso.firebase { FirebaseSSOProvider }
        provider = FirebaseSSOProvider(project_id='test-project');
        raised = False;
        try {
            cb: any = provider.handle_callback(_make_request({'nope': 'x'}));
            asyncio.run(cb);
        } except ValueError as e {
            raised = True;
            assert "id_token" in str(e);
        }
        assert raised;
    }
}


test 'register firebase token endpoint' {
    mock_config = MockScaleConfig(mock_sso_config_with_firebase());
    host = RecordingHost(users=_as_any(unittest.mock.Mock()));
    with unittest.mock.patch(
        'jaclang.scale.sso.sso_auth.get_scale_config', return_value=mock_config
    ) {
        SSOExtension().register(_as_any(host));
    }
    endpoints = [
        e
        for e in host._endpoints
        if e.path == '/sso/firebase/token'
    ];
    assert len(endpoints) == 1;
    assert endpoints[0].method.name == 'POST';
}


test 'firebase token endpoint http integration' {
    original_project_id = os.environ.get('FIREBASE_AUTH_PROJECT_ID');
    os.environ['FIREBASE_AUTH_PROJECT_ID'] = 'test-firebase-project';
    reset_scale_config();
    client = make_client();
    try {
        user_manager = client.server.user_manager;
        auth = _sso_of(client.server);
        user_id = _create_existing_user(user_manager, 'user@example.com');
        user_manager.link_sso_account(user_id, 'firebase', 'firebase-uid-123');
        mock_sso = MockFirebaseSSO(
            SSOUserInfo(
                email='user@example.com',
                external_id='firebase-uid-123',
                display_name='Test User',
                picture='https://example.com/picture.jpg'
            )
        );
        with unittest.mock.patch.object(auth, 'get_sso', return_value=mock_sso) {
            response = client.post(
                '/sso/firebase/token', json={'id_token': 'firebase-token'}
            );
            assert response.status_code == 200 , (
                f"Expected 200, got {response.status_code}: {response.text}"
            );
            data = extract_data(response.json());
            assert data.get('message') == 'Login successful';
            assert data.get('platform') == 'firebase';
            assert data.get('user_id') == user_id;
            token = data.get('token');
            assert token;
            assert user_manager.validate_jwt_token(token) == user_id;
            accounts = user_manager.get_sso_accounts(user_id);
            assert len(accounts) == 1;
            assert accounts[0]['platform'] == 'firebase';
            stored = user_manager.get_user(user_id);
            assert stored['profile']['sso']['firebase']['display_name'] == 'Test User';
        }
    } finally {
        client.close();
        reset_scale_config();
        if original_project_id is not None {
            os.environ['FIREBASE_AUTH_PROJECT_ID'] = original_project_id;
        } else {
            os.environ.pop('FIREBASE_AUTH_PROJECT_ID', None);
        }
    }
}
