"""Test for restspec decorator functionality."""

import from jaclang.scale.tests.scale_test_client {
    ScaleTestClient,
    make_client,
    extract_data
}

def _as_any(v: any) -> any {
    return v;
}

test "custom method walker" {
    client = make_client("restspec_fixtures.jac");
    try {
        response = client.get("/walker/GetWalker");
        assert response.status_code == 200 , response.text;
        data = extract_data(response.json());
        assert data["reports"][0]["message"] == "GetWalker executed";
    } finally {
        client.close();
    }
}

test "custom path walker" {
    client = make_client("restspec_fixtures.jac");
    try {
        response = client.get("/custom/walker");
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert data["reports"][0]["message"] == "CustomPathWalker executed";
        assert data["reports"][0]["path"] == "/custom/walker";
    } finally {
        client.close();
    }
}

test "post method walker" {
    client = make_client("restspec_fixtures.jac");
    try {
        response = client.post("/walker/PostWalker");
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert data["reports"][0]["message"] == "PostWalker executed";
        assert data["reports"][0]["method"] == "POST";
    } finally {
        client.close();
    }
}

test "default method walker" {
    client = make_client("restspec_fixtures.jac");
    try {
        response = client.post("/walker/DefaultWalker");
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert data["reports"][0]["message"] == "DefaultWalker executed";
        assert data["reports"][0]["method"] == "DEFAULT";
    } finally {
        client.close();
    }
}

test "custom method func" {
    client = make_client("restspec_fixtures.jac");
    try {
        client.register_user("u1", "p1");
        login = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": "u1"},
                "credential": {"type": "password", "password": "p1"}
            }
        );
        token = extract_data(login.json())["token"];

        response = client.get(
            "/function/get_func", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert data["result"]["message"] == "get_func executed";
    } finally {
        client.close();
    }
}

test "custom path func" {
    client = make_client("restspec_fixtures.jac");
    try {
        client.register_user("u1", "p1");
        login = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": "u1"},
                "credential": {"type": "password", "password": "p1"}
            }
        );
        token = extract_data(login.json())["token"];

        response = client.get(
            "/custom/func", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert data["result"]["message"] == "custom_path_func executed";
        assert data["result"]["path"] == "/custom/func";
    } finally {
        client.close();
    }
}

test "post method func" {
    client = make_client("restspec_fixtures.jac");
    try {
        client.register_user("u1", "p1");
        login = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": "u1"},
                "credential": {"type": "password", "password": "p1"}
            }
        );
        token = extract_data(login.json())["token"];

        response = client.post(
            "/function/post_func", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert data["result"]["message"] == "post_func executed";
        assert data["result"]["method"] == "POST";
    } finally {
        client.close();
    }
}

test "default method func" {
    client = make_client("restspec_fixtures.jac");
    try {
        client.register_user("u1", "p1");
        login = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": "u1"},
                "credential": {"type": "password", "password": "p1"}
            }
        );
        token = extract_data(login.json())["token"];

        response = client.post(
            "/function/default_func", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert data["result"]["message"] == "default_func executed";
        assert data["result"]["method"] == "DEFAULT";
    } finally {
        client.close();
    }
}

test "get walker with params" {
    client = make_client("restspec_fixtures.jac");
    try {
        response = client.get(
            "/walker/GetWalkerWithParams", params={"name": "Alice", "age": 30}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert data["reports"][0]["message"] == "GetWalkerWithParams executed";
        assert data["reports"][0]["name"] == "Alice";
        assert data["reports"][0]["age"] == 30;
    } finally {
        client.close();
    }
}

test "get func with params" {
    client = make_client("restspec_fixtures.jac");
    try {
        client.register_user("u1", "p1");
        login = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": "u1"},
                "credential": {"type": "password", "password": "p1"}
            }
        );
        token = extract_data(login.json())["token"];

        response = client.get(
            "/function/get_func_with_params",
            headers={"Authorization": f"Bearer {token}"},
            params={"name": "Bob", "age": 40}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert data["result"]["message"] == "get_func_with_params executed";
        assert data["result"]["name"] == "Bob";
        assert data["result"]["age"] == 40;
    } finally {
        client.close();
    }
}

