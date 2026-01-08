# Environment Variables: Configuration Made Easy

!!! warning "Deprecated"
    **Jac Cloud is deprecated.** Use [jac-scale](../../production/index.md) for new projects.

## What Are Environment Variables?

Environment variables are a simple way to configure your Jac Cloud application without changing code. Think of them as settings you can adjust from outside your application. They're perfect for:

- Switching between development and production settings
- Connecting to different databases
- Adjusting security parameters
- Enabling or disabling features
- Storing API keys and secrets

## Quick Start: Setting Your First Variables

### In Development (Command Line)

```bash
# Set variables before running your application
export DATABASE_NAME=my_app_dev
export LOGGER_LEVEL=debug
jac serve main.jac
```

### In Production (Environment File)

```bash
# Create a .env file
echo "DATABASE_NAME=my_app_prod" > .env
echo "LOGGER_LEVEL=info" >> .env

# Load variables and run
source .env
jac serve main.jac
```

## Core Configuration Groups

### Database Connection

Connect to MongoDB or local storage:

```bash
# MongoDB Atlas (cloud database)
export DATABASE_HOST="mongodb+srv://username:password@cluster.mongodb.net"
export DATABASE_NAME="production_db"

# OR Local database
export DATABASE_PATH="local_data"
export DATABASE_NAME="my_app"
```

### Redis Configuration (for WebSockets & Caching)

```bash
# Basic Redis setup
export REDIS_HOST="redis://redis.example.com"
export REDIS_PORT="6379"

# Secured Redis
export REDIS_USER="admin"
export REDIS_PASS="your_secure_password"
```

### API Behavior

```bash
# Show detailed responses including return values
export SHOW_ENDPOINT_RETURNS=true

# Disable automatic API endpoint generation
export DISABLE_AUTO_ENDPOINT=true

# Disable authentication requirement for all walker endpoints
export REQUIRE_AUTH_BY_DEFAULT=false

# Performance optimizations
export DISABLE_AUTO_CLEANUP=true
export SINGLE_QUERY=true
export SESSION_MAX_TRANSACTION_RETRY=3
export SESSION_MAX_COMMIT_RETRY=3
```

## Security Settings

### Token Security

```bash
# Strong security for production
export TOKEN_SECRET="a_long_random_string_that_is_very_hard_to_guess"
export TOKEN_ALGORITHM="HS512"  # More secure algorithm
export TOKEN_TIMEOUT="4"        # 4-hour tokens
```

### User Verification

```bash
# Require email verification before login
export RESTRICT_UNVERIFIED_USER=true
export VERIFICATION_CODE_TIMEOUT=48  # 48 hours to verify
export RESET_CODE_TIMEOUT=1          # 1 hour to reset password
```

### Email Integration (for Verification)

```bash
# SendGrid configuration for email notifications
export SENDGRID_HOST="https://api.example.com"
export SENDGRID_API_KEY="SG.your-sendgrid-api-key"
```

## Logging Configuration

Control what gets logged and where:

```bash
# Production logging setup
export LOGGER_NAME="production"                   # Custom logger name
export LOGGER_LEVEL="info"                        # Less verbose logging
export LOGGER_FILE_PATH="/var/log/jac-cloud.log"  # Standard log location
export LOGGER_ROLLOVER_INTERVAL="D"               # Daily rotation
export LOGGER_MAX_BACKUP="30"                     # Keep 30 days of logs
export LOGGER_ROLLOVER_MAX_FILE_SIZE="10000000"   # 10MB max file size
export LOGGER_USE_UTC="true"                      # Use UTC timestamps
```

## Environment Variable Reference Tables

### Database & Cache Settings

