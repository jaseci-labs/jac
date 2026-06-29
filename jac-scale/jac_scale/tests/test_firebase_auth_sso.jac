import os;
import shutil;
import asyncio;
import json;
import unittest.mock;
import from tempfile { mkdtemp }
import from uuid { uuid4 }
import from fastapi { Request }

import from jac_scale.config.config_loader { reset_scale_config }
import from jac_scale.shared.enums { Platforms, Operations }
import from jac_scale.identity.user_manager { JacScaleUserManager }
import from jac_scale.server.serve { JacAPIServer }
import from jac_scale._optdeps.firebase_auth { firebase_admin as _real_firebase_admin }
import from jac_scale.tests.scale_test_client { make_client, extract_data }
import from jaclang.runtimelib.transport { TransportResponse }


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
        return {
            'mongodb_uri': None,
            'redis_url': None,
            'shelf_db_path': '.jac/data/anchor_store.db'
        };
    }

    def get_monitoring_config -> dict {
        return {'enabled': False, 'port': 9090};
    }
}


def _setup_user_manager(sso_config: dict) -> tuple[str, JacScaleUserManager] {
    test_dir = mkdtemp();
    reset_scale_config();
    mock_config = MockScaleConfig(sso_config);
    with unittest.mock.patch(
        'jac_scale.identity.user_manager.get_scale_config', return_value=mock_config
    ) {
        user_manager = JacScaleUserManager(base_path=test_dir);
    }
    user_manager.create_user_with_identities = unittest.mock.Mock();
    user_manager.find_user_by_identity = unittest.mock.Mock();
    user_manager.link_sso_account = unittest.mock.Mock(return_value={});
    return (test_dir, user_manager);
}


def _teardown_user_manager(test_dir: str) {
    if os.path.exists(test_dir) {
        shutil.rmtree(test_dir);
    }
}


def _make_request(body: dict) -> Request {
    mock_request = unittest.mock.Mock(spec=Request);
    mock_request.body = unittest.mock.AsyncMock(
        return_value=json.dumps(body).encode('utf-8')
    );
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
        'jac_scale.identity.user_manager.get_scale_config', return_value=mock_config
    ) {
        user_manager = JacScaleUserManager(base_path='');
        assert 'firebase' in user_manager.SUPPORTED_PLATFORMS;
        assert user_manager.SUPPORTED_PLATFORMS['firebase']['project_id'] == 'test-firebase-project';
    }
}


test 'supported platforms excludes firebase when not configured' {
    reset_scale_config();
    mock_config = MockScaleConfig(mock_sso_config_without_firebase());
    with unittest.mock.patch(
        'jac_scale.identity.user_manager.get_scale_config', return_value=mock_config
    ) {
        user_manager = JacScaleUserManager(base_path='');
        assert 'firebase' not in user_manager.SUPPORTED_PLATFORMS;
    }
}


