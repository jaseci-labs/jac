"""Test for SSO (Single Sign-On) implementation in jac-scale."""

import json;
import os;
import shutil;
import asyncio;
import from tempfile { mkdtemp }
import from typing { Any }
import from dataclasses { dataclass }
import from types { TracebackType }
import unittest.mock;
import from uuid { uuid4 }

import pytest;
import from fastapi { Request }
import from fastapi.responses { JSONResponse, RedirectResponse }

import from jac_scale.config_loader { reset_scale_config }
import from jac_scale.sso.google { GoogleSSOProvider }
import from jac_scale.sso.apple { AppleSSOProvider }
import from jac_scale.sso.github { GithubSSOProvider }
import from jac_scale.serve { JacAPIServer }
import from jac_scale.enums { Platforms, Operations }
import from jac_scale.user_manager { JacScaleUserManager }
import from jaclang.runtimelib.transport { TransportResponse }

"""Return mock SSO config with Google, Apple, and GitHub credentials configured."""
def mock_sso_config_with_credentials -> dict {
    return {
        "host": "http://localhost:8000",
        "google": {
            "client_id": "test_client_id",
            "client_secret": "test_client_secret"
        },
        "apple": {
            "client_id": "apple_test_client_id",
            "client_secret": "apple_test_client_secret"
        },
        "github": {
            "client_id": "github_test_client_id",
            "client_secret": "github_test_client_secret"
        }
    };
}

"""Return mock SSO config without credentials."""
def mock_sso_config_without_credentials -> dict {
    return {
        "host": "http://localhost:8000",
        "google": {"client_id": "", "client_secret": ""},
        "apple": {"client_id": "", "client_secret": ""},
        "github": {"client_id": "", "client_secret": ""}
    };
}

"""Return mock SSO config with only client_id (no secret)."""
def mock_sso_config_partial_credentials -> dict {
    return {
        "host": "http://localhost:8000",
        "google": {"client_id": "test_id", "client_secret": ""},
        "apple": {"client_id": "apple_test_id", "client_secret": ""},
        "github": {"client_id": "github_test_id", "client_secret": ""}
    };
}

"""Mock user info from SSO provider."""
@dataclass
obj MockUserInfo {
    has email: str,
        id: str = "mock_sso_id",
        external_id: str = "mock_external_id",
        first_name: str = "Test",
        last_name: str = "User",
        display_name: str = "Test User",
        picture: str = "https://example.com/picture.jpg";

    """Mirror SSOUserInfo.profile_fields() so production code can call it."""
    def profile_fields -> dict[str, Any] {
        fields: dict[str, Any] = {};
        for key in ['display_name', 'first_name', 'last_name', 'picture'] {
            val = getattr(self, key, None);
            if val {
                fields[key] = val;
            }
        }
        return fields;
    }
}

"""Mock GoogleSSO for testing - implements SSOProvider interface."""
obj MockGoogleSSO {
    has client_id: str,
        client_secret: str,
        redirect_uri: str,
        allow_insecure_http: bool = False;

    def postinit {
        self.get_login_redirect = self._default_get_login_redirect;
        self.verify_and_process = self._default_verify_and_process;
        self.initiate_auth = self._default_initiate_auth;
        self.handle_callback = self._default_handle_callback;
    }

    """Mock get_login_redirect method."""
    async def _default_get_login_redirect -> RedirectResponse {
        return RedirectResponse(url="https://accounts.google.com/oauth/authorize");
    }

    """Mock verify_and_process method."""
    async def _default_verify_and_process(_request: Request) -> MockUserInfo {
        return MockUserInfo(email="test@example.com");
    }

    """Mock initiate_auth method (SSOProvider interface)."""
    async def _default_initiate_auth -> RedirectResponse {
        return RedirectResponse(url="https://accounts.google.com/oauth/authorize");
    }

    """Mock handle_callback method (SSOProvider interface)."""
    async def _default_handle_callback(request: Request) -> MockUserInfo {
        return await self.verify_and_process(request);
    }

    def __enter__ -> "MockGoogleSSO" {
        return self;
    }

    def __exit__(
        _exc_type: type | None,
        _exc_val: BaseException | None,
        _exc_tb: TracebackType | None
    ) -> None {
        0;
    }
}

"""Mock AppleSSO for testing - implements SSOProvider interface."""
obj MockAppleSSO {
    has client_id: str,
        client_secret: str,
        redirect_uri: str,
        allow_insecure_http: bool = False;

    def postinit {
        self.get_login_redirect = self._default_get_login_redirect;
        self.verify_and_process = self._default_verify_and_process;
        self.initiate_auth = self._default_initiate_auth;
        self.handle_callback = self._default_handle_callback;
    }

    """Mock get_login_redirect method."""
    async def _default_get_login_redirect -> RedirectResponse {
        return RedirectResponse(url="https://appleid.apple.com/auth/authorize");
    }

    """Mock verify_and_process method."""
    async def _default_verify_and_process(_request: Request) -> MockUserInfo {
        return MockUserInfo(email="test@privaterelay.appleid.com");
    }

    """Mock initiate_auth method (SSOProvider interface)."""
    async def _default_initiate_auth -> RedirectResponse {
        return RedirectResponse(url="https://appleid.apple.com/auth/authorize");
    }

    """Mock handle_callback method (SSOProvider interface)."""
    async def _default_handle_callback(request: Request) -> MockUserInfo {
        return await self.verify_and_process(request);
    }

    def __enter__ -> "MockAppleSSO" {
        return self;
    }

    def __exit__(
        _exc_type: type | None,
        _exc_val: BaseException | None,
        _exc_tb: TracebackType | None
    ) -> None {
        0;
    }
}

