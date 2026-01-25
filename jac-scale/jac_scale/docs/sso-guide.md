
# Single Sign-On (SSO) Guide

Jac Scale comes with a robust Single Sign-On (SSO) system that supports Google Authentication out of the box and is designed to be easily extensible for other providers (Microsoft, GitHub, etc.).

## 1. Configuration

SSO configuration is managed via the `jac.toml` file in your project root.

### Enable SSO

Add the following configuration to your `jac.toml`:

```toml
[plugins.scale]
[plugins.scale.jwt]
secret = "your_jwt_secret_key"
algorithm = "HS256"
exp_delta_days = 7

[plugins.scale.sso]
host = "http://localhost:8000/sso"

# Configure specific providers
[plugins.scale.sso.google]
client_id = "${GOOGLE_CLIENT_ID}"
client_secret = "${GOOGLE_CLIENT_SECRET}"
```

## 2. Google SSO Setup

To use Google Sign-In:

1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project or select an existing one.
3. Go to **APIs & Services > Credentials**.
4. Click **Create Credentials > OAuth client ID**.
5. Select **Web application**.
6. Add your redirect URI. For local development, this is typically:
    `http://localhost:8000/sso/google/login/callback`
    and
    `http://localhost:8000/sso/google/register/callback`
7. Copy the **Client ID** and **Client Secret** to your `jac.toml` using environment variable interpolation syntax `${VAR_NAME}`.
    Make sure to export `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in your environment.

## 3. Adding New SSO Providers

Jac Scale uses an abstract base class `SSOProvider` to enforce a consistent interface. To add a new provider (e.g., GitHub), follow these steps:

### Step 1: Create the Provider Class

Create a new file (e.g., `github_sso_provider.jac`) and implement the `SSOProvider` interface:

```jac
import from jac_scale.sso_provider { SSOProvider, SSOUserInfo }

obj GitHubSSOProvider(SSOProvider) {
    can initiate_auth(redirect_uri: str) -> str {
        # Return the authorization URL for GitHub
    }

    async can handle_callback(request: Request) -> SSOUserInfo {
        # Exchange code for token and get user info
        return SSOUserInfo(
            email="user@github.com",
            external_id="12345",
            platform="github",
            display_name="GitHub User"
        );
    }

    can get_platform_name() -> str {
        return "github";
    }
}
```

### Step 2: Register the Provider in JacScaleUserManager

Modify `jac_scale/impl/user_manager.impl.jac` to instantiate your new provider in `get_sso`:

```jac
impl JacScaleUserManager.get_sso(platform: str, operation: str) -> (SSOProvider | None) {
    if platform == "github" {
        return GitHubSSOProvider(...);
    }
    # ... existing Google logic ...
}
```

## 4. UserManager Extension Pattern

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
    - SSO handling
    - Custom specific logic (like the `sso_accounts` table).

If you are developing your own plugin, you can follow this pattern to provide your own User Manager implementation.
