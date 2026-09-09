"""Multi-screen mobile (React Native) fixture: login -> list -> detail.

A `kind = "mobile"` app, so the screens use the mobUI vocabulary (raw HTML
tags are E1105 here). Exercises AuthGuard-protected routes, JacForm login,
walker calls, and dynamic route params for the dual-target gate tests
(`jac build --platform android main.jac` and `--platform web`).
"""
walker:pub whoami {
    can check with Root entry {
        report "anonymous";
    }
}


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
import from '@jac/mobui' { View, Text }

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

    <JacForm
        schema={schema}
        onSubmit={handleSubmit}
        field_config={{
            "username": {"label": "Username", "type": "text"},
            "password": {"label": "Password", "type": "password"}
        }}
        submitLabel="Login"
    />
}

def:pub ListPage -> JsxElement {
    has greeting: str = "";

    async can with entry {
        result = root spawn whoami();
        if result.reports and len(result.reports) > 0 {
            greeting = str(result.reports[0]);
        }
    }

    <View>
        <Text style={{"fontSize": 24, "fontWeight": "bold"}}>Items</Text>
        <Text testID="greeting">{greeting}</Text>
        <Link to="/detail/1">View item 1</Link>
    </View>
}

def:pub DetailPage -> JsxElement {
    <View>
        <Text style={{"fontSize": 24, "fontWeight": "bold"}}>Item Detail</Text>
    </View>
}

def:pub app -> JsxElement {
    <Router>
        <Routes>
            <Route path="/login" element={<LoginPage/>}/>
            <Route
                path="/"
                element={<AuthGuard redirect="/login">
                    <ListPage/>
                </AuthGuard>}
            />
            <Route
                path="detail/:id"
                element={<AuthGuard redirect="/login">
                    <DetailPage/>
                </AuthGuard>}
            />
        </Routes>
    </Router>
}