"""Mock GithubSSO for testing - implements SSOProvider interface."""
obj MockGithubSSO {
    has client_id: str,
        client_secret: str,
        redirect_uri: str,
        allow_insecure_http: bool = False;

    def postinit {
        self.get_login_redirect = self._default_get_login_redirect;
        self.verify_and_process = self._default_verify_and_process;
        self.initiate_auth = self._default_initiate_auth;
        self.handle_callback = self._default_handle_callback;
    }

    """Mock get_login_redirect method."""
    async def _default_get_login_redirect -> RedirectResponse {
        return RedirectResponse(url="https://github.com/login/oauth/authorize");
    }

    """Mock verify_and_process method."""
    async def _default_verify_and_process(_request: Request) -> MockUserInfo {
        return MockUserInfo(email="test@github.com");
    }

    """Mock initiate_auth method (SSOProvider interface)."""
    async def _default_initiate_auth -> RedirectResponse {
        return RedirectResponse(url="https://github.com/login/oauth/authorize");
    }

    """Mock handle_callback method (SSOProvider interface)."""
    async def _default_handle_callback(request: Request) -> MockUserInfo {
        return await self.verify_and_process(request);
    }

    def __enter__ -> "MockGithubSSO" {
        return self;
    }

    def __exit__(
        _exc_type: type | None,
        _exc_val: BaseException | None,
        _exc_tb: TracebackType | None
    ) -> None {
        0;
    }
}

"""Mock JacScaleConfig for testing."""
obj MockScaleConfig {
    has sso_config: dict | None = None,
        _sso_config: dict by postinit;

    def postinit {
        self._sso_config = self.sso_config or mock_sso_config_with_credentials();
    }

    def get_sso_config -> dict {
        return self._sso_config;
    }

    def get_jwt_config -> dict {
        return {"secret": "test_secret", "algorithm": "HS256", "exp_delta_days": 1};
    }

    def get_database_config -> dict {
        return {
            "mongodb_uri": None,
            "redis_url": None,
            "shelf_db_path": ".jac/data/anchor_store.db"
        };
    }

    def get_kubernetes_config -> dict {
        return {"namespace": "default"};
    }

    def get_monitoring_config -> dict {
        return {"enabled": False};
    }
}

"""Extract body content from JSONResponse or TransportResponse."""
def _get_response_body(result: JSONResponse | TransportResponse) -> str {
    if isinstance(result, JSONResponse) {
        return result.body.decode("utf-8");
    } elif isinstance(result, TransportResponse) {
        response_dict = {
            "ok": result.ok,
            "type": result.type,
            "data": result.data,
            "error": None
        };
        if not result.ok and result.error {
            response_dict["error"] = {
                "code": result.error.code,
                "message": result.error.message,
                "details": result.error.details
            };
        }
        if result.meta {
            meta_dict = {};
            if result.meta.request_id {
                meta_dict["request_id"] = result.meta.request_id;
            }
            if result.meta.trace_id {
                meta_dict["trace_id"] = result.meta.trace_id;
            }
            if result.meta.timestamp {
                meta_dict["timestamp"] = result.meta.timestamp;
            }
            if result.meta.extra {
                meta_dict["extra"] = result.meta.extra;
            }
            if meta_dict {
                response_dict["meta"] = meta_dict;
            }
        }
        return json.dumps(response_dict);
    } else {
        raise TypeError(f"Unexpected response type: {type(result)}");
    }
}

"""Setup a user manager with temp dir for testing."""
def _setup_user_manager -> tuple[str, JacScaleUserManager] {
    test_dir = mkdtemp();
    reset_scale_config();
    mock_config = MockScaleConfig(mock_sso_config_with_credentials());
    with unittest.mock.patch(
        "jac_scale.user_manager.get_scale_config", return_value=mock_config
    ) {
        user_manager = JacScaleUserManager(base_path=test_dir);
    }
    user_manager.create_user = unittest.mock.Mock();
    user_manager.get_user = unittest.mock.Mock();
    return (test_dir, user_manager);
}

"""Teardown user manager temp dir."""
def _teardown_user_manager(test_dir: str) -> None {
    if os.path.exists(test_dir) {
        shutil.rmtree(test_dir);
    }
}

