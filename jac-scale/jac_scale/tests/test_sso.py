"""Test for SSO (Single Sign-On) implementation in jac-scale."""

import contextlib
import json
from dataclasses import dataclass
from types import TracebackType
from unittest.mock import AsyncMock, Mock, patch
from uuid import uuid4

import pytest
from fastapi import Request
from fastapi.responses import JSONResponse, RedirectResponse

from jac_scale.config_loader import reset_scale_config
from jac_scale.serve import JacAPIServer, Operations, Platforms
from jaclang.runtimelib.transport import TransportResponse


def mock_sso_config_with_credentials() -> dict:
    """Return mock SSO config with Google credentials configured."""
    return {
        "host": "http://localhost:8000/sso",
        "google": {
            "client_id": "test_client_id",
            "client_secret": "test_client_secret",
        },
    }


def mock_sso_config_without_credentials() -> dict:
    """Return mock SSO config without credentials."""
    return {
        "host": "http://localhost:8000/sso",
        "google": {
            "client_id": "",
            "client_secret": "",
        },
    }


def mock_sso_config_partial_credentials() -> dict:
    """Return mock SSO config with only client_id (no secret)."""
    return {
        "host": "http://localhost:8000/sso",
        "google": {
            "client_id": "test_id",
            "client_secret": "",
        },
    }


@dataclass
class MockUserInfo:
    """Mock user info from SSO provider."""

    email: str
    id: str = "mock_sso_id"
    first_name: str = "Test"
    last_name: str = "User"
    display_name: str = "Test User"
    picture: str = "https://example.com/picture.jpg"


class MockGoogleSSO:
    """Mock GoogleSSO for testing."""

    def __init__(
        self,
        client_id: str,
        client_secret: str,
        redirect_uri: str,
        allow_insecure_http: bool = False,
    ):
        self.client_id = client_id
        self.client_secret = client_secret
        self.redirect_uri = redirect_uri
        self.allow_insecure_http = allow_insecure_http
        # Set default callables that can be overridden
        self.get_login_redirect = self._default_get_login_redirect
        self.verify_and_process = self._default_verify_and_process

    async def _default_get_login_redirect(self) -> RedirectResponse:
        """Mock get_login_redirect method."""
        return RedirectResponse(url="https://accounts.google.com/oauth/authorize")

    async def _default_verify_and_process(self, _request: Request) -> MockUserInfo:
        """Mock verify_and_process method."""
        return MockUserInfo(email="test@example.com")

    def __enter__(self) -> "MockGoogleSSO":
        return self

    def __exit__(
        self,
        _exc_type: type[BaseException] | None,
        _exc_val: BaseException | None,
        _exc_tb: TracebackType | None,
    ) -> None:
        pass


class MockScaleConfig:
    """Mock JacScaleConfig for testing."""

    def __init__(self, sso_config: dict | None = None):
        self._sso_config = sso_config or mock_sso_config_with_credentials()

    def get_sso_config(self) -> dict:
        return self._sso_config


