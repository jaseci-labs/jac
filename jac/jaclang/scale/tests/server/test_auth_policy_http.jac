"""The auth policy over HTTP, from the environment to the response (issue #9895).

Each test boots a real in-process server under one identifier setup, declared
the way a deployment declares it (here through the `JAC_SERVE_AUTH_*`
overrides), and drives it through the public endpoints: the policy a client
reads, registration, login by each identifier, add-identity and rename.
"""

import os;
import uuid;
import from unittest.mock { patch }
import from jaclang.scale.tests.scale_test_client { make_client }

glob STRONG: str = "correct horse battery",
     # The suite lowers the password floor for its fixtures; these tests run
     # under the shipped password defaults plus the setup they name.
     SHIPPED: dict[str, str] = {
         "JAC_SERVE_AUTH_PASSWORD_MIN_LENGTH": "8",
         "JAC_SERVE_AUTH_PASSWORD_REJECT_COMMON": "true",
         "JAC_SERVE_AUTH_PASSWORD_REJECT_IDENTIFIERS": "true"
     };


def setup(**identifiers: str) -> dict[str, str] {
    env = dict(SHIPPED);
    for (kind, mode) in identifiers.items() {
        env["JAC_SERVE_AUTH_IDENTIFIERS_" + kind.upper()] = mode;
    }
    return env;
}


def register(client: any, identities: dict[str, str], password: str = STRONG) -> any {
    return client.post(
        "/user/register",
        json={
            "identities": [{"type": k, "value": v} for (k, v) in identities.items()],
            "credential": {"type": "password", "password": password}
        }
    );
}


def login(client: any, kind: str, value: str, password: str = STRONG) -> any {
    return client.post(
        "/user/login",
        json={
            "identity": {"type": kind, "value": value},
            "credential": {"type": "password", "password": password}
        }
    );
}


def violations(response: any) -> list[str] {
    error = response.json()["error"];
    assert error["code"] == "POLICY_VIOLATION" , error;
    return error["details"]["violations"];
}


test "by default an account registers with a username, an email, or both" {
    with patch.dict(os.environ, setup()) {
        client = make_client();
        try {
            policy = client.get("/user/auth-policy").json()["data"];
            assert policy["identifiers"]
                == {
                    "username": "optional",
                    "email": "optional",
                    "login_with": ["username", "email"]
                };
            assert policy["password"]["min_length"] == 8;
            assert policy["registration"] == {"enabled": True, "challenge": False};

            tag = uuid.uuid4().hex[:10];
            assert register(client, {"username": "u" + tag}).status_code == 201;
            assert register(client, {"email": tag + "@corp.example"}).status_code
                == 201;
            assert login(client, "username", "u" + tag).status_code == 200;
            assert login(client, "email", tag + "@corp.example").status_code == 200;

            squat = register(client, {"username": "v" + tag + "@corp.example"});
            assert squat.status_code == 400;
            assert violations(squat) == ["USERNAME_INVALID"];
            weak = register(client, {"username": "w" + tag}, "password1");
            assert violations(weak) == ["PASSWORD_COMMON"];
            short = register(client, {"username": "x" + tag}, "1");
            assert violations(short) == ["PASSWORD_TOO_SHORT"];
        } finally {
            client.close();
        }
    }
}


