"""Authentication context provider."""

cl {
    import from react { createContext, useContext, useEffect }
    import from ..hooks.useStorage { getStorage, setStorage, removeStorage }
    import from ..services.api { baseUrl }
    import from ..utils.api { getErrorMessage }

    glob:pub AuthContext = createContext(None);

    def:pub AuthProvider(children: any) -> JsxElement {
        has authToken: str = "",
            currentUsername: str = "",
            tempToken: str = "",
            isLoading: bool = True,
            view: str = "login";

        async def validateAndRestoreSession(token: str, username: str) -> None {
            try {
                resp = await fetch(
                    baseUrl + "/admin/users",
                    {"headers": {"Authorization": "Bearer " + token}}
                );
                data = await resp.json();
                if data["ok"] {
                    authToken = token;
                    currentUsername = username;
                    view = "admin";
                } else {
                    removeStorage("admin_token");
                    removeStorage("admin_username");
                }
            } except Exception as e {
                console.error("Session validation failed:", e);
                removeStorage("admin_token");
                removeStorage("admin_username");
            }
            isLoading = False;
        }

        async def login(username: str, password: str) -> dict {
            try {
                resp = await fetch(
                    baseUrl + "/admin/login",
                    {
                        "method": "POST",
                        "headers": {"Content-Type": "application/json"},
                        "body": JSON.stringify(
                            {"username": username, "password": password}
                        )
                    }
                );
                data = await resp.json();
                if data["ok"] and data["data"] {
                    if data["data"]["requires_password_reset"] {
                        tempToken = data["data"]["token"];
                        currentUsername = username;
                        view = "reset";
                        return {"ok": True, "requiresReset": True};
                    } else {
                        token = data["data"]["token"];
                        authToken = token;
                        currentUsername = username;
                        setStorage("admin_token", token);
                        setStorage("admin_username", username);
                        view = "admin";
                        return {"ok": True};
                    }
                }
                return {"ok": False, "error": getErrorMessage(data, "Login failed")};
            } except Exception as e {
                return {"ok": False, "error": "Connection error: " + str(e)};
            }
        }

        async def resetPassword(currentPwd: str, newPwd: str) -> dict {
            try {
                resp = await fetch(
                    baseUrl + "/admin/reset-password",
                    {
                        "method": "POST",
                        "headers": {
                            "Content-Type": "application/json",
                            "Authorization": "Bearer " + tempToken
                        },
                        "body": JSON.stringify(
                            {"current_password": currentPwd, "new_password": newPwd}
                        )
                    }
                );
                data = await resp.json();
                if data["ok"] and data["data"] {
                    token = data["data"]["token"];
                    authToken = token;
                    setStorage("admin_token", token);
                    setStorage("admin_username", currentUsername);
                    tempToken = "";
                    view = "admin";
                    return {"ok": True};
                }
                return {
                    "ok": False,
                    "error": getErrorMessage(data, "Password reset failed")
                };
            } except Exception as e {
                return {"ok": False, "error": "Connection error: " + str(e)};
            }
        }

        def logout -> None {
            authToken = "";
            currentUsername = "";
            removeStorage("admin_token");
            removeStorage("admin_username");
            view = "login";
        }

        useEffect(
            lambda -> None { stored_token = getStorage("admin_token");stored_user = getStorage(
                "admin_username"
            );if stored_token and stored_user {
                validateAndRestoreSession(stored_token, stored_user);
            } else {
                isLoading = False;
            } },
            []
        );

        value = {
            "authToken": authToken,
            "currentUsername": currentUsername,
            "isLoading": isLoading,
            "view": view,
            "login": login,
            "resetPassword": resetPassword,
            "logout": logout
        };

        return
            <AuthContext.Provider value={value}>
                {children}
            </AuthContext.Provider>;
    }

    def:pub useAuth -> dict {
        return useContext(AuthContext);
    }
}
