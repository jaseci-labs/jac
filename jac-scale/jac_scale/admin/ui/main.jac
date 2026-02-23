"""JAC-Scale Admin Portal."""

cl import "./styles/main.css";
cl import from react { useEffect }

cl {
    def:pub app() -> JsxElement {
        # Auth state
        has authToken: str = "",
            currentUsername: str = "",
            tempToken: str = "",
            isLoading: bool = True,
            view: str = "login",
            loginUsername: str = "",
            loginPassword: str = "",
            loginError: str = "",
            resetCurrent: str = "",
            resetNew: str = "",
            resetConfirm: str = "",
            resetError: str = "";

        # Tab state
        has activeTab: str = "authentication",
            authSubTab: str = "users";

        # Data state
        has users: list = [],
            ssoProviders: list = [],
            logs: list = [],
            envVars: dict = {},
            tomlConfig: str = "";

        # UI state
        has showCreateModal: bool = False,
            newUsername: str = "",
            newPassword: str = "",
            newRole: str = "user",
            createError: str = "",
            showEditModal: bool = False,
            editUsername: str = "",
            editRole: str = "user",
            editResetPassword: bool = False,
            editError: str = "",
            mainAlert: str = "",
            mainAlertType: str = "";

        baseUrl = window.location.origin;

        # Storage helpers
        def getStorage(key: str) -> str {
            storage = globalThis.localStorage;
            if storage {
                val = storage.getItem(key);
                return val if val else "";
            }
            return "";
        }

        def setStorage(key: str, value: str) -> None {
            storage = globalThis.localStorage;
            if storage {
                storage.setItem(key, value);
            }
        }

        def removeStorage(key: str) -> None {
            storage = globalThis.localStorage;
            if storage {
                storage.removeItem(key);
            }
        }

        # Data loading
        async def loadSSO(token: str = "") -> None {
            tkn = token or authToken;
            try {
                resp = await fetch(baseUrl + "/admin/sso/providers", {
                    "headers": {"Authorization": "Bearer " + tkn}
                });
                data = await resp.json();
                if data["ok"] and data["data"] {
                    ssoProviders = data["data"]["providers"];
                }
            } except Exception as e {
                console.error("Failed to load SSO:", e);
            }
        }

        async def loadUsers(token: str = "") -> None {
            tkn = token or authToken;
            try {
                resp = await fetch(baseUrl + "/admin/users", {
                    "headers": {"Authorization": "Bearer " + tkn}
                });
                data = await resp.json();
                if data["ok"] and data["data"] {
                    users = data["data"]["users"];
                }
            } except Exception as e {
                console.error("Failed to load users:", e);
            }
        }

        async def loadData(token: str = "") -> None {
            tkn = token or authToken;
            await loadUsers(tkn);
            await loadSSO(tkn);
        }

        async def validateAndRestoreSession(token: str, username: str) -> None {
            try {
                resp = await fetch(baseUrl + "/admin/users", {
                    "headers": {"Authorization": "Bearer " + token}
                });
                data = await resp.json();
                if data["ok"] {
                    authToken = token;
                    currentUsername = username;
                    view = "admin";
                    if data["data"] {
                        users = data["data"]["users"];
                    }
                    await loadSSO(token);
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

        useEffect(lambda -> None {
            storage = globalThis.localStorage;
            if storage {
                stored_token = storage.getItem("admin_token");
                stored_user = storage.getItem("admin_username");
                if stored_token and stored_user {
                    validateAndRestoreSession(stored_token, stored_user);
                } else {
                    isLoading = False;
                }
            } else {
                isLoading = False;
            }
        }, []);

        # Auth handlers
        async def handleLogin(e: any) -> None {
            e.preventDefault();
            loginError = "";
            try {
                resp = await fetch(baseUrl + "/admin/login", {
                    "method": "POST",
                    "headers": {"Content-Type": "application/json"},
                    "body": JSON.stringify({"username": loginUsername, "password": loginPassword})
                });
                data = await resp.json();
                if data["ok"] and data["data"] {
                    if data["data"]["requires_password_reset"] {
                        tempToken = data["data"]["token"];
                        currentUsername = loginUsername;
                        view = "reset";
                    } else {
                        token = data["data"]["token"];
                        authToken = token;
                        currentUsername = loginUsername;
                        setStorage("admin_token", token);
                        setStorage("admin_username", currentUsername);
                        view = "admin";
                        loadData(token);
                    }
                } else {
                    loginError = (data["error"] and data["error"]["message"]) or "Login failed";
                }
            } except Exception as e {
                loginError = "Connection error: " + str(e);
            }
        }

        async def handleResetPassword(e: any) -> None {
            e.preventDefault();
            resetError = "";
            if resetNew != resetConfirm {
                resetError = "Passwords do not match";
                return;
            }
            if len(resetNew) < 8 {
                resetError = "Password must be at least 8 characters";
                return;
            }
            try {
                resp = await fetch(baseUrl + "/admin/reset-password", {
                    "method": "POST",
                    "headers": {
                        "Content-Type": "application/json",
                        "Authorization": "Bearer " + tempToken
                    },
                    "body": JSON.stringify({"current_password": resetCurrent, "new_password": resetNew})
                });
                data = await resp.json();
                if data["ok"] and data["data"] {
                    token = data["data"]["token"];
                    authToken = token;
                    setStorage("admin_token", token);
                    setStorage("admin_username", currentUsername);
                    tempToken = "";
                    view = "admin";
                    loadData(token);
                } else {
                    resetError = (data["error"] and data["error"]["message"]) or "Password reset failed";
                }
            } except Exception as e {
                resetError = "Connection error: " + str(e);
            }
        }

        def handleLogout() -> None {
            authToken = "";
            currentUsername = "";
            removeStorage("admin_token");
            removeStorage("admin_username");
            view = "login";
        }

        # User management handlers
        async def handleCreateUser(e: any) -> None {
            e.preventDefault();
            createError = "";
            try {
                resp = await fetch(baseUrl + "/admin/users", {
                    "method": "POST",
                    "headers": {
                        "Content-Type": "application/json",
                        "Authorization": "Bearer " + authToken
                    },
                    "body": JSON.stringify({"username": newUsername, "password": newPassword, "role": newRole})
                });
                data = await resp.json();
                if data["ok"] {
                    showCreateModal = False;
                    newUsername = "";
                    newPassword = "";
                    newRole = "user";
                    showAlert("User created", "success");
                    loadUsers();
                } else {
                    createError = (data["error"] and data["error"]["message"]) or "Failed to create user";
                }
            } except Exception as e {
                createError = "Connection error: " + str(e);
            }
        }

        async def handleUpdateUser(e: any) -> None {
            e.preventDefault();
            editError = "";
            try {
                resp = await fetch(baseUrl + "/admin/users/" + encodeURIComponent(editUsername), {
                    "method": "PUT",
                    "headers": {
                        "Content-Type": "application/json",
                        "Authorization": "Bearer " + authToken
                    },
                    "body": JSON.stringify({"role": editRole, "requires_password_reset": editResetPassword})
                });
                data = await resp.json();
                if data["ok"] {
                    showEditModal = False;
                    showAlert("User updated", "success");
                    loadUsers();
                } else {
                    editError = (data["error"] and data["error"]["message"]) or "Failed to update user";
                }
            } except Exception as e {
                editError = "Connection error: " + str(e);
            }
        }

        async def handleDeleteUser(username: str) -> None {
            if not window.confirm("Delete user \"" + username + "\"?") {
                return;
            }
            try {
                resp = await fetch(baseUrl + "/admin/users/" + encodeURIComponent(username), {
                    "method": "DELETE",
                    "headers": {"Authorization": "Bearer " + authToken}
                });
                data = await resp.json();
                if data["ok"] {
                    showAlert("User deleted", "success");
                    loadUsers();
                } else {
                    showAlert((data["error"] and data["error"]["message"]) or "Failed to delete user", "error");
                }
            } except Exception as e {
                showAlert("Connection error: " + str(e), "error");
            }
        }

        def showAlert(message: str, alertType: str) -> None {
            mainAlert = message;
            mainAlertType = alertType;
            setTimeout(lambda -> None { mainAlert = ""; }, 3000);
        }

        def openEditModal(username: str, role: str, requiresReset: bool) -> None {
            editUsername = username;
            editRole = role;
            editResetPassword = requiresReset;
            editError = "";
            showEditModal = True;
        }

        def openCreateModal() -> None {
            newUsername = "";
            newPassword = "";
            newRole = "user";
            createError = "";
            showCreateModal = True;
        }

        def makeEditHandler(username: str, role: str, requiresReset: bool) -> any {
            return lambda e: any -> None {
                openEditModal(username, role, requiresReset);
            };
        }

        def makeDeleteHandler(username: str) -> any {
            return lambda e: any -> None {
                handleDeleteUser(username);
            };
        }

        def makeTabHandler(tabId: str) -> any {
            return lambda e: any -> None {
                activeTab = tabId;
            };
        }

        # Tab definitions
        tabs = [
            {"id": "authentication", "label": "Authentication"},
            {"id": "graph", "label": "Graph"},
            {"id": "observability", "label": "Observability"},
            {"id": "logs", "label": "Logs"},
            {"id": "environment", "label": "Environment"},
            {"id": "config", "label": "Configuration"}
        ];

        # Calculate stats
        totalUsers = len(users);
        adminCount = len([u for u in users if u["role"] == "admin"]);
        ssoCount = len([p for p in ssoProviders if p["configured"]]);

        # Loading state
        if isLoading {
            return <div className="min-h-screen bg-slate-950 flex items-center justify-center">
                <div className="text-center">
                    <div className="w-8 h-8 border-2 border-orange-500 border-t-transparent rounded-full animate-spin mx-auto mb-3"></div>
                    <p className="text-slate-400 text-sm">Loading</p>
                </div>
            </div>;
        }

        # Login page
        if view == "login" {
            return <div className="min-h-screen bg-slate-950 flex items-center justify-center p-4">
                <div className="w-full max-w-sm">
                    <div className="text-center mb-8">
                        <h1 className="text-xl font-semibold text-white tracking-tight">JAC Admin</h1>
                        <p className="text-slate-500 text-sm mt-1">Sign in to continue</p>
                    </div>
                    <div className="bg-slate-900 border border-slate-800 rounded-lg p-6">
                        {loginError and <div className="bg-red-500/10 border border-red-500/20 text-red-400 px-3 py-2 rounded text-sm mb-4">{loginError}</div>}
                        <form onSubmit={handleLogin}>
                            <div className="mb-4">
                                <label className="block text-xs font-medium text-slate-400 mb-1.5 uppercase tracking-wider">Username</label>
                                <input
                                    type="text"
                                    value={loginUsername}
                                    onChange={lambda e: any -> None { loginUsername = e.target.value; }}
                                    className="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded text-white text-sm placeholder-slate-600 focus:outline-none focus:border-orange-500 focus:ring-1 focus:ring-orange-500 transition"
                                    placeholder="admin"
                                />
                            </div>
                            <div className="mb-5">
                                <label className="block text-xs font-medium text-slate-400 mb-1.5 uppercase tracking-wider">Password</label>
                                <input
                                    type="password"
                                    value={loginPassword}
                                    onChange={lambda e: any -> None { loginPassword = e.target.value; }}
                                    className="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded text-white text-sm placeholder-slate-600 focus:outline-none focus:border-orange-500 focus:ring-1 focus:ring-orange-500 transition"
                                    placeholder="Enter password"
                                />
                            </div>
                            <button
                                type="submit"
                                className="w-full bg-orange-500 hover:bg-orange-600 text-white text-sm font-medium py-2 px-4 rounded transition"
                            >
                                Sign In
                            </button>
                        </form>
                    </div>
                </div>
            </div>;
        }

        # Password reset page
        if view == "reset" {
            return <div className="min-h-screen bg-slate-950 flex items-center justify-center p-4">
                <div className="w-full max-w-sm">
                    <div className="text-center mb-8">
                        <h1 className="text-xl font-semibold text-white tracking-tight">Reset Password</h1>
                        <p className="text-slate-500 text-sm mt-1">Create a new password to continue</p>
                    </div>
                    <div className="bg-slate-900 border border-slate-800 rounded-lg p-6">
                        {resetError and <div className="bg-red-500/10 border border-red-500/20 text-red-400 px-3 py-2 rounded text-sm mb-4">{resetError}</div>}
                        <form onSubmit={handleResetPassword}>
                            <div className="mb-4">
                                <label className="block text-xs font-medium text-slate-400 mb-1.5 uppercase tracking-wider">Current Password</label>
                                <input
                                    type="password"
                                    value={resetCurrent}
                                    onChange={lambda e: any -> None { resetCurrent = e.target.value; }}
                                    className="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded text-white text-sm placeholder-slate-600 focus:outline-none focus:border-orange-500 focus:ring-1 focus:ring-orange-500 transition"
                                />
                            </div>
                            <div className="mb-4">
                                <label className="block text-xs font-medium text-slate-400 mb-1.5 uppercase tracking-wider">New Password</label>
                                <input
                                    type="password"
                                    value={resetNew}
                                    onChange={lambda e: any -> None { resetNew = e.target.value; }}
                                    className="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded text-white text-sm placeholder-slate-600 focus:outline-none focus:border-orange-500 focus:ring-1 focus:ring-orange-500 transition"
                                    placeholder="Min 8 characters"
                                />
                            </div>
                            <div className="mb-5">
                                <label className="block text-xs font-medium text-slate-400 mb-1.5 uppercase tracking-wider">Confirm Password</label>
                                <input
                                    type="password"
                                    value={resetConfirm}
                                    onChange={lambda e: any -> None { resetConfirm = e.target.value; }}
                                    className="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded text-white text-sm placeholder-slate-600 focus:outline-none focus:border-orange-500 focus:ring-1 focus:ring-orange-500 transition"
                                />
                            </div>
                            <button
                                type="submit"
                                className="w-full bg-orange-500 hover:bg-orange-600 text-white text-sm font-medium py-2 px-4 rounded transition"
                            >
                                Update Password
                            </button>
                        </form>
                    </div>
                </div>
            </div>;
        }

        # Admin Dashboard
        return <div className="min-h-screen bg-slate-950">
            <header className="bg-slate-900 border-b border-slate-800">
                <div className="flex items-center justify-between px-4 h-14">
                    <h1 className="text-sm font-semibold text-white">JAC Admin</h1>
                    <div className="flex items-center gap-3">
                        <span className="text-sm text-slate-400">{currentUsername}</span>
                        <button
                            onClick={lambda -> None { handleLogout(); }}
                            className="text-sm text-slate-500 hover:text-white transition"
                        >
                            Logout
                        </button>
                    </div>
                </div>
                <div className="flex px-4 gap-0.5 border-t border-slate-800">
                    {[<button
                        key={tab["id"]}
                        onClick={makeTabHandler(tab["id"])}
                        className={"px-3 py-2.5 text-xs font-medium transition " +
                            (activeTab == tab["id"]
                                and "text-orange-500 border-b-2 border-orange-500 -mb-px"
                                or "text-slate-500 hover:text-slate-300")}
                    >
                        {tab["label"]}
                    </button> for tab in tabs]}
                </div>
            </header>

            {mainAlert and <div className={"fixed top-4 right-4 z-50 px-4 py-2 rounded text-sm font-medium " +
                (mainAlertType == "success" and "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30" or "bg-red-500/20 text-red-400 border border-red-500/30")}>
                {mainAlert}
            </div>}

            <main className="p-4">
                {activeTab == "authentication" and <div>
                    <div className="flex gap-1 mb-4">
                        <button
                            onClick={lambda -> None { authSubTab = "users"; }}
                            className={"px-3 py-1.5 rounded text-xs font-medium transition " +
                                (authSubTab == "users"
                                    and "bg-slate-800 text-white"
                                    or "text-slate-500 hover:text-slate-300")}
                        >
                            Users
                        </button>
                        <button
                            onClick={lambda -> None { authSubTab = "sso"; }}
                            className={"px-3 py-1.5 rounded text-xs font-medium transition " +
                                (authSubTab == "sso"
                                    and "bg-slate-800 text-white"
                                    or "text-slate-500 hover:text-slate-300")}
                        >
                            SSO
                        </button>
                    </div>

                    <div className="grid grid-cols-3 gap-3 mb-4">
                        <div className="bg-slate-900 border border-slate-800 rounded-lg p-4">
                            <p className="text-xs text-slate-500 uppercase tracking-wider">Users</p>
                            <p className="text-2xl font-semibold text-white mt-1">{totalUsers}</p>
                        </div>
                        <div className="bg-slate-900 border border-slate-800 rounded-lg p-4">
                            <p className="text-xs text-slate-500 uppercase tracking-wider">Admins</p>
                            <p className="text-2xl font-semibold text-orange-500 mt-1">{adminCount}</p>
                        </div>
                        <div className="bg-slate-900 border border-slate-800 rounded-lg p-4">
                            <p className="text-xs text-slate-500 uppercase tracking-wider">SSO</p>
                            <p className="text-2xl font-semibold text-emerald-500 mt-1">{ssoCount}</p>
                        </div>
                    </div>

                    {authSubTab == "users" and <div className="bg-slate-900 border border-slate-800 rounded-lg overflow-hidden">
                        <div className="flex items-center justify-between px-4 py-3 border-b border-slate-800">
                            <h2 className="text-sm font-medium text-white">Users</h2>
                            <button
                                onClick={lambda -> None { openCreateModal(); }}
                                className="px-3 py-1.5 bg-orange-500 hover:bg-orange-600 text-white text-xs font-medium rounded transition"
                            >
                                Add User
                            </button>
                        </div>
                        <table className="w-full">
                            <thead>
                                <tr className="border-b border-slate-800">
                                    <th className="text-left px-4 py-2 text-xs font-medium text-slate-500 uppercase tracking-wider">Username</th>
                                    <th className="text-left px-4 py-2 text-xs font-medium text-slate-500 uppercase tracking-wider">Role</th>
                                    <th className="text-left px-4 py-2 text-xs font-medium text-slate-500 uppercase tracking-wider">Status</th>
                                    <th className="text-right px-4 py-2 text-xs font-medium text-slate-500 uppercase tracking-wider">Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {[<tr key={u["username"]} className="border-b border-slate-800/50 hover:bg-slate-800/30">
                                    <td className="px-4 py-3">
                                        <span className="text-sm text-white">{u["username"]}</span>
                                    </td>
                                    <td className="px-4 py-3">
                                        <span className={"px-2 py-0.5 text-xs font-medium rounded " +
                                            (u["role"] == "admin"
                                                and "bg-purple-500/20 text-purple-400"
                                                or (u["role"] == "moderator"
                                                    and "bg-blue-500/20 text-blue-400"
                                                    or "bg-slate-700 text-slate-400"))}>
                                            {u["role"] or "user"}
                                        </span>
                                    </td>
                                    <td className="px-4 py-3">
                                        {u["requires_password_reset"]
                                            and <span className="text-xs text-amber-400">Reset Required</span>
                                            or <span className="text-xs text-emerald-400">Active</span>}
                                    </td>
                                    <td className="px-4 py-3 text-right">
                                        <button
                                            onClick={makeEditHandler(u["username"], u["role"] or "user", u["requires_password_reset"] or False)}
                                            className="text-slate-500 hover:text-white text-xs mr-3 transition"
                                        >
                                            Edit
                                        </button>
                                        <button
                                            onClick={makeDeleteHandler(u["username"])}
                                            className="text-red-500/70 hover:text-red-400 text-xs transition"
                                        >
                                            Delete
                                        </button>
                                    </td>
                                </tr> for u in users]}
                            </tbody>
                        </table>
                    </div>}

                    {authSubTab == "sso" and <div className="bg-slate-900 border border-slate-800 rounded-lg overflow-hidden">
                        <div className="px-4 py-3 border-b border-slate-800">
                            <h2 className="text-sm font-medium text-white">SSO Providers</h2>
                        </div>
                        <table className="w-full">
                            <thead>
                                <tr className="border-b border-slate-800">
                                    <th className="text-left px-4 py-2 text-xs font-medium text-slate-500 uppercase tracking-wider">Provider</th>
                                    <th className="text-left px-4 py-2 text-xs font-medium text-slate-500 uppercase tracking-wider">Status</th>
                                    <th className="text-left px-4 py-2 text-xs font-medium text-slate-500 uppercase tracking-wider">Client ID</th>
                                    <th className="text-left px-4 py-2 text-xs font-medium text-slate-500 uppercase tracking-wider">Secret</th>
                                </tr>
                            </thead>
                            <tbody>
                                {[<tr key={p["platform"]} className="border-b border-slate-800/50 hover:bg-slate-800/30">
                                    <td className="px-4 py-3">
                                        <span className="text-sm text-white capitalize">{p["platform"]}</span>
                                    </td>
                                    <td className="px-4 py-3">
                                        {p["configured"]
                                            and <span className="text-xs text-emerald-400">Configured</span>
                                            or <span className="text-xs text-slate-500">Not configured</span>}
                                    </td>
                                    <td className="px-4 py-3">
                                        <span className={"text-xs " + (p["client_id_set"] and "text-emerald-400" or "text-slate-600")}>
                                            {p["client_id_set"] and "Set" or "Not set"}
                                        </span>
                                    </td>
                                    <td className="px-4 py-3">
                                        <span className={"text-xs " + (p["client_secret_set"] and "text-emerald-400" or "text-slate-600")}>
                                            {p["client_secret_set"] and "Set" or "Not set"}
                                        </span>
                                    </td>
                                </tr> for p in ssoProviders]}
                            </tbody>
                        </table>
                    </div>}
                </div>}

                {activeTab == "graph" and <div className="bg-slate-900 border border-slate-800 rounded-lg p-8 text-center">
                    <h2 className="text-sm font-medium text-white mb-1">Graph Explorer</h2>
                    <p className="text-xs text-slate-500">Coming soon</p>
                </div>}

                {activeTab == "observability" and <div className="bg-slate-900 border border-slate-800 rounded-lg p-8 text-center">
                    <h2 className="text-sm font-medium text-white mb-1">Observability</h2>
                    <p className="text-xs text-slate-500">Coming soon</p>
                </div>}

                {activeTab == "logs" and <div className="bg-slate-900 border border-slate-800 rounded-lg p-8 text-center">
                    <h2 className="text-sm font-medium text-white mb-1">Logs</h2>
                    <p className="text-xs text-slate-500">Coming soon</p>
                </div>}

                {activeTab == "environment" and <div className="bg-slate-900 border border-slate-800 rounded-lg p-8 text-center">
                    <h2 className="text-sm font-medium text-white mb-1">Environment</h2>
                    <p className="text-xs text-slate-500">Coming soon</p>
                </div>}

                {activeTab == "config" and <div className="bg-slate-900 border border-slate-800 rounded-lg p-8 text-center">
                    <h2 className="text-sm font-medium text-white mb-1">Configuration</h2>
                    <p className="text-xs text-slate-500">Coming soon</p>
                </div>}
            </main>

            {showCreateModal and <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
                <div className="bg-slate-900 border border-slate-800 rounded-lg w-full max-w-sm">
                    <div className="px-4 py-3 border-b border-slate-800">
                        <h2 className="text-sm font-medium text-white">Create User</h2>
                    </div>
                    <form onSubmit={handleCreateUser} className="p-4">
                        {createError and <div className="bg-red-500/10 border border-red-500/20 text-red-400 px-3 py-2 rounded text-xs mb-4">{createError}</div>}
                        <div className="mb-3">
                            <label className="block text-xs font-medium text-slate-400 mb-1.5 uppercase tracking-wider">Username</label>
                            <input
                                type="text"
                                value={newUsername}
                                onChange={lambda e: any -> None { newUsername = e.target.value; }}
                                className="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded text-white text-sm focus:outline-none focus:border-orange-500 transition"
                            />
                        </div>
                        <div className="mb-3">
                            <label className="block text-xs font-medium text-slate-400 mb-1.5 uppercase tracking-wider">Password</label>
                            <input
                                type="password"
                                value={newPassword}
                                onChange={lambda e: any -> None { newPassword = e.target.value; }}
                                className="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded text-white text-sm focus:outline-none focus:border-orange-500 transition"
                            />
                        </div>
                        <div className="mb-4">
                            <label className="block text-xs font-medium text-slate-400 mb-1.5 uppercase tracking-wider">Role</label>
                            <select
                                value={newRole}
                                onChange={lambda e: any -> None { newRole = e.target.value; }}
                                className="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded text-white text-sm focus:outline-none focus:border-orange-500 transition"
                            >
                                <option value="user">User</option>
                                <option value="moderator">Moderator</option>
                                <option value="admin">Admin</option>
                            </select>
                        </div>
                        <div className="flex gap-2 justify-end">
                            <button
                                type="button"
                                onClick={lambda -> None { showCreateModal = False; }}
                                className="px-3 py-1.5 text-slate-400 hover:text-white text-xs font-medium transition"
                            >
                                Cancel
                            </button>
                            <button
                                type="submit"
                                className="px-3 py-1.5 bg-orange-500 hover:bg-orange-600 text-white text-xs font-medium rounded transition"
                            >
                                Create
                            </button>
                        </div>
                    </form>
                </div>
            </div>}

            {showEditModal and <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
                <div className="bg-slate-900 border border-slate-800 rounded-lg w-full max-w-sm">
                    <div className="px-4 py-3 border-b border-slate-800">
                        <h2 className="text-sm font-medium text-white">Edit {editUsername}</h2>
                    </div>
                    <form onSubmit={handleUpdateUser} className="p-4">
                        {editError and <div className="bg-red-500/10 border border-red-500/20 text-red-400 px-3 py-2 rounded text-xs mb-4">{editError}</div>}
                        <div className="mb-3">
                            <label className="block text-xs font-medium text-slate-400 mb-1.5 uppercase tracking-wider">Role</label>
                            <select
                                value={editRole}
                                onChange={lambda e: any -> None { editRole = e.target.value; }}
                                className="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded text-white text-sm focus:outline-none focus:border-orange-500 transition"
                            >
                                <option value="user">User</option>
                                <option value="moderator">Moderator</option>
                                <option value="admin">Admin</option>
                            </select>
                        </div>
                        <div className="mb-4">
                            <label className="flex items-center gap-2 cursor-pointer">
                                <input
                                    type="checkbox"
                                    checked={editResetPassword}
                                    onChange={lambda e: any -> None { editResetPassword = e.target.checked; }}
                                    className="w-4 h-4 rounded border-slate-600 bg-slate-950 text-orange-500 focus:ring-orange-500 focus:ring-offset-0"
                                />
                                <span className="text-xs text-slate-400">Require password reset</span>
                            </label>
                        </div>
                        <div className="flex gap-2 justify-end">
                            <button
                                type="button"
                                onClick={lambda -> None { showEditModal = False; }}
                                className="px-3 py-1.5 text-slate-400 hover:text-white text-xs font-medium transition"
                            >
                                Cancel
                            </button>
                            <button
                                type="submit"
                                className="px-3 py-1.5 bg-orange-500 hover:bg-orange-600 text-white text-xs font-medium rounded transition"
                            >
                                Save
                            </button>
                        </div>
                    </form>
                </div>
            </div>}
        </div>;
    }
}
