"""Password reset page component."""

cl {
    import from ...components.common.Button { Button }
    import from ...components.common.Input { Input }
    import from ...components.common.Alert { InlineAlert }
    import from ...context.AuthContext { useAuth }

    glob MIN_PASSWORD_LENGTH = 8;

    def:pub ResetPage -> JsxElement {
        has resetCurrent: str = "",
            resetNew: str = "",
            resetConfirm: str = "",
            resetError: str = "";

        auth = useAuth();

        async def handleResetPassword(e: any) -> None {
            e.preventDefault();
            resetError = "";

            if resetNew != resetConfirm {
                resetError = "Passwords do not match";
                return;
            }
            if len(resetNew) < MIN_PASSWORD_LENGTH {
                resetError = "Password must be at least " + str(MIN_PASSWORD_LENGTH) + " characters";
                return;
            }

            result = await auth["resetPassword"](resetCurrent, resetNew);
            if not result["ok"] {
                resetError = result["error"];
            }
        }

        return
            <div
                className="min-h-screen bg-slate-950 flex items-center justify-center p-4"
            >
                <div className="w-full max-w-sm">
                    <div className="text-center mb-8">
                        <h1
                            className="text-xl font-semibold text-white tracking-tight"
                        >
                            Reset Password
                        </h1>
                        <p className="text-slate-500 text-sm mt-1">
                            Create a new password to continue
                        </p>
                    </div>
                    <div
                        className="bg-slate-900 border border-slate-800 rounded-lg p-6"
                    >
                        <InlineAlert message={resetError} type="error"/>
                        <form onSubmit={handleResetPassword}>
                            <Input
                                label="Current Password"
                                type="password"
                                value={resetCurrent}
                                onChange={lambda e: any  -> None { resetCurrent = e.target.value;}}
                                className="mb-4"
                            />
                            <Input
                                label="New Password"
                                type="password"
                                value={resetNew}
                                onChange={lambda e: any  -> None { resetNew = e.target.value;}}
                                placeholder="Min 8 characters"
                                className="mb-4"
                            />
                            <Input
                                label="Confirm Password"
                                type="password"
                                value={resetConfirm}
                                onChange={lambda e: any  -> None { resetConfirm = e.target.value;}}
                                className="mb-5"
                            />
                            <Button type="submit" className="w-full">
                                Update Password
                            </Button>
                        </form>
                    </div>
                </div>
            </div>;
    }
}