test "undeclared query params ignored on func" {
    client = make_client("restspec_fixtures.jac");
    try {
        client.register_user("u1", "p1");
        token = client.login_user("u1", "p1");

        response = client.get(
            "/function/get_func_with_params",
            headers={"Authorization": f"Bearer {token}"},
            params={"name": "Bob", "age": 40, "v": "1708012345", "t": "abc"}
        );
        assert response.status_code == 200 , response.text;
        data = extract_data(response.json());
        assert data["result"]["message"] == "get_func_with_params executed";
        assert data["result"]["name"] == "Bob";
        assert data["result"]["age"] == 40;
    } finally {
        client.close();
    }
}

test "undeclared query params ignored on walker" {
    client = make_client("restspec_fixtures.jac");
    try {
        response = client.get(
            "/walker/GetWalkerWithParams",
            params={"name": "Alice", "age": 30, "v": "1708012345"}
        );
        assert response.status_code == 200 , response.text;
        data = extract_data(response.json());
        assert data["reports"][0]["message"] == "GetWalkerWithParams executed";
        assert data["reports"][0]["name"] == "Alice";
        assert data["reports"][0]["age"] == 30;
    } finally {
        client.close();
    }
}

test "openapi specs" {
    client = make_client("restspec_fixtures.jac");
    try {
        srv = client._server;
        assert srv is not None , "server must be running";
        spec = srv.app.openapi();
        paths = spec["paths"];

        assert "/custom/walker" in paths;
        assert "get" in paths["/custom/walker"];

        assert "/custom/func" in paths;
        assert "get" in paths["/custom/func"];

        assert "/walker/GetWalker" in paths;
        assert "get" in paths["/walker/GetWalker"];
        assert "post" not in paths["/walker/GetWalker"];

        assert "/walker/PostWalker" in paths;
        assert "post" in paths["/walker/PostWalker"];
        assert "get" not in paths["/walker/PostWalker"];

        assert "/walker/DefaultWalker" in paths;
        assert "post" in paths["/walker/DefaultWalker"];
        assert "get" not in paths["/walker/DefaultWalker"];
    } finally {
        client.close();
    }
}

