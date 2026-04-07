# GitHub Integration Setup Guide for Jac Builder Studio

Complete step-by-step guide to configure GitHub integration in Jac Builder Studio.

## Overview

Jac Builder Studio uses **two separate GitHub OAuth Apps** for different purposes:

| App | Purpose | Callback URL |
|---|---|---|
| **SSO OAuth App** | Login ("Continue with GitHub") | `/sso/github/callback` (managed by jac-scale) |
| **Repo Ops OAuth App** | Push, pull, create repos, PRs | `/auth/github-connect` |

This separation is required because:

- jac-scale hardcodes the SSO callback to `/sso/github/callback`
- OAuth Apps only support one callback URL each
- OAuth App tokens work for both REST API and git transport (no JWT/installation tokens needed)

### Token Strategy

| Operation | Token Type | Source |
|---|---|---|
| Create repo | OAuth App token | Single token from OAuth flow |
| List repos | OAuth App token | Same token |
| Git push/pull/clone | OAuth App token | Same token via GIT_ASKPASS |
| Create PR | OAuth App token | Same token |
| SSO login | SSO OAuth App (jac-scale) | Separate flow, untouched |

One OAuth App token with `repo,read:user,user:email` scopes does everything. No JWT signing, no installation tokens, no refresh logic needed (OAuth App tokens don't expire).

---

## Part 1: SSO OAuth App (Login)

This OAuth App powers "Continue with GitHub" on the login page. It's managed by jac-scale.

### Step 1: Create the OAuth App

1. Go to **GitHub Settings** > **Developer settings** > **OAuth Apps** > **New OAuth App**
   - Direct link: https://github.com/settings/applications/new

2. Fill in:

| Field | Local Dev | Production |
|---|---|---|
| **Application name** | `jac-builder-sso-dev` | `jac-builder-sso` |
| **Homepage URL** | `http://localhost:8000` | `https://jac-builder.jaseci.org` |
| **Authorization callback URL** | `http://localhost:8000/sso/github/callback` | `https://jac-builder.jaseci.org/sso/github/callback` |

**Note:** OAuth Apps only support ONE callback URL. Create separate apps for local dev and production.

### Step 2: Note Credentials

After creating the app, note:

- **Client ID** (starts with `Ov...`)
- **Client Secret** (generate one, copy immediately)

These map to:

```bash
GITHUB_CLIENT_ID=Ov23li...
GITHUB_CLIENT_SECRET=...
GITHUB_APP_SLUG=                      # Leave empty for OAuth Apps
```

---

## Part 2: Repo Ops OAuth App

This OAuth App powers push, pull, create repo, and create PR from the Git panel.

### Step 1: Create the OAuth App

1. Go to **GitHub Settings** > **Developer settings** > **OAuth Apps** > **New OAuth App**
   - Direct link: https://github.com/settings/applications/new

2. Fill in:

| Field | Local Dev | Production |
|---|---|---|
| **Application name** | `jac-builder-repo-dev` | `jac-builder-repo` |
| **Homepage URL** | `http://localhost:8000` | `https://jac-builder.jaseci.org` |
| **Authorization callback URL** | `http://localhost:8000/auth/github-connect` | `https://jac-builder.jaseci.org/auth/github-connect` |

**Note:** OAuth Apps only support ONE callback URL. Create separate apps for local dev and production.

### Step 2: Note Credentials

After creating the app, note:

- **Client ID** (starts with `Ov...`)
- **Client Secret** (generate one, copy immediately)

These map to:

```bash
GITHUB_REPO_CLIENT_ID=Ov23li...
GITHUB_REPO_CLIENT_SECRET=...
```

### Step 3: Scopes

The OAuth App requests these scopes during authorization (handled automatically by the backend):

- `repo` -- full access to public and private repositories (push, pull, create)
- `read:user` -- read user profile information
- `user:email` -- read user email address

---

## Environment Variables

### Local Development (`.env`)

```bash
# Google OAuth (SSO login)
GOOGLE_CLIENT_ID=""
GOOGLE_CLIENT_SECRET=""

# GitHub OAuth App (SSO login — managed by jac-scale)
# Callback URL: http://localhost:8000/sso/github/callback
GITHUB_CLIENT_ID=Ov23li...           # SSO OAuth App Client ID
GITHUB_CLIENT_SECRET=...             # SSO OAuth App Client Secret
GITHUB_APP_SLUG=                     # Leave empty for OAuth Apps

# GitHub OAuth App (repo operations — push, pull, create repo, PRs)
# Callback URL: http://localhost:8000/auth/github-connect
GITHUB_REPO_CLIENT_ID=Ov23li...     # Repo Ops OAuth App Client ID
GITHUB_REPO_CLIENT_SECRET=...       # Repo Ops OAuth App Client Secret

# Token encryption (optional but recommended for production)
# Generate: python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
GITHUB_TOKEN_ENCRYPTION_KEY=

# Server URLs (must match callback URLs registered in both apps)
HOST=http://localhost:8000
CLIENT_AUTH_CALLBACK_URL=http://localhost:8000/auth/callback
```

### Production (Kubernetes / CI Secrets)

| Secret | Value | Notes |
|---|---|---|
| `GITHUB_CLIENT_ID` | `Ov23li...` | SSO OAuth App Client ID |
| `GITHUB_CLIENT_SECRET` | `...` | SSO OAuth App Client Secret |
| `GITHUB_APP_SLUG` | (empty) | Not needed for OAuth Apps |
| `GITHUB_REPO_CLIENT_ID` | `Ov23li...` | Repo Ops OAuth App Client ID |
| `GITHUB_REPO_CLIENT_SECRET` | `...` | Repo Ops OAuth App Client Secret |
| `GITHUB_TOKEN_ENCRYPTION_KEY` | `<fernet-key>` | Encrypts stored OAuth tokens at rest |
| `HOST` | `https://jac-builder.jaseci.org` | Must match callback URLs |
| `CLIENT_AUTH_CALLBACK_URL` | `https://jac-builder.jaseci.org/auth/callback` | SSO callback base |

### CI/CD Secrets (GitHub Actions)

| GitHub Secret | Maps To | Workflow |
|---|---|---|
| `GH_APP_CLIENT_ID_DEV` | `GITHUB_CLIENT_ID` | `deploy-dev.yml` |
| `GH_APP_CLIENT_SECRET_DEV` | `GITHUB_CLIENT_SECRET` | `deploy-dev.yml` |
| `GH_SSO_APP_SLUG` | `GITHUB_APP_SLUG` | both |
| `GH_REPO_CLIENT_ID_DEV` | `GITHUB_REPO_CLIENT_ID` | `deploy-dev.yml` |
| `GH_REPO_CLIENT_SECRET_DEV` | `GITHUB_REPO_CLIENT_SECRET` | `deploy-dev.yml` |
| `GH_SSO_CLIENT_ID_PROD` | `GITHUB_CLIENT_ID` | `deploy.yml` |
| `GH_SSO_CLIENT_SECRET_PROD` | `GITHUB_CLIENT_SECRET` | `deploy.yml` |
| `GH_REPO_CLIENT_ID_PROD` | `GITHUB_REPO_CLIENT_ID` | `deploy.yml` |
| `GH_REPO_CLIENT_SECRET_PROD` | `GITHUB_REPO_CLIENT_SECRET` | `deploy.yml` |
| `GH_TOKEN_ENCRYPTION_KEY` | `GITHUB_TOKEN_ENCRYPTION_KEY` | both |

---

## Verification

### Test locally:

1. Start the server:

   ```bash
   source ~/.jacvenv/bin/activate
   jac start main.jac
   ```

2. Go to `http://localhost:8000`, log in, create/open a project

3. In the Git panel, click **"Connect GitHub"**:
   - Redirects to GitHub OAuth consent page
   - Authorize the app
   - Redirected back to IDE with "GitHub connected successfully!"

4. Click **"Publish to GitHub"**:
   - Enter repo name, choose public/private
   - Click "Create & Push"
   - Repo created on GitHub and code pushed

5. Verify push/pull and create PR work after connection

### Troubleshoot:

| Error | Cause | Fix |
|---|---|---|
| "GitHub OAuth not configured" | `GITHUB_REPO_CLIENT_ID` or `GITHUB_REPO_CLIENT_SECRET` not set | Check `.env` has the Repo Ops OAuth App credentials |
| "Bad credentials" | OAuth token invalid or revoked | Disconnect and reconnect GitHub |
| "Repository not found" on push | System git credential helper intercepting | Fixed in code (`credential.helper=` override) |
| "Permission denied to {other-user}" | System git credential helper using wrong account | Fixed in code (`credential.helper=` override) |
| "No remote origin found" on PR | Project hasn't been pushed to GitHub yet | Push first via "Publish to GitHub" |
| Callback page shows error | Callback URL mismatch | Verify OAuth App callback URL matches `HOST` env var |
| SSO login fails | SSO OAuth App credentials wrong | Check `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` |

---

## Architecture

```
SSO Login Flow (SSO OAuth App — jac-scale):
  "Continue with GitHub" button
    --> /sso/github/callback (handled by jac-scale)
    --> JWT issued, user logged in

GitHub Connect Flow (Repo Ops OAuth App — jac-ide):
  "Connect GitHub" button (Git panel)
    |
    v
  Backend generates state token + OAuth URL
  (uses GITHUB_REPO_CLIENT_ID)
    |
    v
  GitHub OAuth consent page
  (scopes: repo, read:user, user:email)
    |
    v (redirect with code + state)
  /auth/github-connect callback page
    |
    v
  Backend exchanges code for access token
  (using GITHUB_REPO_CLIENT_ID + SECRET)
    |
    v
  Token stored encrypted on UserProfile node
    |
    v
  Ready for all operations:
    - Create repo   (POST /user/repos)
    - Push/Pull     (git via GIT_ASKPASS with token as username)
    - Clone         (git via GIT_ASKPASS)
    - Create PR     (POST /repos/{owner}/{repo}/pulls)
    - List repos    (GET /user/repos)
```

---

## Security Notes

1. **Client secrets**: Store in environment variables or secret manager, never in code.
2. **Token encryption**: Set `GITHUB_TOKEN_ENCRYPTION_KEY` in production to encrypt stored OAuth tokens at rest.
3. **OAuth App tokens**: Do not expire (unlike GitHub App tokens). Valid until user revokes.
4. **CSRF protection**: OAuth state tokens stored on user profile with 10-minute TTL, single-use.
5. **GIT_ASKPASS**: Credentials injected via temporary script with `0o700` permissions, cleaned up after use. Never embedded in URLs or git config.
6. **Credential helper override**: `git -c credential.helper=` disables system credential managers during IDE git operations to prevent wrong-account authentication.