test "the username is the email" {
    with patch.dict(os.environ, setup(username="off", email="required")) {
        client = make_client();
        try {
            policy = client.get("/user/auth-policy").json()["data"];
            assert policy["identifiers"]["username"] == "off";
            assert policy["identifiers"]["login_with"] == ["username", "email"];

            tag = uuid.uuid4().hex[:10];
            address = tag + "@corp.example";
            refused = register(client, {"username": "u" + tag});
            assert refused.status_code == 400;
            assert sorted(violations(refused))
                == ["IDENTIFIER_NOT_ALLOWED", "IDENTIFIER_REQUIRED"];
            created = register(client, {"email": address});
            assert created.status_code == 201 , created.text;
            token = created.json()["data"]["token"];
            assert login(client, "email", address).status_code == 200;

            auth = {"Authorization": f"Bearer {token}"};
            added = client.post(
                "/user/add-identity",
                json={"identity": {"type": "username", "value": "u" + tag}},
                headers=auth
            );
            assert violations(added) == ["IDENTIFIER_NOT_ALLOWED"];
            renamed = client.put(
                "/user/username", json={"new_username": "u" + tag}, headers=auth
            );
            assert violations(renamed) == ["IDENTIFIER_NOT_ALLOWED"];
        } finally {
            client.close();
        }
    }
}


test "a username plus a required email" {
    with patch.dict(os.environ, setup(username="required", email="required")) {
        client = make_client();
        try {
            tag = uuid.uuid4().hex[:10];
            name = "u" + tag;
            address = tag + "@corp.example";
            assert violations(register(client, {"username": name}))
                == ["IDENTIFIER_REQUIRED"];
            assert violations(register(client, {"email": address}))
                == ["IDENTIFIER_REQUIRED"];
            created = register(client, {"username": name, "email": address});
            assert created.status_code == 201 , created.text;
            assert login(client, "username", name).status_code == 200;
            assert login(client, "email", address).status_code == 200;
            assert login(client, "email", address, "wrong password").status_code == 401;

            auth = {"Authorization": f"Bearer {created.json()['data']['token']}"};
            taken = client.put(
                "/user/username",
                json={"new_username": name + "@x.example"},
                headers=auth
            );
            assert violations(taken) == ["USERNAME_INVALID"];
            renamed = client.put(
                "/user/username", json={"new_username": name + "_2"}, headers=auth
            );
            assert renamed.status_code == 200 , renamed.text;
            weak = client.put(
                "/user/password",
                json={"current_password": STRONG, "new_password": name + "_2 pw"},
                headers={"Authorization": f"Bearer {renamed.json()['data']['token']}"}
            );
            assert violations(weak) == ["PASSWORD_CONTAINS_IDENTIFIER"];
        } finally {
            client.close();
        }
    }
}


test "closed registration and the login limit answer their own codes" {
    env = setup();
    env["JAC_SERVE_AUTH_REGISTRATION_ENABLED"] = "false";
    env["JAC_SERVE_AUTH_LOCKOUT_MAX_ATTEMPTS"] = "2";
    with patch.dict(os.environ, env) {
        client = make_client();
        try {
            tag = uuid.uuid4().hex[:10];
            closed = register(client, {"username": "u" + tag});
            assert closed.status_code == 403;
            assert closed.json()["error"]["code"] == "REGISTRATION_CLOSED";
            assert client.get("/user/auth-policy").json()["data"]["registration"][
                "enabled"
            ]
                is False;

            for attempt in range(2) {
                assert login(client, "username", "ghost" + tag).status_code == 401;
            }
            limited = login(client, "username", "ghost" + tag);
            assert limited.status_code == 429;
            assert limited.json()["error"]["code"] == "RATE_LIMITED";
            assert int(limited.headers.get("Retry-After")) > 0;
        } finally {
            client.close();
        }
    }
}


test "required verification stops startup with or without a mail extension" {
    import from jaclang.server.settings { ServeConfigError }
    with patch.dict(os.environ, setup()) {
        client = make_client();
        try {
            server = client.server;
            server._validate_or_raise();
            server.resolved_settings().auth.email.verification = "required";
            for extensions in [list(server.extensions or []), []] {
                server.extensions = extensions;
                try {
                    server._validate_or_raise();
                    assert False , f"started with {len(extensions)} extensions";
                } except ServeConfigError as refused {
                    assert "[serve.auth.email] verification = 'required'"
                        in str(refused) , str(refused);
                }
            }
        } finally {
            client.close();
        }
    }
}