# ============================================================================
# Common SSO Tests (get_sso, sso_initiate, sso_callback)
# ============================================================================
"""Test get_sso returns GoogleSSO instance for Google platform."""
test "get sso with google platform" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        with unittest.mock.patch(
            "jac_scale.sso.google.GoogleSSOProvider", side_effect=MockGoogleSSO
        ) as mock_sso {
            sso = user_manager.get_sso(Platforms.GOOGLE.value);
            assert sso is not None;
            assert sso.client_id == "test_client_id";
            assert sso.client_secret == "test_client_secret";
            mock_sso.assert_called_once();
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test get_sso returns None for invalid platform."""
test "get sso with invalid platform" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        sso = user_manager.get_sso("invalid_platform");
        assert sso is None;
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test get_sso returns None when platform credentials are not configured."""
test "get sso with unconfigured platform" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        reset_scale_config();
        mock_config = MockScaleConfig(mock_sso_config_without_credentials());
        with unittest.mock.patch(
            "jac_scale.user_manager.get_scale_config", return_value=mock_config
        ) {
            um = JacScaleUserManager(base_path="");
            sso = um.get_sso(Platforms.GOOGLE.value);
            assert sso is None;
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test get_sso creates correct redirect URI (host + /sso/{platform}/callback)."""
test "get sso redirect uri format" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        with unittest.mock.patch(
            "jac_scale.sso.google.GoogleSSOProvider", side_effect=MockGoogleSSO
        ) {
            sso = user_manager.get_sso(Platforms.GOOGLE.value);
            assert sso.redirect_uri == "http://localhost:8000/sso/google/callback";
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test successful SSO initiation."""
test "sso initiate success" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        with unittest.mock.patch.object(
            user_manager, "get_sso", return_value=MockGoogleSSO("id", "secret", "uri")
        ) {
            result = asyncio.run(
                user_manager.sso_initiate(
                    Platforms.GOOGLE.value, Operations.LOGIN.value
                )
            );
            assert isinstance(result, RedirectResponse);
            assert "google.com" in result.headers.get("location", "");
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test SSO initiation with invalid platform."""
test "sso initiate with invalid platform" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        result = asyncio.run(
            user_manager.sso_initiate("invalid_platform", Operations.LOGIN.value)
        );
        assert isinstance(result, (JSONResponse, TransportResponse));
        body = _get_response_body(result);
        assert "Invalid platform" in body;
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test SSO initiation with unconfigured platform."""
test "sso initiate with unconfigured platform" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        user_manager.SUPPORTED_PLATFORMS = {};
        result = asyncio.run(
            user_manager.sso_initiate(Platforms.GOOGLE.value, Operations.LOGIN.value)
        );
        assert isinstance(result, (JSONResponse, TransportResponse));
        body = _get_response_body(result);
        assert "not configured" in body;
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test SSO initiation with invalid operation."""
test "sso initiate with invalid operation" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        result = asyncio.run(
            user_manager.sso_initiate(Platforms.GOOGLE.value, "invalid_operation")
        );
        assert isinstance(result, (JSONResponse, TransportResponse));
        body = _get_response_body(result);
        assert "Invalid operation" in body;
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test SSO initiation when get_sso returns None."""
test "sso initiate when get sso fails" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        with unittest.mock.patch.object(user_manager, "get_sso", return_value=None) {
            result = asyncio.run(
                user_manager.sso_initiate(
                    Platforms.GOOGLE.value, Operations.LOGIN.value
                )
            );
            assert isinstance(result, (JSONResponse, TransportResponse));
            body = _get_response_body(result);
            assert "Failed to initialize SSO" in body;
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test SSO callback logs in existing user."""
test "sso callback login existing user" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        mock_user_id = str(uuid4());
        mock_root_id = str(uuid4());
        user_manager.find_user_by_identity = unittest.mock.Mock(
            return_value={
                "user_id": mock_user_id,
                "root_id": mock_root_id,
                "profile": {}
            }
        );
        user_manager.link_sso_account = unittest.mock.Mock(return_value={});
        mock_sso = MockGoogleSSO("id", "secret", "uri");
        mock_sso.verify_and_process = unittest.mock.AsyncMock(
            return_value=MockUserInfo(email="test@example.com")
        );
        with unittest.mock.patch.object(
            user_manager._identity_storage, "update_user_fields", return_value=True
        ) as mock_update {
            with unittest.mock.patch.object(
                user_manager, "get_sso", return_value=mock_sso
            ) {
                with unittest.mock.patch.object(
                    user_manager, "create_jwt_token", return_value="mock_jwt_token"
                ) {
                    result = asyncio.run(
                        user_manager.sso_callback(mock_request, Platforms.GOOGLE.value)
                    );
                    assert isinstance(result, (JSONResponse, TransportResponse));
                    body = _get_response_body(result);
                    assert "Login successful" in body;
                    assert "mock_jwt_token" in body;
                    # On every SSO login, profile.sso.<platform> is refreshed from
                    # the latest provider data
                    mock_update.assert_called_once();
                    (call_args, _call_kwargs) = mock_update.call_args;
                    assert call_args[0] == mock_user_id;
                    refreshed = call_args[1]['profile'];
                    assert 'google' in refreshed['sso'];
                    assert refreshed['sso']['google']['display_name'] == 'Test User';
                    assert refreshed['sso']['google']['picture'] == 'https://example.com/picture.jpg';
                }
            }
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test SSO callback for existing user with no provider data — no refresh attempted."""
test "sso callback existing user with no profile data" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        mock_user_id = str(uuid4());
        user_manager.find_user_by_identity = unittest.mock.Mock(
            return_value={
                "user_id": mock_user_id,
                "root_id": str(uuid4()),
                "profile": {}
            }
        );
        user_manager.link_sso_account = unittest.mock.Mock(return_value={});
        mock_sso = MockGoogleSSO("id", "secret", "uri");
        # Apple's later-login behavior: only email, no name/picture
        mock_sso.verify_and_process = unittest.mock.AsyncMock(
            return_value=MockUserInfo(
                email="test@example.com",
                display_name=None,
                first_name=None,
                last_name=None,
                picture=None
            )
        );
        with unittest.mock.patch.object(
            user_manager._identity_storage, "update_user_fields", return_value=True
        ) as mock_update {
            with unittest.mock.patch.object(
                user_manager, "get_sso", return_value=mock_sso
            ) {
                with unittest.mock.patch.object(
                    user_manager, "create_jwt_token", return_value="mock_jwt_token"
                ) {
                    result = asyncio.run(
                        user_manager.sso_callback(mock_request, Platforms.GOOGLE.value)
                    );
                    assert isinstance(result, (JSONResponse, TransportResponse));
                    # No SSO fields available — refresh skipped, login still works
                    mock_update.assert_not_called();
                }
            }
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test SSO callback for new user with no provider data — profile=None passed to create_user."""
test "sso callback new user with no profile data" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        mock_user_id = str(uuid4());
        user_manager.find_user_by_identity = unittest.mock.Mock(return_value=None);
        user_manager.create_user.return_value = {
            "user_id": mock_user_id,
            "message": "User registered successfully"
        };
        user_manager.link_sso_account = unittest.mock.Mock(return_value={});
        mock_sso = MockGoogleSSO("id", "secret", "uri");
        mock_sso.verify_and_process = unittest.mock.AsyncMock(
            return_value=MockUserInfo(
                email="newuser@example.com",
                display_name=None,
                first_name=None,
                last_name=None,
                picture=None
            )
        );
        with unittest.mock.patch.object(
            user_manager, "get_sso", return_value=mock_sso
        ) {
            with unittest.mock.patch.object(
                user_manager, "create_jwt_token", return_value="mock_jwt_token"
            ) {
                with unittest.mock.patch(
                    "jac_scale.user_manager.generate_random_password",
                    return_value="random_pass"
                ) {
                    asyncio.run(
                        user_manager.sso_callback(mock_request, Platforms.GOOGLE.value)
                    );
                    user_manager.create_user.assert_called_once_with(
                        identities=[{'type': 'email', 'value': 'newuser@example.com', 'verified': True}],
                        credential={'type': 'password', 'password': 'random_pass'},
                        profile=None
                    );
                }
            }
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test SSO callback auto-registers new user."""
test "sso callback auto register new user" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        mock_user_id = str(uuid4());
        user_manager.find_user_by_identity = unittest.mock.Mock(return_value=None);
        user_manager.create_user.return_value = {
            "user_id": mock_user_id,
            "message": "User registered successfully"
        };
        user_manager.link_sso_account = unittest.mock.Mock(return_value={});
        mock_sso = MockGoogleSSO("id", "secret", "uri");
        mock_sso.verify_and_process = unittest.mock.AsyncMock(
            return_value=MockUserInfo(email="newuser@example.com")
        );
        with unittest.mock.patch.object(
            user_manager, "get_sso", return_value=mock_sso
        ) {
            with unittest.mock.patch.object(
                user_manager, "create_jwt_token", return_value="mock_jwt_token"
            ) {
                with unittest.mock.patch(
                    "jac_scale.user_manager.generate_random_password",
                    return_value="random_pass"
                ) {
                    result = asyncio.run(
                        user_manager.sso_callback(mock_request, Platforms.GOOGLE.value)
                    );
                    assert isinstance(result, (JSONResponse, TransportResponse));
                    # MockUserInfo defaults populate all four optional fields,
                    # so the SSO profile sub-document is fully populated.
                    user_manager.create_user.assert_called_once_with(
                        identities=[{'type': 'email', 'value': 'newuser@example.com', 'verified': True}],
                        credential={'type': 'password', 'password': 'random_pass'},
                        profile={'sso': {'google': {
                            'display_name': 'Test User',
                            'first_name': 'Test',
                            'last_name': 'User',
                            'picture': 'https://example.com/picture.jpg'
                        }}}
                    );
                }
            }
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test SSO callback with invalid platform."""
test "sso callback with invalid platform" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        result = asyncio.run(
            user_manager.sso_callback(mock_request, "invalid_platform")
        );
        assert isinstance(result, (JSONResponse, TransportResponse));
        body = _get_response_body(result);
        assert "Invalid platform" in body;
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test SSO callback with unconfigured platform."""
test "sso callback with unconfigured platform" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        user_manager.SUPPORTED_PLATFORMS = {};
        result = asyncio.run(
            user_manager.sso_callback(mock_request, Platforms.GOOGLE.value)
        );
        assert isinstance(result, (JSONResponse, TransportResponse));
        body = _get_response_body(result);
        assert "not configured" in body;
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test SSO callback when get_sso returns None."""
test "sso callback when get sso fails" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        with unittest.mock.patch.object(user_manager, "get_sso", return_value=None) {
            result = asyncio.run(
                user_manager.sso_callback(mock_request, Platforms.GOOGLE.value)
            );
            assert isinstance(result, (JSONResponse, TransportResponse));
            body = _get_response_body(result);
            assert "Failed to initialize SSO" in body;
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test SSO callback when email is not provided by SSO provider."""
test "sso callback when email not provided" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        mock_sso = MockGoogleSSO("id", "secret", "uri");
        mock_user_info = MockUserInfo(email="");
        mock_user_info.email = None;
        mock_sso.verify_and_process = unittest.mock.AsyncMock(
            return_value=mock_user_info
        );
        with unittest.mock.patch.object(
            user_manager, "get_sso", return_value=mock_sso
        ) {
            result = asyncio.run(
                user_manager.sso_callback(mock_request, Platforms.GOOGLE.value)
            );
            assert isinstance(result, (JSONResponse, TransportResponse));
            body = _get_response_body(result);
            assert "Email not provided" in body;
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test SSO callback when authentication fails."""
test "sso callback authentication failure" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        mock_sso = MockGoogleSSO("id", "secret", "uri");
        mock_sso.verify_and_process = unittest.mock.AsyncMock(
            side_effect=Exception("Authentication failed")
        );
        with unittest.mock.patch.object(
            user_manager, "get_sso", return_value=mock_sso
        ) {
            result = asyncio.run(
                user_manager.sso_callback(mock_request, Platforms.GOOGLE.value)
            );
            assert isinstance(result, (JSONResponse, TransportResponse));
            body = _get_response_body(result);
            assert "Authentication failed" in body;
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test SUPPORTED_PLATFORMS initialization when credentials are in jac.toml."""
test "supported platforms initialization with jac toml credentials" {
    reset_scale_config();
    mock_config = MockScaleConfig(
        {
            "host": "http://localhost:8000",
            "google": {
                "client_id": "toml_test_id",
                "client_secret": "toml_test_secret"
            }
        }
    );
    with unittest.mock.patch(
        "jac_scale.user_manager.get_scale_config", return_value=mock_config
    ) {
        user_manager = JacScaleUserManager(base_path="");
        assert "google" in user_manager.SUPPORTED_PLATFORMS;
        assert user_manager.SUPPORTED_PLATFORMS["google"]["client_id"] == "toml_test_id";
    }
}

"""Test SUPPORTED_PLATFORMS initialization when credentials are missing."""
test "supported platforms initialization without jac toml credentials" {
    reset_scale_config();
    mock_config = MockScaleConfig(mock_sso_config_without_credentials());
    with unittest.mock.patch(
        "jac_scale.user_manager.get_scale_config", return_value=mock_config
    ) {
        user_manager = JacScaleUserManager(base_path="");
        assert "google" not in user_manager.SUPPORTED_PLATFORMS;
    }
}

# ============================================================================
# SSO Account Linking Tests
# ============================================================================
"""Setup user manager without mocked create_user/get_user for linking tests."""
def _setup_real_user_manager -> tuple[str, JacScaleUserManager] {
    test_dir = mkdtemp();
    reset_scale_config();
    mock_config = MockScaleConfig(mock_sso_config_with_credentials());
    with unittest.mock.patch(
        "jac_scale.user_manager.get_scale_config", return_value=mock_config
    ) {
        user_manager = JacScaleUserManager(base_path=test_dir);
    }
    return (test_dir, user_manager);
}

"""Test linking an SSO account successfully."""
test "link sso account success" {
    (test_dir, user_manager) = _setup_real_user_manager();
    try {
        user1 = user_manager.create_internal_user("user1", "pass1");
        user1_id = user1.get("user_id", "user1");

        result = user_manager.link_sso_account(user1_id, "google", "ext_123");
        assert result.get("message") == "SSO account linked successfully";

        accounts = user_manager.get_sso_accounts(user1_id);
        assert len(accounts) == 1;
        assert accounts[0]["platform"] == "google";
        assert accounts[0]["external_id"] == "ext_123";
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test preventing duplicate SSO account linking."""
test "link sso account duplicate" {
    (test_dir, user_manager) = _setup_real_user_manager();
    try {
        user1 = user_manager.create_internal_user("user1", "pass1");
        user1_id = user1.get("user_id", "user1");
        user2 = user_manager.create_internal_user("user2", "pass2");
        user2_id = user2.get("user_id", "user2");

        user_manager.link_sso_account(user1_id, "google", "ext_123");

        result = user_manager.link_sso_account(user2_id, "google", "ext_123");
        assert "already linked to another user" in result.get("error", "");

        result = user_manager.link_sso_account(user1_id, "google", "ext_123");
        assert "already linked to this user" in result.get("message", "");
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test unlinking an SSO account."""
test "unlink sso account" {
    (test_dir, user_manager) = _setup_real_user_manager();
    try {
        user1 = user_manager.create_internal_user("user1", "pass1");
        user1_id = user1.get("user_id", "user1");

        user_manager.link_sso_account(user1_id, "google", "ext_123");

        result = user_manager.unlink_sso_account(user1_id, "google");
        assert result.get("message") == "SSO account unlinked successfully";

        accounts = user_manager.get_sso_accounts(user1_id);
        assert len(accounts) == 0;
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test retrieving user by SSO credentials."""
test "get user by sso" {
    (test_dir, user_manager) = _setup_real_user_manager();
    try {
        user1 = user_manager.create_internal_user("user1", "pass1");
        user1_id = user1.get("user_id", "user1");

        user_manager.link_sso_account(user1_id, "google", "ext_123");

        user = user_manager.get_user_by_sso("google", "ext_123");
        assert user is not None;
        assert user["user_id"] == user1_id;

        user = user_manager.get_user_by_sso("google", "nonexistent");
        assert user is None;
    } finally {
        _teardown_user_manager(test_dir);
    }
}

# ============================================================================
# Endpoint Registration Tests
# ============================================================================
"""Test SSO endpoints registration."""
test "register sso endpoints" {
    mock_server_impl = unittest.mock.Mock();
    mock_user_manager = unittest.mock.Mock();
    mock_config = MockScaleConfig(mock_sso_config_with_credentials());
    with unittest.mock.patch(
        "jac_scale.serve.get_scale_config", return_value=mock_config
    ) {
        with unittest.mock.patch(
            "jaclang.jac0core.runtime.JacRuntimeInterface.get_user_manager",
            return_value=mock_user_manager
        ) {
            server = JacAPIServer(module_name="test_module", port=8000);
        }
    }
    server.server = mock_server_impl;
    mock_server_impl.reset_mock();
    server.register_sso_endpoints();
    # 3 endpoints: GET /sso/{platform}/{operation}, GET /sso/{platform}/callback, POST /sso/{platform}/callback
    assert mock_server_impl.add_endpoint.call_count == 3;
    calls = mock_server_impl.add_endpoint.call_args_list;
    initiate_endpoint = calls[0][0][0];
    assert "/sso/{platform}/{operation}" == initiate_endpoint.path;
    assert initiate_endpoint.method.name == "GET";
    get_callback_endpoint = calls[1][0][0];
    assert "/sso/{platform}/callback" == get_callback_endpoint.path;
    assert get_callback_endpoint.method.name == "GET";
    post_callback_endpoint = calls[2][0][0];
    assert "/sso/{platform}/callback" == post_callback_endpoint.path;
    assert post_callback_endpoint.method.name == "POST";
}

# ============================================================================
# Google SSO Provider Tests
# ============================================================================
"""Test Google initiate_auth delegates to inner SSO."""
test "google sso provider initiate auth" {
    with unittest.mock.patch("jac_scale.sso.google.GoogleSSO") as mock_cls {
        mock_inner_sso = unittest.mock.Mock();
        mock_cls.return_value = mock_inner_sso;
        provider = GoogleSSOProvider("id", "secret", "uri");
        assert provider._google_sso == mock_inner_sso;
        expected_response = unittest.mock.Mock();
        mock_inner_sso.get_login_redirect = unittest.mock.AsyncMock(
            return_value=expected_response
        );
        mock_inner_sso.__enter__ = unittest.mock.Mock(return_value=mock_inner_sso);
        mock_inner_sso.__exit__ = unittest.mock.Mock(return_value=None);
        response = asyncio.run(provider.initiate_auth());
        mock_inner_sso.get_login_redirect.assert_called_once();
        assert response == expected_response;
    }
}

"""Test Google handle_callback delegates and maps user info."""
test "google sso provider handle callback" {
    with unittest.mock.patch("jac_scale.sso.google.GoogleSSO") as mock_cls {
        mock_inner_sso = unittest.mock.Mock();
        mock_cls.return_value = mock_inner_sso;
        provider = GoogleSSOProvider("id", "secret", "uri");
        mock_request = unittest.mock.Mock(spec=Request);
        mock_user = unittest.mock.Mock();
        mock_user.email = "test@example.com";
        mock_user.id = "12345";
        mock_user.display_name = "Test User";
        mock_inner_sso.verify_and_process = unittest.mock.AsyncMock(
            return_value=mock_user
        );
        mock_inner_sso.__enter__ = unittest.mock.Mock(return_value=mock_inner_sso);
        mock_inner_sso.__exit__ = unittest.mock.Mock(return_value=None);
        result = asyncio.run(provider.handle_callback(mock_request));
        mock_inner_sso.verify_and_process.assert_called_once_with(mock_request);
        assert result.email == "test@example.com";
        assert result.external_id == "12345";
        assert result.display_name == "Test User";
    }
}

# ============================================================================
# Apple SSO Provider Tests
# ============================================================================
"""Test get_sso returns AppleSSOProvider instance for Apple platform."""
test "get sso with apple platform" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        with unittest.mock.patch(
            "jac_scale.sso.apple.AppleSSOProvider", side_effect=MockAppleSSO
        ) as mock_sso {
            sso = user_manager.get_sso(Platforms.APPLE.value);
            assert sso is not None;
            assert sso.client_id == "apple_test_client_id";
            assert sso.client_secret == "apple_test_client_secret";
            mock_sso.assert_called_once();
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test get_sso creates correct redirect URI for Apple platform."""
test "get sso apple redirect uri format" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        with unittest.mock.patch(
            "jac_scale.sso.apple.AppleSSOProvider", side_effect=MockAppleSSO
        ) {
            sso = user_manager.get_sso(Platforms.APPLE.value);
            assert sso.redirect_uri == "http://localhost:8000/sso/apple/callback";
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test successful Apple SSO initiation."""
test "apple sso initiate success" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        with unittest.mock.patch.object(
            user_manager, "get_sso", return_value=MockAppleSSO("id", "secret", "uri")
        ) {
            result = asyncio.run(
                user_manager.sso_initiate(
                    Platforms.APPLE.value, Operations.LOGIN.value
                )
            );
            assert isinstance(result, RedirectResponse);
            assert "apple.com" in result.headers.get("location", "");
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test Apple SSO callback logs in existing user."""
test "apple sso callback login existing user" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        mock_user_id = str(uuid4());
        user_manager.find_user_by_identity = unittest.mock.Mock(
            return_value={
                "user_id": mock_user_id,
                "root_id": str(uuid4()),
                "profile": {}
            }
        );
        user_manager.link_sso_account = unittest.mock.Mock(return_value={});
        mock_sso = MockAppleSSO("id", "secret", "uri");
        mock_sso.verify_and_process = unittest.mock.AsyncMock(
            return_value=MockUserInfo(email="test@privaterelay.appleid.com")
        );
        with unittest.mock.patch.object(
            user_manager._identity_storage, "update_user_fields", return_value=True
        ) {
            with unittest.mock.patch.object(
                user_manager, "get_sso", return_value=mock_sso
            ) {
                with unittest.mock.patch.object(
                    user_manager, "create_jwt_token", return_value="mock_apple_jwt"
                ) {
                    result = asyncio.run(
                        user_manager.sso_callback(mock_request, Platforms.APPLE.value)
                    );
                    assert isinstance(result, (JSONResponse, TransportResponse));
                    body = _get_response_body(result);
                    assert "Login successful" in body;
                    assert "mock_apple_jwt" in body;
                }
            }
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test Apple SSO callback auto-registers new user."""
test "apple sso callback auto register new user" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        mock_user_id = str(uuid4());
        user_manager.find_user_by_identity = unittest.mock.Mock(return_value=None);
        user_manager.create_user.return_value = {
            "user_id": mock_user_id,
            "message": "User registered successfully"
        };
        user_manager.link_sso_account = unittest.mock.Mock(return_value={});
        mock_sso = MockAppleSSO("id", "secret", "uri");
        mock_sso.verify_and_process = unittest.mock.AsyncMock(
            return_value=MockUserInfo(email="newuser@privaterelay.appleid.com")
        );
        with unittest.mock.patch.object(
            user_manager, "get_sso", return_value=mock_sso
        ) {
            with unittest.mock.patch.object(
                user_manager, "create_jwt_token", return_value="mock_apple_jwt"
            ) {
                with unittest.mock.patch(
                    "jac_scale.user_manager.generate_random_password",
                    return_value="random_pass"
                ) {
                    result = asyncio.run(
                        user_manager.sso_callback(mock_request, Platforms.APPLE.value)
                    );
                    assert isinstance(result, (JSONResponse, TransportResponse));
                    user_manager.create_user.assert_called_once_with(
                        identities=[{'type': 'email', 'value': 'newuser@privaterelay.appleid.com', 'verified': True}],
                        credential={'type': 'password', 'password': 'random_pass'},
                        profile={'sso': {'apple': {
                            'display_name': 'Test User',
                            'first_name': 'Test',
                            'last_name': 'User',
                            'picture': 'https://example.com/picture.jpg'
                        }}}
                    );
                }
            }
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test Apple initiate_auth delegates to inner SSO."""
test "apple sso provider initiate auth" {
    with unittest.mock.patch("jac_scale.sso.apple.AppleSSO") as mock_cls {
        mock_inner_sso = unittest.mock.Mock();
        mock_cls.return_value = mock_inner_sso;
        provider = AppleSSOProvider("id", "secret", "uri");
        assert provider._apple_sso == mock_inner_sso;
        expected_response = unittest.mock.Mock();
        mock_inner_sso.get_login_redirect = unittest.mock.AsyncMock(
            return_value=expected_response
        );
        mock_inner_sso.__enter__ = unittest.mock.Mock(return_value=mock_inner_sso);
        mock_inner_sso.__exit__ = unittest.mock.Mock(return_value=None);
        response = asyncio.run(provider.initiate_auth());
        mock_inner_sso.get_login_redirect.assert_called_once();
        assert response == expected_response;
    }
}

"""Test Apple handle_callback delegates and maps user info."""
test "apple sso provider handle callback" {
    with unittest.mock.patch("jac_scale.sso.apple.AppleSSO") as mock_cls {
        mock_inner_sso = unittest.mock.Mock();
        mock_cls.return_value = mock_inner_sso;
        provider = AppleSSOProvider("id", "secret", "uri");
        mock_request = unittest.mock.Mock(spec=Request);
        mock_user = unittest.mock.Mock();
        mock_user.email = "test@privaterelay.appleid.com";
        mock_user.id = "apple_12345";
        mock_user.display_name = "Apple User";
        mock_inner_sso.verify_and_process = unittest.mock.AsyncMock(
            return_value=mock_user
        );
        mock_inner_sso.__enter__ = unittest.mock.Mock(return_value=mock_inner_sso);
        mock_inner_sso.__exit__ = unittest.mock.Mock(return_value=None);
        result = asyncio.run(provider.handle_callback(mock_request));
        mock_inner_sso.verify_and_process.assert_called_once_with(mock_request);
        assert result.email == "test@privaterelay.appleid.com";
        assert result.external_id == "apple_12345";
        assert result.display_name == "Apple User";
    }
}

"""Test SUPPORTED_PLATFORMS includes Apple when credentials are configured."""
test "supported platforms initialization with apple credentials" {
    reset_scale_config();
    mock_config = MockScaleConfig(
        {
            "host": "http://localhost:8000",
            "google": {"client_id": "google_id", "client_secret": "google_secret"},
            "apple": {"client_id": "apple_id", "client_secret": "apple_secret"}
        }
    );
    with unittest.mock.patch(
        "jac_scale.user_manager.get_scale_config", return_value=mock_config
    ) {
        user_manager = JacScaleUserManager(base_path="");
        assert "google" in user_manager.SUPPORTED_PLATFORMS;
        assert "apple" in user_manager.SUPPORTED_PLATFORMS;
        assert user_manager.SUPPORTED_PLATFORMS["apple"]["client_id"] == "apple_id";
    }
}

"""Test SUPPORTED_PLATFORMS excludes Apple when credentials are missing."""
test "supported platforms initialization without apple credentials" {
    reset_scale_config();
    mock_config = MockScaleConfig(
        {
            "host": "http://localhost:8000",
            "google": {"client_id": "google_id", "client_secret": "google_secret"},
            "apple": {"client_id": "", "client_secret": ""}
        }
    );
    with unittest.mock.patch(
        "jac_scale.user_manager.get_scale_config", return_value=mock_config
    ) {
        user_manager = JacScaleUserManager(base_path="");
        assert "google" in user_manager.SUPPORTED_PLATFORMS;
        assert "apple" not in user_manager.SUPPORTED_PLATFORMS;
    }
}

# ============================================================================
# GitHub SSO Provider Tests
# ============================================================================
"""Test get_sso returns GithubSSOProvider instance for GitHub platform."""
test "get sso with github platform" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        with unittest.mock.patch(
            "jac_scale.sso.github.GithubSSOProvider", side_effect=MockGithubSSO
        ) as mock_sso {
            sso = user_manager.get_sso(Platforms.GITHUB.value);
            assert sso is not None;
            assert sso.client_id == "github_test_client_id";
            assert sso.client_secret == "github_test_client_secret";
            mock_sso.assert_called_once();
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test get_sso creates correct redirect URI for GitHub platform."""
test "get sso github redirect uri format" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        with unittest.mock.patch(
            "jac_scale.sso.github.GithubSSOProvider", side_effect=MockGithubSSO
        ) {
            sso = user_manager.get_sso(Platforms.GITHUB.value);
            assert sso.redirect_uri == "http://localhost:8000/sso/github/callback";
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test successful GitHub SSO initiation."""
test "github sso initiate success" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        with unittest.mock.patch.object(
            user_manager, "get_sso", return_value=MockGithubSSO("id", "secret", "uri")
        ) {
            result = asyncio.run(
                user_manager.sso_initiate(
                    Platforms.GITHUB.value, Operations.LOGIN.value
                )
            );
            assert isinstance(result, RedirectResponse);
            assert "github.com" in result.headers.get("location", "");
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test GitHub SSO callback logs in existing user."""
test "github sso callback login existing user" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        mock_user_id = str(uuid4());
        user_manager.find_user_by_identity = unittest.mock.Mock(
            return_value={
                "user_id": mock_user_id,
                "root_id": str(uuid4()),
                "profile": {}
            }
        );
        user_manager.link_sso_account = unittest.mock.Mock(return_value={});
        mock_sso = MockGithubSSO("id", "secret", "uri");
        mock_sso.verify_and_process = unittest.mock.AsyncMock(
            return_value=MockUserInfo(email="test@github.com")
        );
        with unittest.mock.patch.object(
            user_manager._identity_storage, "update_user_fields", return_value=True
        ) {
            with unittest.mock.patch.object(
                user_manager, "get_sso", return_value=mock_sso
            ) {
                with unittest.mock.patch.object(
                    user_manager, "create_jwt_token", return_value="mock_github_jwt"
                ) {
                    result = asyncio.run(
                        user_manager.sso_callback(mock_request, Platforms.GITHUB.value)
                    );
                    assert isinstance(result, (JSONResponse, TransportResponse));
                    body = _get_response_body(result);
                    assert "Login successful" in body;
                    assert "mock_github_jwt" in body;
                }
            }
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test GitHub SSO callback auto-registers new user."""
test "github sso callback auto register new user" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        mock_user_id = str(uuid4());
        user_manager.find_user_by_identity = unittest.mock.Mock(return_value=None);
        user_manager.create_user.return_value = {
            "user_id": mock_user_id,
            "message": "User registered successfully"
        };
        user_manager.link_sso_account = unittest.mock.Mock(return_value={});
        mock_sso = MockGithubSSO("id", "secret", "uri");
        mock_sso.verify_and_process = unittest.mock.AsyncMock(
            return_value=MockUserInfo(email="newuser@github.com")
        );
        with unittest.mock.patch.object(
            user_manager, "get_sso", return_value=mock_sso
        ) {
            with unittest.mock.patch.object(
                user_manager, "create_jwt_token", return_value="mock_github_jwt"
            ) {
                with unittest.mock.patch(
                    "jac_scale.user_manager.generate_random_password",
                    return_value="random_pass"
                ) {
                    result = asyncio.run(
                        user_manager.sso_callback(mock_request, Platforms.GITHUB.value)
                    );
                    assert isinstance(result, (JSONResponse, TransportResponse));
                    user_manager.create_user.assert_called_once_with(
                        identities=[{'type': 'email', 'value': 'newuser@github.com', 'verified': True}],
                        credential={'type': 'password', 'password': 'random_pass'},
                        profile={'sso': {'github': {
                            'display_name': 'Test User',
                            'first_name': 'Test',
                            'last_name': 'User',
                            'picture': 'https://example.com/picture.jpg'
                        }}}
                    );
                }
            }
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test GitHub initiate_auth delegates to inner SSO."""
test "github sso provider initiate auth" {
    with unittest.mock.patch("jac_scale.sso.github.GithubSSO") as mock_cls {
        mock_inner_sso = unittest.mock.Mock();
        mock_cls.return_value = mock_inner_sso;
        provider = GithubSSOProvider("id", "secret", "uri");
        assert provider._github_sso == mock_inner_sso;
        expected_response = unittest.mock.Mock();
        mock_inner_sso.get_login_redirect = unittest.mock.AsyncMock(
            return_value=expected_response
        );
        mock_inner_sso.__enter__ = unittest.mock.Mock(return_value=mock_inner_sso);
        mock_inner_sso.__exit__ = unittest.mock.Mock(return_value=None);
        response = asyncio.run(provider.initiate_auth());
        mock_inner_sso.get_login_redirect.assert_called_once();
        assert response == expected_response;
    }
}

"""Test GitHub handle_callback delegates and maps user info."""
test "github sso provider handle callback" {
    with unittest.mock.patch("jac_scale.sso.github.GithubSSO") as mock_cls {
        mock_inner_sso = unittest.mock.Mock();
        mock_cls.return_value = mock_inner_sso;
        provider = GithubSSOProvider("id", "secret", "uri");
        mock_request = unittest.mock.Mock(spec=Request);
        mock_user = unittest.mock.Mock();
        mock_user.email = "test@github.com";
        mock_user.id = "github_12345";
        mock_user.display_name = "GitHub User";
        mock_inner_sso.verify_and_process = unittest.mock.AsyncMock(
            return_value=mock_user
        );
        mock_inner_sso.__enter__ = unittest.mock.Mock(return_value=mock_inner_sso);
        mock_inner_sso.__exit__ = unittest.mock.Mock(return_value=None);
        result = asyncio.run(provider.handle_callback(mock_request));
        mock_inner_sso.verify_and_process.assert_called_once_with(mock_request);
        assert result.email == "test@github.com";
        assert result.external_id == "github_12345";
        assert result.display_name == "GitHub User";
    }
}

"""Test SUPPORTED_PLATFORMS includes GitHub when credentials are configured."""
test "supported platforms initialization with github credentials" {
    reset_scale_config();
    mock_config = MockScaleConfig(
        {
            "host": "http://localhost:8000",
            "github": {"client_id": "github_id", "client_secret": "github_secret"}
        }
    );
    with unittest.mock.patch(
        "jac_scale.user_manager.get_scale_config", return_value=mock_config
    ) {
        user_manager = JacScaleUserManager(base_path="");
        assert "github" in user_manager.SUPPORTED_PLATFORMS;
        assert user_manager.SUPPORTED_PLATFORMS["github"]["client_id"] == "github_id";
    }
}

"""Test SUPPORTED_PLATFORMS excludes GitHub when credentials are missing."""
test "supported platforms initialization without github credentials" {
    reset_scale_config();
    mock_config = MockScaleConfig(
        {
            "host": "http://localhost:8000",
            "google": {"client_id": "google_id", "client_secret": "google_secret"},
            "github": {"client_id": "", "client_secret": ""}
        }
    );
    with unittest.mock.patch(
        "jac_scale.user_manager.get_scale_config", return_value=mock_config
    ) {
        user_manager = JacScaleUserManager(base_path="");
        assert "google" in user_manager.SUPPORTED_PLATFORMS;
        assert "github" not in user_manager.SUPPORTED_PLATFORMS;
    }
}

"""Test all three platforms configured together."""
test "supported platforms initialization with all providers" {
    reset_scale_config();
    mock_config = MockScaleConfig(mock_sso_config_with_credentials());
    with unittest.mock.patch(
        "jac_scale.user_manager.get_scale_config", return_value=mock_config
    ) {
        user_manager = JacScaleUserManager(base_path="");
        assert "google" in user_manager.SUPPORTED_PLATFORMS;
        assert "apple" in user_manager.SUPPORTED_PLATFORMS;
        assert "github" in user_manager.SUPPORTED_PLATFORMS;
    }
}