| **Variable** | **Description** | **Default** | **Example** |
|--------------|-----------------|-------------|-------------|
| `DATABASE_HOST` | MongoDB connection string | `mongodb://localhost/?retryWrites=true&w=majority` | `mongodb+srv://user:pass@cluster.mongodb.net` |
| `DATABASE_NAME` | MongoDB database name | `jaseci` | `my_production_db` |
| `DATABASE_PATH` | Local path for DB | `mydatabase` | `path/to/db` |
| `REDIS_HOST` | Redis connection host | `redis://localhost` | `redis://redis.example.com` |
| `REDIS_PORT` | Redis connection port | `6379` | `6380` |
| `REDIS_USER` | Redis username | `null` | `admin` |
| `REDIS_PASS` | Redis password | `null` | `secret123` |

### API & Application Behavior

| **Variable** | **Description** | **Default** | **Example** |
|--------------|-----------------|-------------|-------------|
| `DISABLE_AUTO_ENDPOINT` | Disable automatic API endpoints | `false` | `true` |
| `REQUIRE_AUTH_BY_DEFAULT` | Require authentication for all walker endpoints | `true` | `false` |
<!-- | `SHOW_ENDPOINT_RETURNS` | Include walker return values | `false` | `true` | -->
| `DISABLE_AUTO_CLEANUP` | Disable automatic deletion of disconnected nodes | `false` | `true` |
| `SINGLE_QUERY` | Use individual queries instead of batch | `false` | `true` |
| `SESSION_MAX_TRANSACTION_RETRY` | MongoDB's transactional retry | `1` | `3` |
| `SESSION_MAX_COMMIT_RETRY` | MongoDB's transaction commit retry | `1` | `3` |

### Authentication & Security

| **Variable** | **Description** | **Default** | **Example** |
|--------------|-----------------|-------------|-------------|
| `TOKEN_SECRET` | Secret key for token encryption | 50 random characters | `your-super-secure-secret-key` |
| `TOKEN_ALGORITHM` | Algorithm for token encryption | `HS256` | `HS512` |
| `TOKEN_TIMEOUT` | Token expiration in hours | `12` | `24` |
| `RESTRICT_UNVERIFIED_USER` | Require email verification | `false` | `true` |
| `VERIFICATION_CODE_TIMEOUT` | Verification code expiration (hours) | `24` | `48` |
| `RESET_CODE_TIMEOUT` | Password reset code expiration (hours) | `24` | `1` |
| `SENDGRID_HOST` | Host for verification links | `http://localhost:8000` | `https://api.example.com` |
| `SENDGRID_API_KEY` | SendGrid API key | `null` | `SG.your-api-key` |

### Logging Configuration

| **Variable** | **Description** | **Default** | **Example** |
|--------------|-----------------|-------------|-------------|
| `LOGGER_NAME` | Logger name | `app` | `production` |
| `LOGGER_LEVEL` | Log level | `debug` | `info` |
| `LOGGER_FILE_PATH` | Log file location | `/tmp/jac_cloud_logs/jac-cloud.log` | `/var/log/jac-cloud.log` |
| `LOGGER_ROLLOVER_INTERVAL` | Rotation interval (M=minute, H=hour, D=day, W=week) | `D` | `H` |
| `LOGGER_MAX_BACKUP` | Maximum backup files | `-1` (unlimited) | `30` |
| `LOGGER_ROLLOVER_MAX_FILE_SIZE` | Maximum file size in bytes before rollover | `10000000` | `5000000` |
| `LOGGER_USE_UTC` | Use UTC time | `false` | `true` |

## Social Login Configuration

### Basic Pattern

```bash
# Replace PLATFORM with: GOOGLE, GITHUB, FACEBOOK, etc.
export SSO_{PLATFORM}_CLIENT_ID="your_client_id"
export SSO_{PLATFORM}_CLIENT_SECRET="your_client_secret"
```

### Google Example

```bash
export SSO_GOOGLE_CLIENT_ID="123456789-abcdef.apps.googleusercontent.com"
export SSO_GOOGLE_CLIENT_SECRET="GOCSPX-abcdefghijklmnop"
```