# ============================================================================
# Path Parameter Tests (regression for @restspec path param bug)
# Single server instance for all path-param assertions — no per-case restart.
# ============================================================================
test "restspec path parameters" {
    client = make_client("restspec_fixtures.jac");
    try {
        # Obtain an auth token (functions require auth, walkers are public)
        client.register_user("u_pp", "p_pp");
        token = client.login_user("u_pp", "p_pp");
        auth = {"Authorization": f"Bearer {token}"};

        # --- OpenAPI schema: routes registered with correct path templates ---
        srv = client._server;
        assert srv is not None , "server must be running";
        spec = srv.app.openapi();
        paths = spec["paths"];
        assert "/items/{item_id}" in paths and "get" in paths["/items/{item_id}"];
        assert "/users/{user_id}/orders" in paths
            and "get" in paths["/users/{user_id}/orders"];
        assert "/orgs/{org_id}/repos/{repo_id}" in paths
            and "get" in paths["/orgs/{org_id}/repos/{repo_id}"];
        assert "/resources/{resource_id}/update" in paths
            and "post" in paths["/resources/{resource_id}/update"];
        assert "/nodes/{node_id}" in paths and "get" in paths["/nodes/{node_id}"];
        assert "/projects/{project_id}/tasks/{task_id}" in paths
            and "get" in paths["/projects/{project_id}/tasks/{task_id}"];

        # OpenAPI marks the path param as in=path, required=true
        item_params = paths["/items/{item_id}"]["get"]["parameters"];
        pp = _as_any(
            next(
                p
                for p in item_params
                if p["name"] == "item_id"
            )
        );
        assert pp["in"] == "path" and pp["required"] == True;

        # --- Function: single path param ---
        r = client.get("/items/abc123", headers=auth);
        assert r.status_code == 200;
        d = extract_data(r.json())["result"];
        assert d["item_id"] == "abc123" and d["message"] == "get_item executed";

        # --- Function: path param + explicit query param ---
        r = client.get("/users/u42/orders", headers=auth, params={"status": "pending"});
        assert r.status_code == 200;
        d = extract_data(r.json())["result"];
        assert d["user_id"] == "u42" and d["status"] == "pending";

        # --- Function: path param + default query param ---
        r = client.get("/users/u99/orders", headers=auth);
        assert r.status_code == 200;
        d = extract_data(r.json())["result"];
        assert d["user_id"] == "u99" and d["status"] == "all";

        # --- Function: multiple path params ---
        r = client.get("/orgs/myorg/repos/myrepo", headers=auth);
        assert r.status_code == 200;
        d = extract_data(r.json())["result"];
        assert d["org_id"] == "myorg" and d["repo_id"] == "myrepo";

        # --- Function: POST with path param + JSON body ---
        r = client.post(
            "/resources/res-001/update",
            headers=auth,
            json={"name": "widget", "value": 42}
        );
        assert r.status_code == 200;
        d = extract_data(r.json())["result"];
        assert d["resource_id"] == "res-001"
            and d["name"] == "widget"
            and d["value"] == 42;

        # --- Walker: single path param (walkers are public, no auth needed) ---
        r = client.get("/nodes/node-xyz");
        assert r.status_code == 200;
        d = extract_data(r.json())["reports"][0];
        assert d["node_id"] == "node-xyz" and d["message"] == "GetNodeWalker executed";

        # --- Walker: multiple path params ---
        r = client.get("/projects/proj-1/tasks/task-2");
        assert r.status_code == 200;
        d = extract_data(r.json())["reports"][0];
        assert d["project_id"] == "proj-1" and d["task_id"] == "task-2";
        assert d["message"] == "GetProjectTaskWalker executed";
    } finally {
        client.close();
    }
}

test "walker with default node parameter route" {
    client = make_client("restspec_fixtures.jac");
    try {
        srv = client._server;
        assert srv is not None , "server must be running";
        spec = srv.app.openapi();
        paths = spec["paths"];

        walker_paths_with_param = [
            p
            for p in paths.keys()
            if "/walker/" in p and "{" in p
        ];

        has_nd_param = any("{nd}" in p for p in walker_paths_with_param);

        assert has_nd_param , f"Walker routes should use '{{nd}}'. Found: {walker_paths_with_param}";

        test_route = next(
            (
                p
                for p in walker_paths_with_param
                if "{nd}" in p
            ),
            None
        );
        if test_route {
            method = "post" if "post" in paths[test_route] else "get";
            params = paths[test_route][method]["parameters"];
            nd_param: any = next(
                (
                    p
                    for p in params
                    if p.get("name") == "nd"
                ),
                None
            );
            assert nd_param is not None , "Should have a path parameter named 'nd'";
            assert nd_param["in"] == "path" , "nd parameter should be in path";
            assert nd_param["required"] == True , "nd parameter should be required";
        }
    } finally {
        client.close();
    }
}

test "walker with node parameter functional test" {
    client = make_client("restspec_fixtures.jac");
    try {
        # First, create a UserProfile node to test with
        create_response = client.post(
            "/walker/CreateUserProfile", json={"user_id": "user123", "name": "Alice"}
        );
        assert create_response.status_code == 200;
        create_data = extract_data(create_response.json());
        node_id = create_data["reports"][0]["node_id"];

        response = client.post(f"/walker/LoadUserProfile/{node_id}", json={});

        assert response.status_code == 200 , f"Expected 200. Got: {response.status_code}, Body: {response.text}";

        data = extract_data(response.json());

        assert data["reports"][0]["message"] == "LoadUserProfile executed on node";
        assert data["reports"][0]["node_id"] == node_id;
        assert data["reports"][0]["user_id"] == "user123";
        assert data["reports"][0]["name"] == "Alice";
    } finally {
        client.close();
    }
}

