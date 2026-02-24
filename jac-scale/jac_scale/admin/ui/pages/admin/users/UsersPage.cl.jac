"""Users management page."""

cl {
    import from react { useEffect }
    import from ....components.common.Button { Button }
    import from ....components.common.Card { Card, CardHeader, StatsCard }
    import from ....components.common.Badge { RoleBadge, StatusBadge }
    import from ....components.tables.DataTable { DataTable, TableRow, TableCell }
    import from ....context.AuthContext { useAuth }
    import from ....context.AlertContext { useAlert }
    import from ....services.userService {
        getUsers,
        createUser,
        updateUser,
        deleteUser,
        getSSOProviders
    }
    import from ....utils.api { getErrorMessage }
    import from .CreateUserModal { CreateUserModal }
    import from .EditUserModal { EditUserModal }
    def:pub UsersPage -> JsxElement {
        has users: list = [],
            ssoProviders: list = [],
            showCreateModal: bool = False,
            showEditModal: bool = False,
            editUsername: str = "",
            editRole: str = "user",
            editResetRequired: bool = False;

        auth = useAuth();
        alert = useAlert();

        async def loadUsers -> None {
            result = await getUsers(auth["authToken"]);
            if result["ok"] and result["data"] {
                users = result["data"]["users"];
            }
        }

        async def loadSSO -> None {
            result = await getSSOProviders(auth["authToken"]);
            if result["ok"] and result["data"] {
                ssoProviders = result["data"]["providers"];
            }
        }

        useEffect(lambda -> None { loadUsers();loadSSO();}, []);

        async def handleCreate(username: str, password: str, role: str) -> dict {
            result = await createUser(username, password, role, auth["authToken"]);
            if result["ok"] {
                alert["showAlert"]("User created", "success");
                loadUsers();
            }
            return {
                "ok": result["ok"],
                "error": getErrorMessage(result, "Failed to create user")
            };
        }

        async def handleUpdate(username: str, role: str, resetRequired: bool) -> dict {
            result = await updateUser(username, role, resetRequired, auth["authToken"]);
            if result["ok"] {
                alert["showAlert"]("User updated", "success");
                loadUsers();
            }
            return {
                "ok": result["ok"],
                "error": getErrorMessage(result, "Failed to update user")
            };
        }

        async def handleDelete(username: str) -> None {
            if not window.confirm("Delete user \"" + username + "\"?") {
                return;
            }
            result = await deleteUser(username, auth["authToken"]);
            if result["ok"] {
                alert["showAlert"]("User deleted", "success");
                loadUsers();
            } else {
                alert["showAlert"](
                    getErrorMessage(result, "Failed to delete user"), "error"
                );
            }
        }

        def openEditModal(username: str, role: str, resetRequired: bool) -> None {
            editUsername = username;
            editRole = role;
            editResetRequired = resetRequired;
            showEditModal = True;
        }

        def makeEditHandler(username: str, role: str, resetRequired: bool) -> any {
            return lambda e: any  -> None { openEditModal(
                username, role, resetRequired
            );};
        }

        def makeDeleteHandler(username: str) -> any {
            return lambda e: any  -> None { handleDelete(username);};
        }

        totalUsers = len(users);
        adminCount = len(
            [
                u
                for u in users
                if u["role"] == "admin"
            ]
        );
        ssoCount = len(
            [
                p
                for p in ssoProviders
                if p["configured"]
            ]
        );

        columns = [
            {"key": "username", "label": "Username"},
            {"key": "role", "label": "Role"},
            {"key": "status", "label": "Status"},
            {"key": "actions", "label": "Actions", "align": "right"}
        ];

        return
            <div>
                <div className="grid grid-cols-3 gap-3 mb-4">
                    <StatsCard label="Users" value={totalUsers} color="white"/>
                    <StatsCard label="Admins" value={adminCount} color="orange"/>
                    <StatsCard label="SSO Providers" value={ssoCount} color="emerald"/>
                </div>
                <Card className="overflow-hidden">
                    <CardHeader
                        title="Users"
                        action={<Button
                            onClick={lambda -> None { showCreateModal = True;}}
                        >
                            Add User
                        </Button>}
                    />
                    <DataTable columns={columns}>
                        {[
                            <TableRow key={u["username"]}>
                                <TableCell>
                                    <span className="text-sm text-white">
                                        {u["username"]}
                                    </span>
                                </TableCell>
                                <TableCell>
                                    <RoleBadge role={u["role"]}/>
                                </TableCell>
                                <TableCell>
                                    <StatusBadge
                                        active={not u["requires_password_reset"]}
                                        activeText="Active"
                                        inactiveText="Reset Required"
                                    />
                                </TableCell>
                                <TableCell align="right">
                                    <Button
                                        variant="ghost"
                                        onClick={makeEditHandler(
                                            u["username"],
                                            u["role"] or "user",
                                            u["requires_password_reset"] or False
                                        )}
                                        className="mr-3"
                                    >
                                        Edit
                                    </Button>
                                    <Button
                                        variant="link"
                                        onClick={makeDeleteHandler(u["username"])}
                                        className="text-red-500/70 hover:text-red-400"
                                    >
                                        Delete
                                    </Button>
                                </TableCell>
                            </TableRow> for u in users
                        ]}
                    </DataTable>
                </Card>
                <CreateUserModal
                    isOpen={showCreateModal}
                    onClose={lambda -> None { showCreateModal = False;}}
                    onCreate={handleCreate}
                />
                <EditUserModal
                    isOpen={showEditModal}
                    onClose={lambda -> None { showEditModal = False;}}
                    onUpdate={handleUpdate}
                    username={editUsername}
                    initialRole={editRole}
                    initialResetRequired={editResetRequired}
                />
            </div>;
    }
}
