"""Test for SSO (Single Sign-On) implementation in jac-scale."""

import json;
import os;
import shutil;
import asyncio;
import from tempfile { mkdtemp }
import from dataclasses { dataclass }
import from types { TracebackType }
import unittest.mock;
import from uuid { uuid4 }

import pytest;
import from fastapi { Request }
import from fastapi.responses { JSONResponse, RedirectResponse }

import from jac_scale.config_loader { reset_scale_config }
import from jac_scale.google_sso_provider { GoogleSSOProvider }
import from jac_scale.serve { JacAPIServer, Operations, Platforms }
import from jac_scale.user_manager { JacScaleUserManager }
import from jaclang.runtimelib.transport { TransportResponse }

"""Return mock SSO config with Google credentials configured."""
def mock_sso_config_with_credentials -> dict {
    return {
        "host": "http://localhost:8000/sso",
        "google": {
            "client_id": "test_client_id",
            "client_secret": "test_client_secret"
        }
    };
}

"""Return mock SSO config without credentials."""
def mock_sso_config_without_credentials -> dict {
    return {
        "host": "http://localhost:8000/sso",
        "google": {"client_id": "", "client_secret": ""}
    };
}

"""Return mock SSO config with only client_id (no secret)."""
def mock_sso_config_partial_credentials -> dict {
    return {
        "host": "http://localhost:8000/sso",
        "google": {"client_id": "test_id", "client_secret": ""}
    };
}

"""Mock user info from SSO provider."""
@dataclass
obj MockUserInfo {
    has email: str,
        id: str = "mock_sso_id",
        first_name: str = "Test",
        last_name: str = "User",
        display_name: str = "Test User",
        picture: str = "https://example.com/picture.jpg";
}

"""Mock GoogleSSO for testing - implements SSOProvider interface."""
class MockGoogleSSO {
    has client_id: str,
        client_secret: str,
        redirect_uri: str,
        allow_insecure_http: bool = False;

    def init(
        self,
        client_id: str,
        client_secret: str,
        redirect_uri: str,
        allow_insecure_http: bool = False
    ) -> None {
        self.client_id = client_id;
        self.client_secret = client_secret;
        self.redirect_uri = redirect_uri;
        self.allow_insecure_http = allow_insecure_http;
        self.get_login_redirect = self._default_get_login_redirect;
        self.verify_and_process = self._default_verify_and_process;
        self.initiate_auth = self._default_initiate_auth;
        self.handle_callback = self._default_handle_callback;
    }

    """Mock get_login_redirect method."""
    async def _default_get_login_redirect(self) -> RedirectResponse {
        return RedirectResponse(url="https://accounts.google.com/oauth/authorize");
    }

    """Mock verify_and_process method."""
    async def _default_verify_and_process(self, _request: Request) -> MockUserInfo {
        return MockUserInfo(email="test@example.com");
    }

    """Mock initiate_auth method (SSOProvider interface)."""
    async def _default_initiate_auth(self, operation: str) -> RedirectResponse {
        return RedirectResponse(url="https://accounts.google.com/oauth/authorize");
    }

    """Mock handle_callback method (SSOProvider interface)."""
    async def _default_handle_callback(self, request: Request) -> MockUserInfo {
        return await self.verify_and_process(request);
    }

    """Mock get_platform_name method (SSOProvider interface)."""
    def get_platform_name(self) -> str {
        return "google";
    }

    def __enter__(self) -> "MockGoogleSSO" {
        return self;
    }

    def __exit__(
        self,
        _exc_type: type | None,
        _exc_val: BaseException | None,
        _exc_tb: TracebackType | None
    ) -> None {
        0;
    }
}

"""Mock JacScaleConfig for testing."""
class MockScaleConfig {
    has _sso_config: dict;

    def init(self, sso_config: dict | None = None) -> None {
        self._sso_config = sso_config or mock_sso_config_with_credentials();
    }

    def get_sso_config(self) -> dict {
        return self._sso_config;
    }

    def get_jwt_config(self) -> dict {
        return {"secret": "test_secret", "algorithm": "HS256", "exp_delta_days": 1};
    }

    def get_kubernetes_config(self) -> dict {
        return {"namespace": "default"};
    }

