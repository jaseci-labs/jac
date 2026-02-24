"""Header component with logo and user menu."""

cl {
    import from ..common.Button { Button }

    def:pub Header(username: str, onLogout: any) -> JsxElement {
        return
            <div className="flex items-center justify-between px-4 h-12">
                <h1 className="text-sm font-semibold text-white">
                    JAC Admin
                </h1>
                <div className="flex items-center gap-3">
                    <span className="text-sm text-slate-400">
                        {username}
                    </span>
                    <Button onClick={onLogout} variant="link">
                        Logout
                    </Button>
                </div>
            </div>;
    }
}
