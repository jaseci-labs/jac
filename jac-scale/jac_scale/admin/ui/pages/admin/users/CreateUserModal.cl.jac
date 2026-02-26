"""Create user modal component."""

cl {
    import from ....components.common.Modal { Modal, ModalFooter }
    import from ....components.common.Button { Button }
    import from ....components.common.Input { Input }
    import from ....components.common.Select { Select }
    import from ....components.common.Alert { InlineAlert }
    import from ....constants.users { ROLE_OPTIONS }

    def:pub CreateUserModal(isOpen: bool, onClose: any, onCreate: any) -> JsxElement {
        has newUsername: str = "",
            newPassword: str = "",
            newRole: str = "user",
            createError: str = "";

        async def handleSubmit(e: any) -> None {
            e.preventDefault();
            createError = "";
            result = await onCreate(newUsername, newPassword, newRole);
            if result["ok"] {
                newUsername = "";
                newPassword = "";
                newRole = "user";
                onClose();
            } else {
                createError = result["error"];
            }
        }

        def handleClose -> None {
            newUsername = "";
            newPassword = "";
            newRole = "user";
            createError = "";
            onClose();
        }

        return
            <Modal isOpen={isOpen} onClose={handleClose} title="Create User">
                <form onSubmit={handleSubmit}>
                    <InlineAlert message={createError} type="error"/>
                    <Input
                        label="Username"
                        type="text"
                        value={newUsername}
                        onChange={lambda e: any  -> None { newUsername = e.target.value;}}
                        className="mb-3"
                    />
                    <Input
                        label="Password"
                        type="password"
                        value={newPassword}
                        onChange={lambda e: any  -> None { newPassword = e.target.value;}}
                        className="mb-3"
                    />
                    <Select
                        label="Role"
                        value={newRole}
                        onChange={lambda e: any  -> None { newRole = e.target.value;}}
                        options={ROLE_OPTIONS}
                        className="mb-4"
                    />
                    <ModalFooter>
                        <Button variant="ghost" onClick={handleClose}>
                            Cancel
                        </Button>
                        <Button type="submit">
                            Create
                        </Button>
                    </ModalFooter>
                </form>
            </Modal>;
    }
}