# ============================================================================
# Custom Object Body Parameter Tests — walker + function + recursive
# One integration test per variant; schema + runtime + validation in one flow.
# ============================================================================
test "custom obj body - walker flows" {
    client = make_client("restspec_fixtures.jac");
    try {
        # OpenAPI: UserBody schema + CreateUser body references it via $ref
        srv = client._server;
        assert srv is not None , "server must be running";
        spec = srv.app.openapi();
        schemas = spec["components"]["schemas"];
        assert "UserBody" in schemas;
        user_schema = schemas["UserBody"];
        assert user_schema["properties"]["name"]["type"] == "string"
            and user_schema["properties"]["age"]["type"] == "integer"
            and set(user_schema["required"]) == {"name", "age"};
        body_ref = spec["paths"]["/walker/CreateUser"]["post"]["requestBody"]["content"][
            "application/json"
        ]["schema"]["$ref"];
        body_schema = schemas[body_ref.rsplit("/", 1)[1]];
        assert body_schema["properties"]["user"].get("$ref", "").endswith("/UserBody");

        # Flat obj
        r = client.post(
            "/walker/CreateUser", json={"user": {"name": "Alice", "age": 30}}
        );
        assert r.status_code == 200 , r.text;
        d = extract_data(r.json())["reports"][0];
        assert d["name"] == "Alice" and d["age"] == 30 and d["user_type"] == "UserBody";

        # Nested obj
        r = client.post(
            "/walker/CreateUserWithAddress",
            json={
                "user": {
                    "name": "Bob",
                    "address": {"street": "1 Main", "city": "Springfield"}
                }
            }
        );
        assert r.status_code == 200 , r.text;
        d = extract_data(r.json())["reports"][0];
        assert d["name"] == "Bob"
            and d["street"] == "1 Main"
            and d["city"] == "Springfield"
            and d["address_type"] == "Address";

        # List of objs
        r = client.post(
            "/walker/CreateUsers",
            json={"users": [{"name": "Alice", "age": 30}, {"name": "Bob", "age": 25}]}
        );
        assert r.status_code == 200 , r.text;
        d = extract_data(r.json())["reports"][0];
        assert d["count"] == 2
            and d["names"] == ["Alice", "Bob"]
            and d["first_type"] == "UserBody";

        # Validation rejects wrong field type
        r = client.post(
            "/walker/CreateUser", json={"user": {"name": "Alice", "age": "not-an-int"}}
        );
        assert r.status_code == 422;
    } finally {
        client.close();
    }
}

test "custom obj body - function flows" {
    client = make_client("restspec_fixtures.jac");
    try {
        client.register_user("u_fn", "p_fn");
        auth = {"Authorization": f"Bearer {client.login_user('u_fn', 'p_fn')}"};

        # Flat obj
        r = client.post(
            "/func/create_user",
            headers=auth,
            json={"user": {"name": "Alice", "age": 30}}
        );
        assert r.status_code == 200 , r.text;
        d = extract_data(r.json())["result"];
        assert d["name"] == "Alice" and d["age"] == 30 and d["user_type"] == "UserBody";

        # Nested obj
        r = client.post(
            "/func/create_user_with_address",
            headers=auth,
            json={
                "user": {
                    "name": "Bob",
                    "address": {"street": "1 Main", "city": "Springfield"}
                }
            }
        );
        assert r.status_code == 200 , r.text;
        d = extract_data(r.json())["result"];
        assert d["name"] == "Bob"
            and d["street"] == "1 Main"
            and d["city"] == "Springfield"
            and d["address_type"] == "Address";

        # List of objs
        r = client.post(
            "/func/create_users",
            headers=auth,
            json={"users": [{"name": "Alice", "age": 30}, {"name": "Bob", "age": 25}]}
        );
        assert r.status_code == 200 , r.text;
        d = extract_data(r.json())["result"];
        assert d["count"] == 2
            and d["names"] == ["Alice", "Bob"]
            and d["first_type"] == "UserBody";

        # Validation rejects wrong field type
        r = client.post(
            "/func/create_user",
            headers=auth,
            json={"user": {"name": "Alice", "age": "not-an-int"}}
        );
        assert r.status_code == 422;
    } finally {
        client.close();
    }
}

