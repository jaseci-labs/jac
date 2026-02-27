"""Edit user modal component."""

cl {
    import from ....components.common.Modal { Modal, ModalFooter }
    import from ....components.common.Button { Button }
    import from ....components.common.Select { Select }
    import from ....components.common.Alert { InlineAlert }
    import from ....constants.users { ROLE_OPTIONS }

    def:pub EditUserModal(
        isOpen: bool,
        onClose: any,
        onUpdate: any,
        username: str,
        initialRole: str,
        initialResetRequired: bool
    ) -> JsxElement {
        has editRole: str = initialRole,
            editResetPassword: bool = initialResetRequired,
            editError: str = "";

        async def handleSubmit(e: any) -> None {
            e.preventDefault();
            editError = "";
            result = await onUpdate(username, editRole, editResetPassword);
            if result["ok"] {
                onClose();
            } else {
                editError = result["error"];
            }
        }

        def handleClose -> None {
            editError = "";
            onClose();
        }

        return
            <Modal isOpen={isOpen} onClose={handleClose} title={"Edit " + username}>
                <form onSubmit={handleSubmit}>
                    <InlineAlert message={editError} type="error"/>
                    <Select
                        label="Role"
                        value={editRole}
                        onChange={lambda e: any  -> None { editRole = e.target.value;}}
                        options={ROLE_OPTIONS}
                        className="mb-3"
                    />
                    <div className="mb-4">
                        <label className="flex items-center gap-2 cursor-pointer">
                            <input
                                type="checkbox"
                                checked={editResetPassword}
                                onChange={lambda e: any  -> None { editResetPassword = e.target.checked;}}
                                className="w-4 h-4 rounded border-slate-600 bg-slate-950 text-orange-500 focus:ring-orange-500 focus:ring-offset-0"
                            />
                            <span className="text-xs text-slate-400">
                                Require password reset
                            </span>
                        </label>
                    </div>
                    <ModalFooter>
                        <Button variant="ghost" onClick={handleClose}>
                            Cancel
                        </Button>
                        <Button type="submit">
                            Save
                        </Button>
                    </ModalFooter>
                </form>
            </Modal>;
    }
}