### GitHub Example

```bash
export SSO_GITHUB_CLIENT_ID="abc123def456"
export SSO_GITHUB_CLIENT_SECRET="ghp_abcdefghijklmnopqrstuvwxyz"
```

### Complete SSO Environment Variables

| **Variable Pattern** | **Description** |
|----------------------|-----------------|
| `SSO_{PLATFORM}_CLIENT_ID` | OAuth client ID for the platform |
| `SSO_{PLATFORM}_CLIENT_SECRET` | OAuth client secret for the platform |
| `SSO_{PLATFORM}_ALLOW_INSECURE_HTTP` | Allow non-HTTPS connections (not recommended for production) |
| `SSO_GITLAB_BASE_ENDPOINT_URL` | Base URL for GitLab SSO (for self-hosted GitLab) |
| `SSO_MICROSOFT_TENANT` | Microsoft tenant ID for Azure AD |

### Apple-Specific SSO Configuration

Apple requires a special configuration for client secret generation:

| **Variable** | **Description** |
|--------------|-----------------|
| `SSO_APPLE_CLIENT_ID` | Apple client ID |
| `SSO_APPLE_CLIENT_TEAM_ID` | Apple developer team ID |
| `SSO_APPLE_CLIENT_KEY` | Apple client key |
| `SSO_APPLE_CLIENT_CERTIFICATE_PATH` | Path to Apple client certificate |
| `SSO_APPLE_CLIENT_CERTIFICATE` | Raw Apple client certificate content |

### Supported Platforms

<div class="grid-container" style="display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 10px;">
    <div class="grid-item" style="text-align: center; padding: 15px; border: 1px solid #444; border-radius: 8px; background-color: #333;">
        <div>Google</div>
    </div>
    <div class="grid-item" style="text-align: center; padding: 15px; border: 1px solid #444; border-radius: 8px; background-color: #333;">
        <div>Facebook</div>
    </div>
    <div class="grid-item" style="text-align: center; padding: 15px; border: 1px solid #444; border-radius: 8px; background-color: #333;">
        <div>GitHub</div>
    </div>
    <div class="grid-item" style="text-align: center; padding: 15px; border: 1px solid #444; border-radius: 8px; background-color: #333;">
        <div>Microsoft</div>
    </div>
    <div class="grid-item" style="text-align: center; padding: 15px; border: 1px solid #444; border-radius: 8px; background-color: #333;">
        <div>Apple</div>
    </div>
    <div class="grid-item" style="text-align: center; padding: 15px; border: 1px solid #444; border-radius: 8px; background-color: #333;">
        <div>LinkedIn</div>
    </div>
    <div class="grid-item" style="text-align: center; padding: 15px; border: 1px solid #444; border-radius: 8px; background-color: #333;">
        <div>Twitter</div>
    </div>
    <div class="grid-item" style="text-align: center; padding: 15px; border: 1px solid #444; border-radius: 8px; background-color: #333;">
        <div>GitLab</div>
    </div>
    <div class="grid-item" style="text-align: center; padding: 15px; border: 1px solid #444; border-radius: 8px; background-color: #333;">
        <div>KAKAO</div>
    </div>
    <div class="grid-item" style="text-align: center; padding: 15px; border: 1px solid #444; border-radius: 8px; background-color: #333;">
        <div>Notion</div>
    </div>
    <div class="grid-item" style="text-align: center; padding: 15px; border: 1px solid #444; border-radius: 8px; background-color: #333;">
        <div>YANDEX</div>
    </div>
    <div class="grid-item" style="text-align: center; padding: 15px; border: 1px solid #444; border-radius: 8px; background-color: #333;">
        <div>FITBIT</div>
    </div>
    <div class="grid-item" style="text-align: center; padding: 15px; border: 1px solid #444; border-radius: 8px; background-color: #333;">
        <div>LINE</div>
    </div>
    <div class="grid-item" style="text-align: center; padding: 15px; border: 1px solid #444; border-radius: 8px; background-color: #333;">
        <div>NAVER</div>
    </div>
