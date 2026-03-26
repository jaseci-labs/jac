
# Single Sign-On (SSO) Guide

Jac Scale comes with a robust Single Sign-On (SSO) system that supports **Google**, **Apple**, and **GitHub** authentication out of the box and is designed to be easily extensible for other providers.

## 1. Configuration

SSO configuration is managed via the `jac.toml` file in your project root.

### Enable SSO

Add the following configuration to your `jac.toml`:

```toml
[plugins.scale.jwt]
secret = "your_jwt_secret_key"
algorithm = "HS256"
exp_delta_days = 7

[plugins.scale.sso]
host = "http://localhost:8000"
client_auth_callback_url = ""  # Optional: frontend URL to redirect after SSO (e.g., "https://myapp.com/auth-done")

# Configure specific providers
[plugins.scale.sso.google]
client_id = "${GOOGLE_CLIENT_ID}"
client_secret = "${GOOGLE_CLIENT_SECRET}"

[plugins.scale.sso.apple]
client_id = "${APPLE_CLIENT_ID}"
client_secret = "${APPLE_CLIENT_SECRET}"

[plugins.scale.sso.github]
client_id = "${GITHUB_CLIENT_ID}"
client_secret = "${GITHUB_CLIENT_SECRET}"
```

Only providers with both `client_id` and `client_secret` configured will be available. Unconfigured providers are silently skipped.

## 2. Endpoints

### Initiation

```
GET /sso/{platform}/{operation}
```

- `platform`: `google`, `apple`, or `github`
- `operation`: `login` or `register`

Redirects the user to the SSO provider's authorization page.

### Callback (unified)

```
GET  /sso/{platform}/callback
POST /sso/{platform}/callback
```

A single callback endpoint handles both login and registration:

- If the user **already exists**: logs them in and returns a JWT token.
- If the user **does not exist**: automatically registers them with a random password, then returns a JWT token.

Both GET and POST methods are supported (Apple Sign In uses POST for its callback).

### Frontend Redirect

If `client_auth_callback_url` is configured, the callback redirects to that URL with query parameters:

- **Success**: `{client_auth_callback_url}?token={jwt_token}`
- **Error**: `{client_auth_callback_url}?error={code}&message={details}`

If not configured, the callback returns a JSON `TransportResponse`.

## 3. Google SSO Setup

1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project or select an existing one.
3. Go to **APIs & Services > Credentials**.
4. Click **Create Credentials > OAuth client ID**.
5. Select **Web application**.
6. Add the redirect URI:

   ```
   http://localhost:8000/sso/google/callback
   ```

7. Copy the **Client ID** and **Client Secret**.
8. Export them as environment variables:

   ```bash
   export GOOGLE_CLIENT_ID="your_client_id"
   export GOOGLE_CLIENT_SECRET="your_client_secret"
   ```

## 4. Apple SSO Setup

1. Go to the [Apple Developer Portal](https://developer.apple.com/).
2. Register an **App ID** with **Sign In with Apple** enabled.
3. Create a **Services ID** for web authentication.
4. Configure the redirect URI:

   ```
   http://localhost:8000/sso/apple/callback
   ```

5. Generate a **Client Secret** (Apple uses a JWT-based secret).
6. Export them as environment variables:

   ```bash
   export APPLE_CLIENT_ID="your_services_id"
   export APPLE_CLIENT_SECRET="your_client_secret"
   ```

> **Note**: Apple Sign In sends callbacks as POST requests, which is why both GET and POST callback endpoints are registered.

## 5. GitHub SSO Setup

1. Go to [GitHub Developer Settings](https://github.com/settings/developers).
2. Click **New OAuth App**.
3. Set the **Authorization callback URL** to:

   ```
   http://localhost:8000/sso/github/callback
   ```

4. Copy the **Client ID** and generate a **Client Secret**.
5. Export them as environment variables:

   ```bash
   export GITHUB_CLIENT_ID="your_client_id"
   export GITHUB_CLIENT_SECRET="your_client_secret"
   ```

## 6. Adding New SSO Providers

Jac Scale uses an abstract base class `SSOProvider` to enforce a consistent interface. To add a new provider (e.g., Microsoft), follow these steps:

### Step 1: Add the Platform to the Enum

In `jac_scale/enums.jac`, add the new platform:

```jac
enum Platforms {
    GOOGLE = 'google',
    APPLE = 'apple',
    GITHUB = 'github',
    MICROSOFT = 'microsoft',
}
```

### Step 2: Create the Provider Class

Create a new file `sso/microsoft.jac` implementing the `SSOProvider` interface:

```jac
import from fastapi { Request, Response }
import from fastapi_sso.sso.microsoft { MicrosoftSSO }
import from jac_scale.sso.provider { SSOProvider, SSOUserInfo }
import from jac_scale.enums { Platforms }

obj MicrosoftSSOProvider(SSOProvider) {
    has client_id: str,
        client_secret: str,
        redirect_uri: str,
        allow_insecure_http: bool = True,
        _microsoft_sso: (MicrosoftSSO | None) = None;

    def postinit -> None {
        self._microsoft_sso = MicrosoftSSO(
            client_id=self.client_id,
            client_secret=self.client_secret,
            redirect_uri=self.redirect_uri,
            allow_insecure_http=self.allow_insecure_http
        );
    }

    async def initiate_auth -> Response {
        with self._microsoft_sso {
            return await self._microsoft_sso.get_login_redirect();
        }
    }

    async def handle_callback(request: Request) -> SSOUserInfo {
        with self._microsoft_sso {
            user_info = await self._microsoft_sso.verify_and_process(request);
            return SSOUserInfo(
                email=user_info.email,
                external_id=user_info.id,
                platform=self.get_platform_name(),
                display_name=user_info?.display_name
            );
        }
    }

    def get_platform_name -> str {
        return Platforms.MICROSOFT.value;
    }
}
```

### Step 3: Register in UserManager and Config

1. Add the provider instantiation in `impl/user_manager.impl.jac` inside `get_sso()`:

```jac
if platform == Platforms.MICROSOFT.value {
    import from jac_scale.sso.microsoft { MicrosoftSSOProvider }
    return MicrosoftSSOProvider(
        client_id=credentials['client_id'],
        client_secret=credentials['client_secret'],
        redirect_uri=redirect_uri,
        allow_insecure_http=True
    );
}
```

1. Add the default config in `impl/config_loader.impl.jac`:

```jac
'microsoft': {'client_id': '', 'client_secret': ''}
```

1. Add the config parsing in `get_sso_config()`.

## 7. UserManager Extension Pattern

Jac Scale allows you to override the core `UserManager` using the plugin hook system.

### How it works

1. **Hook Definition**: The core `jac` runtime defines a hook spec `get_user_manager()`.
2. **Implementation**: `jac-scale` provides an implementation in `plugin.jac`:

    ```jac
    @hookimpl
    def get_user_manager() -> Type[UserManager] {
        return JacScaleUserManager;
    }
    ```

3. **Custom Logic**: The `JacScaleUserManager` extends the base `UserManager` to add:
    - JWT-based authentication
    - SSO handling (unified callback with auto-registration)
    - SSO account linking
    - Role-based user management
