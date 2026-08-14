"""User management service functions."""

import from .api { get, post, put, del }
async def:pub getUsers(token: str) -> dict[str, any] {
    return await get("/admin/users", token);
}

async def:pub createUser(
    username: str, password: str, role: str, token: str
) -> dict[str, any] {
    return await post(
        "/admin/users",
        {"username": username, "password": password, "role": role},
        token
    );
}

async def:pub updateUser(
    username: str, role: str, requiresReset: bool, token: str
) -> dict[str, any] {
    return await put(
        "/admin/users/" + encodeURIComponent(username),
        {"role": role, "requires_password_reset": requiresReset},
        token
    );
}

async def:pub deleteUser(username: str, token: str) -> dict[str, any] {
    return await del("/admin/users/" + encodeURIComponent(username), token);
}

async def:pub getSSOProviders(token: str) -> dict[str, any] {
    return await get("/admin/sso/providers", token);
}
