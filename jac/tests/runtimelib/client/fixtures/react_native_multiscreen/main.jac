"""Multi-screen React Native fixture: login -> list -> detail.

Exercises AuthGuard-protected routes, JacForm login, walker calls, and
dynamic route params for dual-target gate tests.
"""
walker:pub whoami {
    can check with Root entry {
        report "anonymous";
    }
}

cl {
    import from '@jac/runtime' {
        Router,
        Routes,
        Route,
        AuthGuard,
        JacForm,
        JacSchema,
        Link,
        jacLogin
    }

    def:pub LoginPage -> JsxElement {
        schema = JacSchema(
            {
                username: JacSchema.string().min(1, "Username required"),
                password: JacSchema.string().min(1, "Password required")
            }
        );

        async def handleSubmit(data: dict) {
            await jacLogin(data["username"], data["password"]);
        }

        return
            <JacForm
                schema={schema}
                onSubmit={handleSubmit}
                field_config={{
                    "username": {"label": "Username", "type": "text"},
                    "password": {"label": "Password", "type": "password"}
                }}
                submitLabel="Login"
            />;
    }

    def:pub ListPage -> JsxElement {
        has greeting: str = "";

        async can with entry {
            result = root spawn whoami();
            if result.reports and len(result.reports) > 0 {
                greeting = str(result.reports[0]);
            }
        }

        return
            <div>
                <h1>Items</h1>
                <p data-testid="greeting">{greeting}</p>
                <Link to="/detail/1">View item 1</Link>
            </div>;
    }

    def:pub DetailPage -> JsxElement {
        return
            <div>
                <h1>Item Detail</h1>
            </div>;
    }

    def:pub app -> JsxElement {
        return
            <Router>
                <Routes>
                    <Route path="/login" element={<LoginPage/>}/>
                    <Route
                        path="/"
                        element={
                            <AuthGuard redirect="/login">
                                <ListPage/>
                            </AuthGuard>
                        }
                    />
                    <Route
                        path="detail/:id"
                        element={
                            <AuthGuard redirect="/login">
                                <DetailPage/>
                            </AuthGuard>
                        }
                    />
                </Routes>
            </Router>;
    }
}