</div>

## Server Configuration (Uvicorn)

Jac Cloud uses Uvicorn as its server. Configure it with these variables:

### Basic Server Settings

```bash
# Public server configuration
export UV_HOST="0.0.0.0"        # Listen on all interfaces
export UV_PORT="80"              # Standard HTTP port
export UV_TIMEOUT_KEEP_ALIVE="120"  # Keep connections alive longer
```

### HTTPS/SSL Configuration

```bash
# Enable HTTPS
export UV_SSL_KEYFILE="/etc/ssl/private/key.pem"
export UV_SSL_CERTFILE="/etc/ssl/certs/cert.pem"
```

### Complete Uvicorn Configuration Table

| **Variable** | **Uvicorn Equivalent** | **Default** | **Description** |
|--------------|------------------------|-------------|-----------------|
| `UV_HOST` | host | "127.0.0.1" | Interface to bind to |
| `UV_PORT` | port | 8000 | Port to bind to |
| `UV_UDS` | uds | None | Unix domain socket path |
| `UV_FD` | fd | None | File descriptor to use |
| `UV_LOOP` | loop | "auto" | Event loop implementation |
| `UV_HTTP` | http | "auto" | HTTP protocol implementation |
| `UV_WS` | ws | "auto" | WebSocket protocol implementation |
| `UV_WS_MAX_SIZE` | ws_max_size | 16777216 | WebSocket max message size |
| `UV_WS_MAX_QUEUE` | ws_max_queue | 32 | WebSocket max queue size |
| `UV_WS_PING_INTERVAL` | ws_ping_interval | 20.0 | WebSocket ping interval |
| `UV_WS_PING_TIMEOUT` | ws_ping_timeout | 20.0 | WebSocket ping timeout |
| `UV_WS_PER_MESSAGE_DEFLATE` | ws_per_message_deflate | True | WebSocket message compression |
| `UV_LIFESPAN` | lifespan | "auto" | Lifespan implementation |
| `UV_INTERFACE` | interface | "auto" | ASGI interface type |
| `UV_RELOAD_DIRS` | reload_dirs | None | Directories to monitor for reload |
| `UV_RELOAD_INCLUDES` | reload_includes | None | File patterns to include for reload |
| `UV_RELOAD_EXCLUDES` | reload_excludes | None | File patterns to exclude from reload |
| `UV_RELOAD_DELAY` | reload_delay | 0.25 | Reload delay in seconds |
| `UV_ENV_FILE` | env_file | None | Environment file path |
| `UV_LOG_CONFIG` | log_config | LOGGING_CONFIG | Logging configuration |
| `UV_LOG_LEVEL` | log_level | None | Log level |
| `UV_ACCESS_LOG` | access_log | True | Enable access log |
| `UV_PROXY_HEADERS` | proxy_headers | True | Trust proxy headers |
| `UV_SERVER_HEADER` | server_header | True | Include server header |
| `UV_DATE_HEADER` | date_header | True | Include date header |
| `UV_FORWARDED_ALLOW_IPS` | forwarded_allow_ips | None | IPs allowed for X-Forwarded-For |
| `UV_ROOT_PATH` | root_path | "" | ASGI root path |
| `UV_LIMIT_CONCURRENCY` | limit_concurrency | None | Maximum concurrent connections |
| `UV_BACKLOG` | backlog | 2048 | Maximum number of pending connections |
| `UV_LIMIT_MAX_REQUESTS` | limit_max_requests | None | Maximum requests per worker |
| `UV_TIMEOUT_KEEP_ALIVE` | timeout_keep_alive | 5 | Keep-alive connection timeout |
| `UV_TIMEOUT_GRACEFUL_SHUTDOWN` | timeout_graceful_shutdown | None | Graceful shutdown timeout |
| `UV_SSL_KEYFILE` | ssl_keyfile | None | SSL key file path |
| `UV_SSL_CERTFILE` | ssl_certfile | None | SSL certificate file path |
| `UV_SSL_KEYFILE_PASSWORD` | ssl_keyfile_password | None | SSL key file password |
| `UV_SSL_VERSION` | ssl_version | SSL_PROTOCOL_VERSION | SSL version |
| `UV_SSL_CERT_REQS` | ssl_cert_reqs | ssl.CERT_NONE | SSL certificate requirements |
| `UV_SSL_CA_CERTS` | ssl_ca_certs | None | SSL CA certificate file |
| `UV_SSL_CIPHERS` | ssl_ciphers | "TLSv1" | SSL cipher suite |
| `UV_HEADERS` | headers | None | HTTP headers to include |
| `UV_USE_COLORS` | use_colors | None | Use colors in logs |
| `UV_APP_DIR` | app_dir | None | Application directory |
| `UV_FACTORY` | factory | False | Use application factory pattern |
| `UV_H11_MAX_INCOMPLETE_EVENT_SIZE` | h11_max_incomplete_event_size | None | Maximum h11 incomplete event size |

