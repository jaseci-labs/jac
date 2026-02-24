# Admin Portal for JAC-Scale

## Goal

Implement a Django-style admin portal at `/admin` with user management, role-based access, and administrative tools.

## Requirements

### Core Admin System

- [ ] Bootstrap admin user with UUID `00000000-0000-0000-0000-000000000000` if none exists
- [ ] Default admin credentials configurable via `jac.toml` under `[plugins.scale.admin]`
- [ ] Admin portal accessible at `/admin` route
- [ ] Secure admin authentication (separate from regular user auth)

### User Management Enhancements

- [ ] Add `is_password_required` field to user model
- [ ] Add `requires_password_reset` flag for:
  - Admin-created users (must reset on first login)
  - Admin user on first login
- [ ] Self-registered users: no password reset required
- [ ] Admin portal endpoints for user CRUD operations

### Role-Based Access Control (RBAC)

- [ ] Role model: `admin`, `moderator`, `user` (extensible)
- [ ] Permission model: granular permissions per role
- [ ] Middleware to enforce role-based access on endpoints
- [ ] Role assignment UI in admin portal

### SSO Management

- [ ] Admin UI to configure SSO providers
- [ ] Enable/disable SSO providers at runtime
- [ ] View/manage SSO-linked accounts

### Graph Visualizer

- [ ] Admin-accessible graph data explorer
- [ ] Extend existing `/graph/data` endpoint for admin access
- [ ] User graph browsing (view any user's graph as admin)

## Affected Files

### New Files

```
jac-scale/jac_scale/admin/
├── admin_portal.jac          # Admin portal routes & handlers
├── admin_user.jac            # Admin user bootstrap & management
├── rbac.jac                  # Role-based access control system
├── impl/
│   ├── admin_portal.impl.jac
│   ├── admin_user.impl.jac
│   └── rbac.impl.jac
└── static/
    └── admin/                # Admin UI assets (if serving static)
```

### Modified Files

| File | Changes |
|------|---------|
| `jac_scale/user_manager.jac` | Add `is_password_required`, `requires_password_reset` fields |
| `jac_scale/impl/user_manager.impl.jac` | Implement new user fields, admin user bootstrap |
| `jac_scale/serve.jac` | Include admin portal mixin |
| `jac_scale/impl/serve.core.impl.jac` | Mount `/admin` routes |
| `jac_scale/config_loader.jac` | Add admin config schema |
| `jac_scale/impl/config_loader.impl.jac` | Admin config defaults |
| `jac_scale/plugin_config.jac` | Register admin config section |

## Approach

### Phase 1: Foundation

1. Add admin config section to `jac.toml` schema
2. Extend user model with new fields (`is_password_required`, `requires_password_reset`, `role`)
3. Create admin user bootstrap logic (UUID all zeros, default credentials)
4. Add password reset flow endpoint

### Phase 2: RBAC

1. Define role and permission models
2. Create RBAC middleware for route protection
3. Add role assignment endpoints (admin-only)
4. Update JWT claims to include role

### Phase 3: Admin Portal

1. Create `/admin` route group with admin-only middleware
2. Implement user management endpoints:
    - `GET /admin/users` - List users
    - `POST /admin/users` - Create user (sets `requires_password_reset=true`)
    - `PUT /admin/users/{id}` - Update user
    - `DELETE /admin/users/{id}` - Delete user
    - `PUT /admin/users/{id}/role` - Assign role
3. Implement SSO management endpoints
4. Admin graph visualizer (extend existing `/graph/data`)

### Phase 4: Frontend (Optional)

1. Serve static admin UI at `/admin` (React/Vue SPA or simple HTML)
2. Or: document API-only approach for external admin UIs

## Configuration Schema

```toml
[plugins.scale.admin]
enabled = true
username = "admin"
email = "admin@localhost"
default_password = "changeme"  # Force reset on first login
session_expiry_hours = 24
```

## Open Questions

1. **Admin UI approach**:
   - Serve static SPA from jac-scale?
   - API-only with external UI?
   - Server-rendered templates (like Django)?

2. **Database storage**:
   - Extend SQLite users table with new columns?
   - Separate admin-specific MongoDB collection?
   - Both (SQLite for auth, MongoDB for admin data)?

3. **Role granularity**:
   - Fixed roles (admin/moderator/user)?
   - Custom roles with permission sets?
   - Resource-level permissions (per-walker/per-function)?

4. **Multi-tenancy**:
   - Single admin for entire system?
   - Per-tenant admin isolation?

5. **Audit logging**:
   - Track admin actions?
   - Store in separate collection/table?

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Default credentials in production | Critical - security breach | Force password reset, warn in logs if default password unchanged |
| Admin UUID collision | Low - intentional design | Document UUID `00000000...` is reserved |
| RBAC bypass | High - privilege escalation | Comprehensive middleware, test coverage |
| Breaking existing auth flow | High - user lockout | Feature flags, backwards compatibility |
| SSO config exposure | Medium - credential leak | Mask secrets in admin UI, encrypt at rest |
| Graph data exposure | High - data breach | Strict admin-only access, audit logging |

## Success Criteria

- Admin can login at `/admin` with configured credentials
- Admin can list/create/update/delete users
- Admin-created users must reset password on first login
- Roles can be assigned and enforced on endpoints
- SSO providers configurable from admin portal
- Graph visualizer accessible to admin for any user
