"""Authentication service functions."""

cl {
    import from .api { post, baseUrl }
    async def:pub loginUser(username: str, password: str) -> dict {
        return await post("/admin/login", {"username": username, "password": password});
    }

    async def:pub resetUserPassword(currentPwd: str, newPwd: str, token: str) -> dict {
        return await post("/admin/reset-password", {
            "current_password": currentPwd,
            "new_password": newPwd
        }, token);
    }
}