!!! note "Running with Workers"
    `UV_RELOAD` and `UV_WORKERS` are not supported with `jac serve`. If you need multiple workers, use `uvicorn` directly with the `--workers` flag and set the `APP_PATH` environment variable to your Jac file.

## Environment Presets for Different Scenarios

### Local Development

```bash
# Quick setup for local development
export DATABASE_NAME="dev_db"
export LOGGER_LEVEL="debug"
export SHOW_ENDPOINT_RETURNS="true"
```

### Testing

```bash
# Configuration for testing
export DATABASE_NAME="test_db"
export LOGGER_LEVEL="debug"
export TOKEN_TIMEOUT="1"  # Short-lived tokens for testing
export REQUIRE_AUTH_BY_DEFAULT="false"  # Disable auth for easier testing
```

### Production

```bash
# Secure production configuration
export DATABASE_HOST="mongodb+srv://user:pass@cluster.mongodb.net"
export DATABASE_NAME="prod_db"
export LOGGER_LEVEL="info"
export LOGGER_MAX_BACKUP="30"
export TOKEN_ALGORITHM="HS512"
export TOKEN_TIMEOUT="4"
export RESTRICT_UNVERIFIED_USER="true"
export UV_HOST="0.0.0.0"
export UV_PORT="443"
export UV_SSL_KEYFILE="/etc/ssl/private/key.pem"
export UV_SSL_CERTFILE="/etc/ssl/certs/cert.pem"
```

## Best Practices for Beginners

1. **Use environment files**: Create `.env` files for different environments

   ```bash
   # Create different environment files
   touch .env.development .env.testing .env.production
   ```

2. **Never commit secrets**: Add `.env` files to your `.gitignore`

   ```bash
   # Add to .gitignore
   echo ".env*" >> .gitignore
   ```

3. **Use different values per environment**:

   ```bash
   # Development
   DATABASE_NAME=my_app_dev

   # Production
   DATABASE_NAME=my_app_prod
   ```

4. **Document your variables**: Create a template file showing all options

   ```bash
   # Create a template with comments
   touch .env.template
   ```

5. **Validate critical variables**: Check for required variables in your code

   ```jac
   walker check_config {
       can enter with `root entry {
           if not env("DATABASE_HOST") {
               print("Warning: DATABASE_HOST not set, using default");
           }
       }
   }
   ```

## Next Steps

- Learn about [WebSocket Communication](websocket.md) for real-time features
- Explore [Task Scheduling](scheduler.md) for automated background tasks
- Set up [Logging & Monitoring](logging.md) to track application performance
- Deploy your app using the [Kubernetes Deployment Guide](deployment.md)
