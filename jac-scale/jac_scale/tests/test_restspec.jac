"""Test for restspec decorator functionality."""

import from jac_scale.tests.scale_test_client {
    ScaleTestClient,
    make_client,
    extract_data
}

test "custom method walker" {
    client = make_client("restspec_fixtures.jac");
    try {
        response = client.get("/walker/GetWalker");
        assert response.status_code == 200;
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
        client.post("/user/register", json={"username": "u1", "password": "p1"});
        login = client.post("/user/login", json={"username": "u1", "password": "p1"});
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
        client.post("/user/register", json={"username": "u1", "password": "p1"});
        login = client.post("/user/login", json={"username": "u1", "password": "p1"});
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
        client.post("/user/register", json={"username": "u1", "password": "p1"});
        login = client.post("/user/login", json={"username": "u1", "password": "p1"});
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
        client.post("/user/register", json={"username": "u1", "password": "p1"});
        login = client.post("/user/login", json={"username": "u1", "password": "p1"});
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
        client.post("/user/register", json={"username": "u1", "password": "p1"});
        login = client.post("/user/login", json={"username": "u1", "password": "p1"});
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

test "openapi specs" {
    client = make_client("restspec_fixtures.jac");
    try {
        spec = client.get("/openapi.json").json();
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
        client.post("/user/register", json={"username": "u_pp", "password": "p_pp"});
        login = client.post(
            "/user/login", json={"username": "u_pp", "password": "p_pp"}
        );
        auth = {"Authorization": f"Bearer {extract_data(login.json())['token']}"};

        # --- OpenAPI schema: routes registered with correct path templates ---
        spec = client.get("/openapi.json").json();
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
        pp = next(
            p
            for p in item_params
            if p["name"] == "item_id"
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
        spec = client.get("/openapi.json").json();
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
            nd_param = next(
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