test 'get sso with firebase platform' {
    (test_dir, user_manager) = _setup_user_manager(mock_sso_config_with_firebase());
    try {
        mock_fb = _mock_firebase_admin();
        with unittest.mock.patch(
            'jac_scale._optdeps.firebase_auth.HAS_FIREBASE_ADMIN', True
        ), unittest.mock.patch(
            'jac_scale._optdeps.firebase_auth.firebase_admin', mock_fb
        ), unittest.mock.patch(
            'jac_scale._optdeps.firebase_auth.credentials', mock_fb.credentials
        ), unittest.mock.patch('jac_scale.sso.firebase.firebase_admin', mock_fb), unittest.mock.patch(
            'jac_scale.sso.firebase.credentials', mock_fb.credentials
        ) {
            sso = user_manager.get_sso(Platforms.FIREBASE.value);
            assert sso is not None;
            assert sso.project_id == 'test-firebase-project';
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}


test 'firebase sso initiate returns helpful error' {
    (test_dir, user_manager) = _setup_user_manager(mock_sso_config_with_firebase());
    try {
        result = asyncio.run(
            user_manager.sso_initiate(Platforms.FIREBASE.value, Operations.LOGIN.value)
        );
        assert isinstance(result, TransportResponse);
        assert not result.ok;
        assert 'POST /sso/firebase/token' in result.error.message;
    } finally {
        _teardown_user_manager(test_dir);
    }
}


test 'firebase token auth login existing user' {
    (test_dir, user_manager) = _setup_user_manager(mock_sso_config_with_firebase());
    try {
        mock_user_id = str(uuid4());
        user_manager.find_user_by_identity.return_value = {
            'user_id': mock_user_id,
            'root_id': str(uuid4()),
            'profile': {}
        };
        mock_fb = _mock_firebase_admin();
        mock_fb.auth.verify_id_token.return_value = {
            'email': 'user@example.com',
            'uid': 'firebase-uid-123',
            'name': 'Test User',
            'picture': 'https://example.com/picture.jpg'
        };
        with unittest.mock.patch(
            'jac_scale._optdeps.firebase_auth.HAS_FIREBASE_ADMIN', True
        ), unittest.mock.patch(
            'jac_scale._optdeps.firebase_auth.firebase_admin', mock_fb
        ), unittest.mock.patch(
            'jac_scale._optdeps.firebase_auth.credentials', mock_fb.credentials
        ), unittest.mock.patch('jac_scale._optdeps.firebase_auth.auth', mock_fb.auth), unittest.mock.patch(
            'jac_scale.sso.firebase.firebase_admin', mock_fb
        ), unittest.mock.patch(
            'jac_scale.sso.firebase.credentials', mock_fb.credentials
        ), unittest.mock.patch('jac_scale.sso.firebase.auth', mock_fb.auth), unittest.mock.patch.object(
            user_manager._identity_storage, 'update_user_fields', return_value=True
        ), unittest.mock.patch.object(
            user_manager, 'create_jwt_token', return_value='jwt-token'
        ) {
            result = asyncio.run(
                user_manager.firebase_token_auth_with_id_token('firebase-token')
            );
            assert result.ok;
            assert result.data['message'] == 'Login successful';
            assert result.data['token'] == 'jwt-token';
            assert result.data['platform'] == 'firebase';
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}


test 'firebase token auth auto register new user' {
    (test_dir, user_manager) = _setup_user_manager(mock_sso_config_with_firebase());
    try {
        user_manager.find_user_by_identity.return_value = None;
        user_manager.create_user_with_identities.return_value = {
            'user_id': str(uuid4()),
            'message': 'User registered successfully'
        };
        mock_fb = _mock_firebase_admin();
        mock_fb.auth.verify_id_token.return_value = {
            'email': 'newuser@example.com',
            'uid': 'firebase-uid-999',
            'name': 'New User'
        };
        with unittest.mock.patch(
            'jac_scale._optdeps.firebase_auth.HAS_FIREBASE_ADMIN', True
        ), unittest.mock.patch(
            'jac_scale._optdeps.firebase_auth.firebase_admin', mock_fb
        ), unittest.mock.patch(
            'jac_scale._optdeps.firebase_auth.credentials', mock_fb.credentials
        ), unittest.mock.patch('jac_scale._optdeps.firebase_auth.auth', mock_fb.auth), unittest.mock.patch(
            'jac_scale.sso.firebase.firebase_admin', mock_fb
        ), unittest.mock.patch(
            'jac_scale.sso.firebase.credentials', mock_fb.credentials
        ), unittest.mock.patch('jac_scale.sso.firebase.auth', mock_fb.auth), unittest.mock.patch.object(
            user_manager, 'create_jwt_token', return_value='jwt-token'
        ), unittest.mock.patch(
            'jac_scale.identity.user_manager.generate_random_password',
            return_value='random-pass'
        ) {
            result = asyncio.run(
                user_manager.firebase_token_auth_with_id_token('firebase-token')
            );
            assert result.ok;
            assert result.data['token'] == 'jwt-token';
            user_manager.create_user_with_identities.assert_called_once();
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}


test 'firebase token auth not configured' {
    (test_dir, user_manager) = _setup_user_manager(mock_sso_config_without_firebase());
    try {
        result = asyncio.run(
            user_manager.firebase_token_auth_with_id_token('firebase-token')
        );
        assert not result.ok;
        assert 'not configured' in result.error.message.lower();
    } finally {
        _teardown_user_manager(test_dir);
    }
}


test 'firebase provider missing id token fails' {
    mock_fb = _mock_firebase_admin();
    with unittest.mock.patch(
        'jac_scale._optdeps.firebase_auth.HAS_FIREBASE_ADMIN', True
    ), unittest.mock.patch('jac_scale._optdeps.firebase_auth.firebase_admin', mock_fb), unittest.mock.patch(
        'jac_scale._optdeps.firebase_auth.credentials', mock_fb.credentials
    ), unittest.mock.patch('jac_scale._optdeps.firebase_auth.auth', mock_fb.auth), unittest.mock.patch(
        'jac_scale.sso.firebase.firebase_admin', mock_fb
    ), unittest.mock.patch('jac_scale.sso.firebase.credentials', mock_fb.credentials), unittest.mock.patch(
        'jac_scale.sso.firebase.auth', mock_fb.auth
    ) {
        import from jac_scale.sso.firebase { FirebaseSSOProvider }
        provider = FirebaseSSOProvider(project_id='test-project');
        raised = False;
        try {
            asyncio.run(provider.handle_callback(_make_request({'nope': 'x'})));
        } except ValueError as e {
            raised = True;
            assert "id_token" in str(e);
        }
        assert raised;
    }
}


test 'register firebase token endpoint' {
    mock_server_impl = unittest.mock.Mock();
    mock_user_manager = unittest.mock.Mock();
    mock_config = MockScaleConfig(mock_sso_config_with_firebase());
    with unittest.mock.patch(
        'jac_scale.server.serve.get_scale_config', return_value=mock_config
    ) {
        with unittest.mock.patch(
            'jaclang.jac0core.runtime.JacRuntimeInterface.get_user_manager',
            return_value=mock_user_manager
        ) {
            server = JacAPIServer(module_name='test_module', port=8000);
        }
    }
    server.server = mock_server_impl;
    mock_server_impl.reset_mock();
    server.register_firebase_token_endpoint();
    mock_server_impl.add_endpoint.assert_called_once();
    endpoint = mock_server_impl.add_endpoint.call_args[0][0];
    assert endpoint.path == '/sso/firebase/token';
    assert endpoint.method.name == 'POST';
}


test 'firebase token endpoint http integration' {
    original_project_id = os.environ.get('FIREBASE_AUTH_PROJECT_ID');
    os.environ['FIREBASE_AUTH_PROJECT_ID'] = 'test-firebase-project';
    reset_scale_config();
    mock_fb = _mock_firebase_admin();
    mock_fb.auth.verify_id_token.return_value = {
        'email': 'user@example.com',
        'uid': 'firebase-uid-123',
        'name': 'Test User',
        'picture': 'https://example.com/picture.jpg'
    };
    client = make_client();
    try {
        user_manager = client.server.user_manager;
        mock_user_id = str(uuid4());
        user_manager.find_user_by_identity = unittest.mock.Mock(
            return_value={
                'user_id': mock_user_id,
                'root_id': str(uuid4()),
                'profile': {}
            }
        );
        with unittest.mock.patch(
            'jac_scale._optdeps.firebase_auth.HAS_FIREBASE_ADMIN', True
        ), unittest.mock.patch(
            'jac_scale._optdeps.firebase_auth.firebase_admin', mock_fb
        ), unittest.mock.patch(
            'jac_scale._optdeps.firebase_auth.credentials', mock_fb.credentials
        ), unittest.mock.patch('jac_scale._optdeps.firebase_auth.auth', mock_fb.auth), unittest.mock.patch(
            'jac_scale.sso.firebase.firebase_admin', mock_fb
        ), unittest.mock.patch(
            'jac_scale.sso.firebase.credentials', mock_fb.credentials
        ), unittest.mock.patch('jac_scale.sso.firebase.auth', mock_fb.auth), unittest.mock.patch.object(
            user_manager._identity_storage, 'update_user_fields', return_value=True
        ) {
            response = client.post(
                '/sso/firebase/token', json={'id_token': 'firebase-token'}
            );
            assert response.status_code == 200 , (
                f"Expected 200, got {response.status_code}: {response.text}"
            );
            data = extract_data(response.json());
            assert data.get('message') == 'Login successful';
            assert data.get('platform') == 'firebase';
            assert 'token' in data;
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
