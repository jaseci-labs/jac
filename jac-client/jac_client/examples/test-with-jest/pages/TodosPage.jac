cl import from "@jac-client/utils" { jacIsLoggedIn, jacLogout }
cl import from ..components.Button { Button }
cl import from ..components.Card { Card }

cl {
    def:pub TodosPage() -> any {
        if not jacIsLoggedIn() {
            return <div className="center">Please login</div>;
        }

        return <div className="center">
            <Card title="My Todos">
                <p>You are logged in 🎉</p>
                <Button
                    label="Logout"
                    onClick={lambda -> None { jacLogout(); }}
                />
            </Card>
        </div>;
    }
}