    def get_metrics_config(self) -> dict {
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
        raise TypeError(f"Unexpected response type: {type(result)}") ;
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

# TestJacScaleUserManagerSSO
"""Test get_sso returns GoogleSSO instance for Google platform."""
test "get sso with google platform" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        with unittest.mock.patch(
            "jac_scale.google_sso_provider.GoogleSSOProvider",
            side_effect=MockGoogleSSO
        ) as mock_sso {
            sso = user_manager.get_sso(Platforms.GOOGLE.value, Operations.LOGIN.value);
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
        sso = user_manager.get_sso("invalid_platform", Operations.LOGIN.value);
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
            sso = um.get_sso(Platforms.GOOGLE.value, Operations.LOGIN.value);
            assert sso is None;
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test get_sso creates correct redirect URI based on jac.toml SSO host."""
test "get sso redirect uri format" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        with unittest.mock.patch(
            "jac_scale.google_sso_provider.GoogleSSOProvider",
            side_effect=MockGoogleSSO
        ) {
            sso = user_manager.get_sso(Platforms.GOOGLE.value, Operations.LOGIN.value);
            assert sso.redirect_uri == "http://localhost:8000/sso/google/login/callback";
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

"""Test successful SSO callback for login."""
test "sso callback login success" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        user_manager.get_user.return_value = {
            "email": "test@example.com",
            "root_id": str(uuid4())
        };
        mock_sso = MockGoogleSSO("id", "secret", "uri");
        mock_sso.verify_and_process = unittest.mock.AsyncMock(
            return_value=MockUserInfo(email="test@example.com")
        );
        with unittest.mock.patch.object(user_manager, "get_sso", return_value=mock_sso) {
            with unittest.mock.patch.object(
                user_manager, "create_jwt_token", return_value="mock_jwt_token"
            ) {
                result = asyncio.run(
                    user_manager.sso_callback(
                        mock_request, Platforms.GOOGLE.value, Operations.LOGIN.value
                    )
                );
                assert isinstance(result, (JSONResponse, TransportResponse));
                body = _get_response_body(result);
                assert "Login successful" in body;
                assert "test@example.com" in body;
                assert "mock_jwt_token" in body;
            }
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test successful SSO callback for registration."""
test "sso callback register success" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        user_manager.get_user.return_value = None;
        user_manager.create_user.return_value = {
            "email": "newuser@example.com",
            "root_id": str(uuid4())
        };
        mock_sso = MockGoogleSSO("id", "secret", "uri");
        mock_sso.verify_and_process = unittest.mock.AsyncMock(
            return_value=MockUserInfo(email="newuser@example.com")
        );
        with unittest.mock.patch.object(user_manager, "get_sso", return_value=mock_sso) {
            with unittest.mock.patch.object(
                user_manager, "create_jwt_token", return_value="mock_jwt_token"
            ) {
                with unittest.mock.patch(
                    "jac_scale.user_manager.generate_random_password",
                    return_value="random_pass"
                ) {
                    result = asyncio.run(
                        user_manager.sso_callback(
                            mock_request,
                            Platforms.GOOGLE.value,
                            Operations.REGISTER.value
                        )
                    );
                    assert isinstance(result, (JSONResponse, TransportResponse));
                    user_manager.create_user.assert_called_once_with(
                        "newuser@example.com", "random_pass"
                    );
                }
            }
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test SSO callback for login when user doesn't exist."""
test "sso callback login user not found" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        user_manager.get_user.return_value = None;
        mock_sso = MockGoogleSSO("id", "secret", "uri");
        mock_sso.verify_and_process = unittest.mock.AsyncMock(
            return_value=MockUserInfo(email="nonexistent@example.com")
        );
        with unittest.mock.patch.object(user_manager, "get_sso", return_value=mock_sso) {
            result = asyncio.run(
                user_manager.sso_callback(
                    mock_request, Platforms.GOOGLE.value, Operations.LOGIN.value
                )
            );
            assert isinstance(result, (JSONResponse, TransportResponse));
            body = _get_response_body(result);
            assert "User not found" in body;
        }
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test SSO callback for registration when user already exists."""
test "sso callback register user already exists" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        user_manager.get_user.return_value = {
            "email": "existing@example.com",
            "root_id": str(uuid4())
        };
        mock_sso = MockGoogleSSO("id", "secret", "uri");
        mock_sso.verify_and_process = unittest.mock.AsyncMock(
            return_value=MockUserInfo(email="existing@example.com")
        );
        with unittest.mock.patch.object(user_manager, "get_sso", return_value=mock_sso) {
            result = asyncio.run(
                user_manager.sso_callback(
                    mock_request, Platforms.GOOGLE.value, Operations.REGISTER.value
                )
            );
            assert isinstance(result, (JSONResponse, TransportResponse));
            body = _get_response_body(result);
            assert "User already exists" in body;
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
            user_manager.sso_callback(
                mock_request, "invalid_platform", Operations.LOGIN.value
            )
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
            user_manager.sso_callback(
                mock_request, Platforms.GOOGLE.value, Operations.LOGIN.value
            )
        );
        assert isinstance(result, (JSONResponse, TransportResponse));
        body = _get_response_body(result);
        assert "not configured" in body;
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test SSO callback with invalid operation."""
test "sso callback with invalid operation" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        mock_request = unittest.mock.Mock(spec=Request);
        result = asyncio.run(
            user_manager.sso_callback(
                mock_request, Platforms.GOOGLE.value, "invalid_operation"
            )
        );
        assert isinstance(result, (JSONResponse, TransportResponse));
        body = _get_response_body(result);
        assert "Invalid operation" in body;
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
                user_manager.sso_callback(
                    mock_request, Platforms.GOOGLE.value, Operations.LOGIN.value
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
        with unittest.mock.patch.object(user_manager, "get_sso", return_value=mock_sso) {
            result = asyncio.run(
                user_manager.sso_callback(
                    mock_request, Platforms.GOOGLE.value, Operations.LOGIN.value
                )
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
        with unittest.mock.patch.object(user_manager, "get_sso", return_value=mock_sso) {
            result = asyncio.run(
                user_manager.sso_callback(
                    mock_request, Platforms.GOOGLE.value, Operations.LOGIN.value
                )
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
            "host": "http://localhost:8000/sso",
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

"""Test linking an SSO account successfully."""
test "link sso account success" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        user_manager._ensure_connection();
        user_manager._conn.execute(
            "INSERT INTO users (username, password_hash, token, root_id) VALUES (?, ?, ?, ?)",
            ("user1", "hash", "token", "root")
        );
        user_manager._conn.commit();

        result = user_manager.link_sso_account(
            "user1", "google", "ext_123", "test@google.com"
        );
        assert result.get("message") == "SSO account linked successfully";
        assert result.get("user_id") == "user1";

        accounts = user_manager.get_sso_accounts("user1");
        assert len(accounts) == 1;
        assert accounts[0]["platform"] == "google";
        assert accounts[0]["external_id"] == "ext_123";
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test preventing duplicate SSO account linking."""
test "link sso account duplicate" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        user_manager._ensure_connection();
        user_manager._conn.execute(
            "INSERT INTO users (username, password_hash, token, root_id) VALUES (?, ?, ?, ?)",
            ("user1", "hash", "token", "root")
        );
        user_manager._conn.execute(
            "INSERT INTO users (username, password_hash, token, root_id) VALUES (?, ?, ?, ?)",
            ("user2", "hash", "token2", "root2")
        );
        user_manager._conn.commit();

        user_manager.link_sso_account("user1", "google", "ext_123", "test@google.com");

        result = user_manager.link_sso_account(
            "user2", "google", "ext_123", "test@google.com"
        );
        assert "already linked to another user" in result.get("error", "");

        result = user_manager.link_sso_account(
            "user1", "google", "ext_123", "test@google.com"
        );
        assert "already linked to this user" in result.get("message", "");
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test unlinking an SSO account."""
test "unlink sso account" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        user_manager._ensure_connection();
        user_manager._conn.execute(
            "INSERT INTO users (username, password_hash, token, root_id) VALUES (?, ?, ?, ?)",
            ("user1", "hash", "token", "root")
        );
        user_manager._conn.commit();

        user_manager.link_sso_account("user1", "google", "ext_123", "test@google.com");

        result = user_manager.unlink_sso_account("user1", "google");
        assert result.get("message") == "SSO account unlinked successfully";

        accounts = user_manager.get_sso_accounts("user1");
        assert len(accounts) == 0;
    } finally {
        _teardown_user_manager(test_dir);
    }
}

"""Test retrieving user by SSO credentials."""
test "get user by sso" {
    (test_dir, user_manager) = _setup_user_manager();
    try {
        user_manager._ensure_connection();
        user_manager._conn.execute(
            "INSERT INTO users (username, password_hash, token, root_id) VALUES (?, ?, ?, ?)",
            ("user1", "hash", "token_val", "root_val")
        );
        user_manager._conn.commit();

        user_manager.link_sso_account("user1", "google", "ext_123", "test@google.com");

        user = user_manager.get_user_by_sso("google", "ext_123");
        assert user is not None;
        assert user["email"] == "user1";
        assert user["token"] == "token_val";
        assert user["root_id"] == "root_val";

        user = user_manager.get_user_by_sso("google", "nonexistent");
        assert user is None;
    } finally {
        _teardown_user_manager(test_dir);
    }
}

# TestJacAPIServerEndpoints
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
    assert mock_server_impl.add_endpoint.call_count == 2;
    calls = mock_server_impl.add_endpoint.call_args_list;
    first_endpoint = calls[0][0][0];
    assert "/sso/{platform}/{operation}" in first_endpoint.path;
    assert first_endpoint.method.name == "GET";
}

# TestGoogleSSOProvider
"""Test initiate_auth delegates to inner SSO."""
test "google sso provider initiate auth" {
    with unittest.mock.patch("jac_scale.google_sso_provider.GoogleSSO") as mock_cls {
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
        response = asyncio.run(provider.initiate_auth("login"));
        mock_inner_sso.get_login_redirect.assert_called_once();
        assert response == expected_response;
    }
}

"""Test handle_callback delegates and maps user info."""
test "google sso provider handle callback" {
    with unittest.mock.patch("jac_scale.google_sso_provider.GoogleSSO") as mock_cls {
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
        assert result.platform == "google";
        assert result.display_name == "Test User";
    }
}

"""Test get_platform_name returns google."""
test "google sso provider get platform name" {
    with unittest.mock.patch("jac_scale.google_sso_provider.GoogleSSO") as mock_cls {
        mock_inner_sso = unittest.mock.Mock();
        mock_cls.return_value = mock_inner_sso;
        provider = GoogleSSOProvider("id", "secret", "uri");
        assert provider.get_platform_name() == "google";
    }
}