test "recursive obj body flows" {
    client = make_client("restspec_fixtures.jac");
    try {
        # OpenAPI: TreeNode.children items $ref TreeNode (self-reference)
        srv = client._server;
        assert srv is not None , "server must be running";
        spec = srv.app.openapi();
        schemas = spec["components"]["schemas"];
        assert "TreeNode" in schemas;
        items = schemas["TreeNode"]["properties"]["children"].get("items", {});
        assert items.get("$ref", "").endswith("/TreeNode") , f"Expected children items to $ref TreeNode, got {items}";

        # Walker tree (public): 4 nodes, depth 3
        walker_tree = {
            "name": "root",
            "children": [
                {"name": "child1", "children": [{"name": "leaf1", "children": []}]},
                {"name": "child2", "children": []}
            ]
        };
        r = client.post("/walker/CreateTreeWalker", json={"root": walker_tree});
        assert r.status_code == 200 , r.text;
        d = extract_data(r.json())["reports"][0];
        assert d["root_name"] == "root"
            and d["root_type"] == "TreeNode"
            and d["child_type"] == "TreeNode"
            and d["depth"] == 3
            and d["node_count"] == 4;

        # Function tree (auth): 5 nodes, depth 3
        client.register_user("u_rec", "p_rec");
        auth = {"Authorization": f"Bearer {client.login_user('u_rec', 'p_rec')}"};
        fn_tree = {
            "name": "root",
            "children": [
                {
                    "name": "child1",
                    "children": [
                        {"name": "leaf1", "children": []},
                        {"name": "leaf2", "children": []}
                    ]
                },
                {"name": "child2", "children": []}
            ]
        };
        r = client.post("/func/create_tree", headers=auth, json={"root": fn_tree});
        assert r.status_code == 200 , r.text;
        d = extract_data(r.json())["result"];
        assert d["root_name"] == "root"
            and d["root_type"] == "TreeNode"
            and d["child_type"] == "TreeNode"
            and d["depth"] == 3
            and d["node_count"] == 5;
    } finally {
        client.close();
    }
}

# ============================================================================
# Raw response body -- @restspec(envelope=False, produces=...)
# The endpoint that motivated this: a `curl | bash` installer cannot be handed
# a JSON envelope, so the return value has to reach the wire verbatim.
# ============================================================================
test "raw body skips the transport envelope" {
    client = make_client("restspec_fixtures.jac");
    try {
        r = client.get("/raw/script.sh");
        assert r.status_code == 200 , r.text;
        # Body is the return value verbatim -- no {"ok":..,"data":..} wrapper.
        assert r.text == "#!/usr/bin/env bash\necho jac\n" , r.text;
        assert r.headers["content-type"].startswith("text/x-shellscript");
        assert "\"ok\"" not in r.text;
    } finally {
        client.close();
    }
}

test "raw body defaults to text/plain without produces" {
    client = make_client("restspec_fixtures.jac");
    try {
        r = client.get("/raw/plain");
        assert r.status_code == 200 , r.text;
        assert r.text == "plain body";
        assert r.headers["content-type"].startswith("text/plain");
    } finally {
        client.close();
    }
}

test "raw body json-encodes non-str returns without the envelope" {
    client = make_client("restspec_fixtures.jac");
    try {
        r = client.get("/raw/json");
        assert r.status_code == 200 , r.text;
        assert r.json() == {"a": 1} , r.text;
        assert r.headers["content-type"].startswith("application/json");
    } finally {
        client.close();
    }
}