class TestJacAPIServerSSO:
    """Test SSO functionality in JacAPIServer."""

    def setup_method(self) -> None:
        """Setup for each test method."""
        # Reset config singleton to ensure fresh config
        reset_scale_config()

        # Mock the server components
        self.mock_server_impl = Mock()
        self.mock_user_manager = Mock()
        self.mock_introspector = Mock()
        self.mock_execution_manager = Mock()

        # Create JacAPIServer instance with mocked config (jac.toml approach)
        mock_config = MockScaleConfig(mock_sso_config_with_credentials())
        with patch("jac_scale.serve.get_scale_config", return_value=mock_config):
            self.server = JacAPIServer(
                module_name="test_module",
                port=8000,
            )

        # Replace server components with mocks
        self.server.server = self.mock_server_impl
        self.server.user_manager = self.mock_user_manager
        self.server.introspector = self.mock_introspector
        self.server.execution_manager = self.mock_execution_manager

    def teardown_method(self) -> None:
        """Teardown after each test."""
        with contextlib.suppress(BaseException):
            del self.server

    @staticmethod
    def _get_response_body(result: JSONResponse | TransportResponse) -> str:
        """Extract body content from JSONResponse or TransportResponse."""
        if isinstance(result, JSONResponse):
            return result.body.decode("utf-8")
        elif isinstance(result, TransportResponse):
            # Convert TransportResponse to JSON string
            response_dict = {
                "ok": result.ok,
                "type": result.type,
                "data": result.data,
                "error": None,
            }
            if not result.ok and result.error:
                response_dict["error"] = {
                    "code": result.error.code,
                    "message": result.error.message,
                    "details": result.error.details,
                }
            if result.meta:
                meta_dict = {}
                if result.meta.request_id:
                    meta_dict["request_id"] = result.meta.request_id
                if result.meta.trace_id:
                    meta_dict["trace_id"] = result.meta.trace_id
                if result.meta.timestamp:
                    meta_dict["timestamp"] = result.meta.timestamp
                if result.meta.extra:
                    meta_dict["extra"] = result.meta.extra
                if meta_dict:
                    response_dict["meta"] = meta_dict
            return json.dumps(response_dict)
        else:
            raise TypeError(f"Unexpected response type: {type(result)}")

    def test_get_sso_with_google_platform(self) -> None:
        """Test get_sso returns GoogleSSO instance for Google platform."""
        with patch("jac_scale.serve.GoogleSSO", return_value=MockGoogleSSO) as mock_sso:
            sso = self.server.get_sso(Platforms.GOOGLE.value, Operations.LOGIN.value)

            assert sso is not None
            mock_sso.assert_called_once()

    def test_get_sso_with_invalid_platform(self) -> None:
        """Test get_sso returns None for invalid platform."""
        sso = self.server.get_sso("invalid_platform", Operations.LOGIN.value)
        assert sso is None

    def test_get_sso_with_unconfigured_platform(self) -> None:
        """Test get_sso returns None when platform credentials are not configured in jac.toml."""
        reset_scale_config()
        # Mock config without credentials (simulating empty [plugins.scale.sso] in jac.toml)
        mock_config = MockScaleConfig(mock_sso_config_without_credentials())
        with patch("jac_scale.serve.get_scale_config", return_value=mock_config):
            server = JacAPIServer(
                module_name="test_module",
                port=8000,
            )
            sso = server.get_sso(Platforms.GOOGLE.value, Operations.LOGIN.value)
            assert sso is None

    def test_get_sso_redirect_uri_format(self) -> None:
        """Test get_sso creates correct redirect URI based on jac.toml SSO host."""
        with patch("jac_scale.serve.GoogleSSO") as mock_sso:
            self.server.get_sso(Platforms.GOOGLE.value, Operations.LOGIN.value)

            # Check that GoogleSSO was called with correct redirect_uri
            call_args = mock_sso.call_args
            assert call_args is not None
            assert (
                call_args.kwargs["redirect_uri"]
                == "http://localhost:8000/sso/google/login/callback"
            )

    @pytest.mark.asyncio
    async def test_sso_initiate_success(self) -> None:
        """Test successful SSO initiation."""
        with patch.object(
            self.server, "get_sso", return_value=MockGoogleSSO("id", "secret", "uri")
        ):
            result = await self.server.sso_initiate(
                Platforms.GOOGLE.value, Operations.LOGIN.value
            )

            assert isinstance(result, RedirectResponse)
            assert "google.com" in result.headers.get("location", "")

    @pytest.mark.asyncio
    async def test_sso_initiate_with_invalid_platform(self) -> None:
        """Test SSO initiation with invalid platform."""
        result = await self.server.sso_initiate(
            "invalid_platform", Operations.LOGIN.value
        )

        assert isinstance(result, (JSONResponse, TransportResponse))
        # Extract body from JSONResponse or TransportResponse
        body = self._get_response_body(result)
        assert "Invalid platform" in body

    @pytest.mark.asyncio
    async def test_sso_initiate_with_unconfigured_platform(self) -> None:
        """Test SSO initiation with unconfigured platform."""
        # Clear supported platforms
        self.server.SUPPORTED_PLATFORMS = {}

        result = await self.server.sso_initiate(
            Platforms.GOOGLE.value, Operations.LOGIN.value
        )

        assert isinstance(result, (JSONResponse, TransportResponse))
        body = self._get_response_body(result)
        assert "not configured" in body

    @pytest.mark.asyncio
    async def test_sso_initiate_with_invalid_operation(self) -> None:
        """Test SSO initiation with invalid operation."""
        result = await self.server.sso_initiate(
            Platforms.GOOGLE.value, "invalid_operation"
        )

        assert isinstance(result, (JSONResponse, TransportResponse))
        body = self._get_response_body(result)
        assert "Invalid operation" in body

    @pytest.mark.asyncio
    async def test_sso_initiate_when_get_sso_fails(self) -> None:
        """Test SSO initiation when get_sso returns None."""
        with patch.object(self.server, "get_sso", return_value=None):
            result = await self.server.sso_initiate(
                Platforms.GOOGLE.value, Operations.LOGIN.value
            )

            assert isinstance(result, (JSONResponse, TransportResponse))
            body = self._get_response_body(result)
            assert "Failed to initialize SSO" in body

    @pytest.mark.asyncio
    async def test_sso_callback_login_success(self) -> None:
        """Test successful SSO callback for login."""
        # Mock request
        mock_request = Mock(spec=Request)

        # Mock user manager
        self.mock_user_manager.get_user.return_value = {
            "email": "test@example.com",
            "root_id": str(uuid4()),
        }

        # Mock GoogleSSO
        mock_sso = MockGoogleSSO("id", "secret", "uri")
        mock_sso.verify_and_process = AsyncMock(
            return_value=MockUserInfo(email="test@example.com")
        )

        with (
            patch.object(self.server, "get_sso", return_value=mock_sso),
            patch.object(
                self.server, "create_jwt_token", return_value="mock_jwt_token"
            ),
        ):
            result = await self.server.sso_callback(
                mock_request, Platforms.GOOGLE.value, Operations.LOGIN.value
            )

            assert isinstance(result, (JSONResponse, TransportResponse))
            body = self._get_response_body(result)

            assert "Login successful" in body
            assert "test@example.com" in body
            assert "mock_jwt_token" in body

    @pytest.mark.asyncio
    async def test_sso_callback_register_success(self) -> None:
        """Test successful SSO callback for registration."""
        # Mock request
        mock_request = Mock(spec=Request)

        # Mock user manager - user doesn't exist
        self.mock_user_manager.get_user.return_value = None
        self.mock_user_manager.create_user.return_value = {
            "email": "newuser@example.com",
            "root_id": str(uuid4()),
        }

        # Mock GoogleSSO
        mock_sso = MockGoogleSSO("id", "secret", "uri")
        mock_sso.verify_and_process = AsyncMock(
            return_value=MockUserInfo(email="newuser@example.com")
        )

        with (
            patch.object(self.server, "get_sso", return_value=mock_sso),
            patch.object(
                self.server, "create_jwt_token", return_value="mock_jwt_token"
            ),
            patch(
                "jac_scale.serve.generate_random_password",
                return_value="random_pass",
            ),
        ):
            result = await self.server.sso_callback(
                mock_request, Platforms.GOOGLE.value, Operations.REGISTER.value
            )

            assert isinstance(result, (JSONResponse, TransportResponse))
            # Verify create_user was called with random password
            self.mock_user_manager.create_user.assert_called_once_with(
                "newuser@example.com", "random_pass"
            )

    @pytest.mark.asyncio
    async def test_sso_callback_login_user_not_found(self) -> None:
        """Test SSO callback for login when user doesn't exist."""
        # Mock request
        mock_request = Mock(spec=Request)

        # Mock user manager - user doesn't exist
        self.mock_user_manager.get_user.return_value = None

        # Mock GoogleSSO
        mock_sso = MockGoogleSSO("id", "secret", "uri")
        mock_sso.verify_and_process = AsyncMock(
            return_value=MockUserInfo(email="nonexistent@example.com")
        )

        with patch.object(self.server, "get_sso", return_value=mock_sso):
            result = await self.server.sso_callback(
                mock_request, Platforms.GOOGLE.value, Operations.LOGIN.value
            )

            assert isinstance(result, (JSONResponse, TransportResponse))
            body = self._get_response_body(result)

            assert "User not found" in body

    @pytest.mark.asyncio
    async def test_sso_callback_register_user_already_exists(self) -> None:
        """Test SSO callback for registration when user already exists."""
        # Mock request
        mock_request = Mock(spec=Request)

        # Mock user manager - user already exists
        self.mock_user_manager.get_user.return_value = {
            "email": "existing@example.com",
            "root_id": str(uuid4()),
        }

        # Mock GoogleSSO
        mock_sso = MockGoogleSSO("id", "secret", "uri")
        mock_sso.verify_and_process = AsyncMock(
            return_value=MockUserInfo(email="existing@example.com")
        )

        with patch.object(self.server, "get_sso", return_value=mock_sso):
            result = await self.server.sso_callback(
                mock_request, Platforms.GOOGLE.value, Operations.REGISTER.value
            )

            assert isinstance(result, (JSONResponse, TransportResponse))
            body = self._get_response_body(result)

            assert "User already exists" in body

    @pytest.mark.asyncio
    async def test_sso_callback_with_invalid_platform(self) -> None:
        """Test SSO callback with invalid platform."""
        mock_request = Mock(spec=Request)

        result = await self.server.sso_callback(
            mock_request, "invalid_platform", Operations.LOGIN.value
        )

        assert isinstance(result, (JSONResponse, TransportResponse))
        body = self._get_response_body(result)
        assert "Invalid platform" in body

    @pytest.mark.asyncio
    async def test_sso_callback_with_unconfigured_platform(self) -> None:
        """Test SSO callback with unconfigured platform."""
        mock_request = Mock(spec=Request)

        # Clear supported platforms
        self.server.SUPPORTED_PLATFORMS = {}

        result = await self.server.sso_callback(
            mock_request, Platforms.GOOGLE.value, Operations.LOGIN.value
        )

        assert isinstance(result, (JSONResponse, TransportResponse))
        body = self._get_response_body(result)
        assert "not configured" in body

    @pytest.mark.asyncio
    async def test_sso_callback_with_invalid_operation(self) -> None:
        """Test SSO callback with invalid operation."""
        mock_request = Mock(spec=Request)

        result = await self.server.sso_callback(
            mock_request, Platforms.GOOGLE.value, "invalid_operation"
        )

        assert isinstance(result, (JSONResponse, TransportResponse))
        body = self._get_response_body(result)
        assert "Invalid operation" in body

    @pytest.mark.asyncio
    async def test_sso_callback_when_get_sso_fails(self) -> None:
        """Test SSO callback when get_sso returns None."""
        mock_request = Mock(spec=Request)

        with patch.object(self.server, "get_sso", return_value=None):
            result = await self.server.sso_callback(
                mock_request, Platforms.GOOGLE.value, Operations.LOGIN.value
            )

            assert isinstance(result, (JSONResponse, TransportResponse))
            body = self._get_response_body(result)
            assert "Failed to initialize SSO" in body

    @pytest.mark.asyncio
    async def test_sso_callback_when_email_not_provided(self) -> None:
        """Test SSO callback when email is not provided by SSO provider."""
        mock_request = Mock(spec=Request)

        # Mock GoogleSSO with no email
        mock_sso = MockGoogleSSO("id", "secret", "uri")
        mock_user_info = MockUserInfo(email="")
        mock_user_info.email = None  # type: ignore
        mock_sso.verify_and_process = AsyncMock(return_value=mock_user_info)

        with patch.object(self.server, "get_sso", return_value=mock_sso):
            result = await self.server.sso_callback(
                mock_request, Platforms.GOOGLE.value, Operations.LOGIN.value
            )

            assert isinstance(result, (JSONResponse, TransportResponse))
            body = self._get_response_body(result)

            assert "Email not provided" in body

    @pytest.mark.asyncio
    async def test_sso_callback_authentication_failure(self) -> None:
        """Test SSO callback when authentication fails."""
        mock_request = Mock(spec=Request)

        # Mock GoogleSSO that raises exception
        mock_sso = MockGoogleSSO("id", "secret", "uri")
        mock_sso.verify_and_process = AsyncMock(
            side_effect=Exception("Authentication failed")
        )

        with patch.object(self.server, "get_sso", return_value=mock_sso):
            result = await self.server.sso_callback(
                mock_request, Platforms.GOOGLE.value, Operations.LOGIN.value
            )

            assert isinstance(result, (JSONResponse, TransportResponse))
            body = self._get_response_body(result)

            assert "Authentication failed" in body

    @pytest.mark.asyncio
    async def test_sso_callback_register_create_user_error(self) -> None:
        """Test SSO callback for registration when create_user returns error."""
        mock_request = Mock(spec=Request)

        # Mock user manager
        self.mock_user_manager.get_user.return_value = None
        self.mock_user_manager.create_user.return_value = {
            "error": "Failed to create user"
        }

        # Mock GoogleSSO
        mock_sso = MockGoogleSSO("id", "secret", "uri")
        mock_sso.verify_and_process = AsyncMock(
            return_value=MockUserInfo(email="error@example.com")
        )

        with (
            patch.object(self.server, "get_sso", return_value=mock_sso),
            patch(
                "jac_scale.serve.generate_random_password", return_value="random_pass"
            ),
        ):
            result = await self.server.sso_callback(
                mock_request, Platforms.GOOGLE.value, Operations.REGISTER.value
            )

            assert isinstance(result, (JSONResponse, TransportResponse))
            body = self._get_response_body(result)

            assert "Failed to create user" in body

    def test_register_sso_endpoints(self) -> None:
        """Test SSO endpoints registration."""
        # Reset mock
        self.mock_server_impl.reset_mock()

        # Register SSO endpoints
        self.server.register_sso_endpoints()

        # Verify that add_endpoint was called for both endpoints
        assert self.mock_server_impl.add_endpoint.call_count == 2

        # Get the calls
        calls = self.mock_server_impl.add_endpoint.call_args_list

        # Check first endpoint (initiate)
        first_endpoint = calls[0][0][0]
        assert "/sso/{platform}/{operation}" in first_endpoint.path
        assert first_endpoint.method.name == "GET"
        assert "SSO APIs" in first_endpoint.tags

        # Check second endpoint (callback)
        second_endpoint = calls[1][0][0]
        assert "/sso/{platform}/{operation}/callback" in second_endpoint.path
        assert second_endpoint.method.name == "GET"
        assert "SSO APIs" in second_endpoint.tags

    def test_platforms_enum(self) -> None:
        """Test Platforms enum values."""
        assert Platforms.GOOGLE.value == "google"
        assert len(list(Platforms)) == 1  # Only Google is currently supported

    def test_operations_enum(self) -> None:
        """Test Operations enum values."""
        assert Operations.LOGIN.value == "login"
        assert Operations.REGISTER.value == "register"
        assert len(list(Operations)) == 2

    def test_supported_platforms_initialization_with_jac_toml_credentials(self) -> None:
        """Test SUPPORTED_PLATFORMS initialization when credentials are in jac.toml."""
        reset_scale_config()
        # Mock config with credentials (simulating [plugins.scale.sso.google] in jac.toml)
        mock_config = MockScaleConfig(
            {
                "host": "http://localhost:8000/sso",
                "google": {
                    "client_id": "toml_test_id",
                    "client_secret": "toml_test_secret",
                },
            }
        )
        with patch("jac_scale.serve.get_scale_config", return_value=mock_config):
            server = JacAPIServer(
                module_name="test_module",
                port=8000,
            )

            assert "google" in server.SUPPORTED_PLATFORMS
            assert server.SUPPORTED_PLATFORMS["google"]["client_id"] == "toml_test_id"
            assert (
                server.SUPPORTED_PLATFORMS["google"]["client_secret"]
                == "toml_test_secret"
            )

    def test_supported_platforms_initialization_without_jac_toml_credentials(
        self,
    ) -> None:
        """Test SUPPORTED_PLATFORMS initialization when credentials are missing from jac.toml."""
        reset_scale_config()
        # Mock config without credentials (simulating empty sso section in jac.toml)
        mock_config = MockScaleConfig(mock_sso_config_without_credentials())
        with patch("jac_scale.serve.get_scale_config", return_value=mock_config):
            server = JacAPIServer(
                module_name="test_module",
                port=8000,
            )

            assert "google" not in server.SUPPORTED_PLATFORMS
            assert len(server.SUPPORTED_PLATFORMS) == 0

    def test_supported_platforms_initialization_with_partial_jac_toml_credentials(
        self,
    ) -> None:
        """Test SUPPORTED_PLATFORMS initialization with only client_id in jac.toml."""
        reset_scale_config()
        # Mock config with partial credentials (only client_id, no secret)
        mock_config = MockScaleConfig(mock_sso_config_partial_credentials())
        with patch("jac_scale.serve.get_scale_config", return_value=mock_config):
            server = JacAPIServer(
                module_name="test_module",
                port=8000,
            )

            # Should not be added if credentials are incomplete
            assert "google" not in server.SUPPORTED_PLATFORMS

    @pytest.mark.asyncio
    async def test_sso_callback_login_token_generation(self) -> None:
        """Test that SSO callback generates JWT token on successful login."""
        mock_request = Mock(spec=Request)

        # Mock user manager
        user_email = "tokentest@example.com"
        self.mock_user_manager.get_user.return_value = {
            "email": user_email,
            "root_id": str(uuid4()),
        }

        # Mock GoogleSSO
        mock_sso = MockGoogleSSO("id", "secret", "uri")
        mock_sso.verify_and_process = AsyncMock(
            return_value=MockUserInfo(email=user_email)
        )

        with (
            patch.object(self.server, "get_sso", return_value=mock_sso),
            patch.object(
                self.server, "create_jwt_token", return_value="generated_token"
            ) as mock_create_token,
        ):
            result = await self.server.sso_callback(
                mock_request, Platforms.GOOGLE.value, Operations.LOGIN.value
            )

            # Verify create_jwt_token was called with correct email
            mock_create_token.assert_called_once_with(user_email)

            # Verify response contains the token
            assert isinstance(result, (JSONResponse, TransportResponse))
            body = self._get_response_body(result)

            assert "generated_token" in body

    @pytest.mark.asyncio
    async def test_sso_callback_register_token_generation(self) -> None:
        """Test that SSO callback generates JWT token on successful registration."""
        mock_request = Mock(spec=Request)

        user_email = "registertoken@example.com"

        # Mock user manager
        self.mock_user_manager.get_user.return_value = None
        self.mock_user_manager.create_user.return_value = {
            "email": user_email,
            "root_id": str(uuid4()),
        }

        # Mock GoogleSSO
        mock_sso = MockGoogleSSO("id", "secret", "uri")
        mock_sso.verify_and_process = AsyncMock(
            return_value=MockUserInfo(email=user_email)
        )

        with (
            patch.object(self.server, "get_sso", return_value=mock_sso),
            patch.object(
                self.server, "create_jwt_token", return_value="new_user_token"
            ) as mock_create_token,
            patch(
                "jac_scale.serve.generate_random_password",
                return_value="random_pass",
            ),
        ):
            result = await self.server.sso_callback(
                mock_request, Platforms.GOOGLE.value, Operations.REGISTER.value
            )

            # Verify create_jwt_token was called with correct email
            mock_create_token.assert_called_once_with(user_email)

            # Verify response contains the token
            assert isinstance(result, (JSONResponse, TransportResponse))
            body = self._get_response_body(result)

            assert "new_user_token" in body