test "raw body sends bytes verbatim, not their repr (#9234)" {
    # Serializer has no bytes case, so a result serialized before the raw-body
    # branch sees it arrives as the repr string instead of the bytes.
    client = make_client("restspec_fixtures.jac");
    try {
        r = client.get("/raw/bytes");
        assert r.status_code == 200 , r.text;
        assert r.content == b"PK\x03\x04\x00\xffRAW" , str(r.content);
        assert len(r.content) == 9 , str(len(r.content));
        assert r.headers["content-type"].startswith("application/octet-stream");
    } finally {
        client.close();
    }
}

test "raw body sends a bytearray verbatim (#9234)" {
    client = make_client("restspec_fixtures.jac");
    try {
        r = client.get("/raw/bytearray");
        assert r.status_code == 200 , r.text;
        assert r.content == b"\x00\x01\x02" , str(r.content);
    } finally {
        client.close();
    }
}

test "envelope remains the default" {
    client = make_client("restspec_fixtures.jac");
    try {
        r = client.get("/raw/enveloped");
        assert r.status_code == 200 , r.text;
        assert r.headers["content-type"].startswith("application/json");
        assert extract_data(r.json())["result"] == "wrapped";
    } finally {
        client.close();
    }
}


test "restspec without method registers a live POST route (#8000 f3)" {
    # A restspec instance is truthy, so `restspec.method if restspec else POST`
    # yielded method="" for any @restspec(path=...) def without method= - the
    # router bucketed it under "" and every request 404ed. It must default to
    # POST and serve.
    client = make_client("restspec_fixtures.jac");
    try {
        client.register_user("u1", "p1");
        login = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": "u1"},
                "credential": {"type": "password", "password": "p1"}
            }
        );
        token = extract_data(login.json())["token"];

        response = client.post(
            "/custom/no-method-func", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200 , (
            f"expected a live default-POST route, got {response.status_code}: {response.text}"
        );
        data = extract_data(response.json());
        assert data["result"]["message"] == "no_method_func executed";

        srv = client._server;
        assert srv is not None , "server must be running";
        schema = srv.app.openapi();
        methods = list(schema["paths"]["/custom/no-method-func"].keys());
        assert methods == ["post"] , f"openapi must carry a real verb, got {methods}";
    } finally {
        client.close();
    }
}


test "restspec decoration-time validation rejects bad specs (#8000 f3)" {
    import from jaclang.runtime.builtin { APIProtocol }
    import jaclang.runtime.builtin as blt;

    with testraises(ValueError) as exc {
        blt.restspec(method="HEAD")(lambda { 1; });
    }
    assert "not routable" in str(exc.value);

    with testraises(ValueError) as exc2 {
        blt.restspec(protocol="carrier-pigeon")(lambda { 1; });
    }
    assert "not recognized" in str(exc2.value);

    def some_fn -> int {
        return 1;
    }
    with testraises(ValueError) as exc3 {
        blt.restspec(protocol=APIProtocol.WEBHOOK)(some_fn);
    }
    assert "walker-only" in str(exc3.value);

    with testraises(ValueError) as exc4 {
        blt.restspec(broadcast=True)(some_fn);
    }
    assert "WEBSOCKET" in str(exc4.value);

    # String coercion: 'ws' and 'get' normalize instead of degrading to HTTP.
    decorated = blt.restspec(method="get")(some_fn);
    assert decorated.restspec.method.value == "GET";
}


# ============================================================================
# Request and response channel (#9618, #9619): a served unit reads the request
# it is serving and chooses the status and headers of its own enveloped
# response. One client per group; the fixture compile dominates the cost.
# ============================================================================
def _count_marks(client: ScaleTestClient, auth: dict[str, str], label: str) -> int {
    r = client.post("/walker/CountAuditMarks", headers=auth, json={"label": label});
    assert r.status_code == 200 , r.text;
    return extract_data(r.json())["reports"][0]["count"];
}

test "a walker or function chooses its status and keeps its body (#9618)" {
    client = make_client("restspec_fixtures.jac");
    try {
        auth = {"Authorization": "Bearer " + client.register_and_login("u1", "p1")};

        # Nothing chosen: the answer is the same 200 envelope as before.
        r = client.post("/walker/DefaultWalker", headers=auth);
        assert r.status_code == 200 , r.text;
        assert sorted(r.json().keys()) == ["data", "error", "ok", "type"] , r.text;
        assert r.json()["ok"] is True and r.json()["error"] is None , r.text;

        # A refusal that does not raise: 403, report body intact, write kept.
        r = client.post(
            "/walker/RefuseAfterWrite", headers=auth, json={"label": "kept"}
        );
        assert r.status_code == 403 , r.text;
        body = r.json();
        assert body["ok"] is False and body["error"] is None , r.text;
        assert body["data"]["reports"] == [{"error": "Forbidden", "label": "kept"}] , r.text;
        assert _count_marks(client, auth, "kept") == 1;

        # A refusal that raises: the unit rolls back and the 409 still stands.
        r = client.post(
            "/walker/RefuseAndRollBack", headers=auth, json={"label": "gone"}
        );
        assert r.status_code == 409 , r.text;
        assert r.json()["ok"] is False , r.text;
        assert r.json()["error"]["message"] == "Already exists" , r.text;
        assert _count_marks(client, auth, "gone") == 0;

        # A crash after choosing a success status is still a 500.
        r = client.post("/walker/CrashAfterCreated", headers=auth);
        assert r.status_code == 500 , r.text;

        # A success status and a header of the walker's own on the envelope.
        r = client.post("/walker/CreatedWithHeader", headers=auth);
        assert r.status_code == 201 , r.text;
        assert r.json()["ok"] is True , r.text;
        assert r.headers["x-resource-id"] == "r-7";
        assert r.json()["data"]["reports"] == [{"id": "r-7"}] , r.text;

        # A function: 404 with its return value as the body, 200 otherwise.
        r = client.post("/function/find_thing", json={"thing_id": "nope"});
        assert r.status_code == 404 , r.text;
        assert r.json()["data"]["result"]
            == {"error": "Not found", "thing_id": "nope"} , r.text;
        r = client.post("/function/find_thing", json={"thing_id": "known"});
        assert r.status_code == 200 , r.text;
        assert r.json()["ok"] is True , r.text;
        assert extract_data(r.json())["result"] == {"thing_id": "known"};
    } finally {
        client.close();
    }
}

test "a chosen status and header survive the idempotency replay (#9618)" {
    client = make_client("restspec_fixtures.jac");
    try {
        auth = {"Authorization": "Bearer " + client.register_and_login("u1", "p1")};
        keyed = dict(auth);
        keyed["X-Jac-Idempotency-Key"] = "refuse-once";
        first = client.post(
            "/walker/RefuseAfterWrite", headers=keyed, json={"label": "once"}
        );
        again = client.post(
            "/walker/RefuseAfterWrite", headers=keyed, json={"label": "once"}
        );
        assert first.status_code == 403 and again.status_code == 403 , again.text;
        assert again.json() == first.json() , again.text;
        # The write was kept, so the retry must replay instead of running again.
        assert _count_marks(client, auth, "once") == 1;

        keyed["X-Jac-Idempotency-Key"] = "create-once";
        first = client.post("/walker/CreatedWithHeader", headers=keyed);
        again = client.post("/walker/CreatedWithHeader", headers=keyed);
        assert again.status_code == 201 , again.text;
        assert again.headers["x-resource-id"] == "r-7";
        assert again.json() == first.json() , again.text;
    } finally {
        client.close();
    }
}

test "a walker and a function read the request they serve (#9619)" {
    client = make_client("restspec_fixtures.jac");
    try {
        token = client.register_and_login("u1", "p1");
        # A sync walker runs on a worker thread and still sees the request.
        r = client.get(
            "/channel/walker-request",
            params={"x": "1"},
            headers={
                "Host": "shop.example.com",
                "X-Probe": "p1",
                "X-Forwarded-Host": "evil.example.net",
                "Authorization": "Bearer " + token
            }
        );
        assert r.status_code == 200 , r.text;
        seen = extract_data(r.json())["reports"][0];
        assert seen["method"] == "GET" , r.text;
        assert seen["path"] == "/channel/walker-request" , r.text;
        # The forwarded host of an untrusted peer is not the origin.
        assert seen["origin"] == "http://shop.example.com" , r.text;
        assert seen["public_origin"] == "" , r.text;
        assert seen["link"] == "http://shop.example.com/invite/abc" , r.text;
        assert seen["probe"] == "p1" , r.text;
        # Credentials stay with the framework.
        assert seen["authorization"] is None , r.text;
        assert seen["query"] == {"x": "1"} and seen["query_string"] == "x=1" , r.text;

        # An async walker runs on the request's own task; it reads and shapes.
        r = client.post(
            "/walker/AsyncWalkerReadsRequest", headers={"Host": "shop.example.com:8443"}
        );
        assert r.status_code == 202 , r.text;
        seen = r.json()["data"]["reports"][0];
        assert seen["origin"] == "http://shop.example.com:8443" , r.text;
        assert seen["path"] == "/walker/AsyncWalkerReadsRequest" , r.text;

        r = client.get(
            "/channel/func-request",
            params={"tag": "t"},
            headers={"Host": "shop.example.com", "X-Probe": "p2"}
        );
        assert r.status_code == 200 , r.text;
        seen = extract_data(r.json())["result"];
        assert seen["path"] == "/channel/func-request" , r.text;
        assert seen["origin"] == "http://shop.example.com" , r.text;
        assert seen["probe"] == "p2" and seen["query"] == {"tag": "t"} , r.text;

        # A raw-body function reads the request; its body is its return value.
        r = client.get("/raw/origin", headers={"Host": "shop.example.com"});
        assert r.status_code == 200 and r.text == "http://shop.example.com" , r.text;

        # A Host that is not a host cannot become part of a link.
        r = client.get(
            "/channel/func-request", headers={"Host": "evil.example.net/x?y="}
        );
        assert extract_data(r.json())["result"]["origin"] == "" , r.text;
    } finally {
        client.close();
    }
}

test "a configured public origin is what links are built from (#9619)" {
    import os;
    os.environ["JAC_SERVE_PUBLIC_ORIGIN"] = "https://app.example.com/";
    try {
        client = make_client("restspec_fixtures.jac");
    } finally {
        os.environ.pop("JAC_SERVE_PUBLIC_ORIGIN", None);
    }
    try {
        r = client.get(
            "/channel/func-request", headers={"Host": "attacker.example.net"}
        );
        assert r.status_code == 200 , r.text;
        seen = extract_data(r.json())["result"];
        assert seen["origin"] == "http://attacker.example.net" , r.text;
        assert seen["public_origin"] == "https://app.example.com" , r.text;
        assert seen["link"] == "https://app.example.com/invite/abc" , r.text;
    } finally {
        client.close();
    }
}

test "outside a request there is no request and nothing to shape (#9619)" {
    import from jaclang.server.exchange { current_request, respond }
    assert current_request() is None;
    assert respond(status=403) is False;
    with testraises(ValueError) as bad_status {
        respond(status=99);
    }
    assert "200..599" in str(bad_status.value);
    with testraises(ValueError) as server_owned {
        respond(headers={"Content-Length": "1"});
    }
    assert "set by the server" in str(server_owned.value);
    with testraises(ValueError) as split {
        respond(headers={"X-Injected": "a\r\nSet-Cookie: stolen=1"});
    }
    assert "line break" in str(split.value);
}
